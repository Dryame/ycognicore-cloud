package bf.ycognicore.backend.service;

import bf.ycognicore.backend.config.RabbitMqConfig;
import bf.ycognicore.backend.entity.tenant.OutboxEvent;
import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.repository.tenant.OutboxEventRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OutboxIntegrationIT {

    @Mock
    private OutboxEventRepository outboxRepository;

    @Mock
    private RabbitTemplate rabbitTemplate;

    private OutboxPublisherService outboxPublisher;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        outboxPublisher = new OutboxPublisherService(outboxRepository, rabbitTemplate, objectMapper);
        TenantContext.setTenantId("DEMO001");
    }

    @AfterEach
    void tearDown() {
        TenantContext.clear();
    }

    @Test
    void publishPendingEvents_publie_et_marque_comme_published() throws Exception {
        // 1. Préparation
        OutboxEvent event = new OutboxEvent();
        event.setId(UUID.randomUUID());
        event.setType("vente.commande.creee");
        event.setPayload("{\"montant\": 150000}");
        event.setStatut("PENDING");

        when(outboxRepository.findByStatutOrderByDateCreationAsc(eq("PENDING"), any(Pageable.class)))
                .thenReturn(List.of(event));

        // 2. Exécution
        outboxPublisher.publishPendingEvents();

        // 3. Vérifications
        // Le message a bien été envoyé à RabbitMQ
        verify(rabbitTemplate, times(1)).convertAndSend(
                eq(RabbitMqConfig.EXCHANGE_NAME),
                eq("vente.commande.creee"),
                anyString()
        );

        // Le statut a été mis à jour
        assertThat(event.getStatut()).isEqualTo("PUBLISHED");
        verify(outboxRepository, times(1)).save(event);
    }

    @Test
    void publishPendingEvents_marque_failed_apres_3_tentatives() {
        // 1. Préparation
        OutboxEvent event = new OutboxEvent();
        event.setId(UUID.randomUUID());
        event.setType("vente.commande.creee");
        event.setPayload("{\"montant\": 150000}");
        event.setStatut("PENDING");
        event.setTentatives(2); // Déjà 2 tentatives

        when(outboxRepository.findByStatutOrderByDateCreationAsc(eq("PENDING"), any(Pageable.class)))
                .thenReturn(List.of(event));

        // Simulation d'une erreur RabbitMQ
        doThrow(new RuntimeException("RabbitMQ indisponible"))
                .when(rabbitTemplate).convertAndSend(anyString(), anyString(), anyString());

        // 2. Exécution
        outboxPublisher.publishPendingEvents();

        // 3. Vérifications
        assertThat(event.getStatut()).isEqualTo("FAILED");
        assertThat(event.getTentatives()).isEqualTo(3);
        verify(outboxRepository, times(1)).save(event);
    }
}
