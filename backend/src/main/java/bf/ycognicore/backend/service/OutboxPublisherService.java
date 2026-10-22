package bf.ycognicore.backend.service;

import bf.ycognicore.backend.config.RabbitMqConfig;
import bf.ycognicore.backend.entity.tenant.OutboxEvent;
import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.repository.tenant.OutboxEventRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class OutboxPublisherService {
    private static final Logger log = LoggerFactory.getLogger(OutboxPublisherService.class);
    private static final int BATCH_SIZE = 100;

    private final OutboxEventRepository outboxRepository;
    private final RabbitTemplate rabbitTemplate;
    private final ObjectMapper objectMapper;

    public OutboxPublisherService(OutboxEventRepository outboxRepository, RabbitTemplate rabbitTemplate, ObjectMapper objectMapper) {
        this.outboxRepository = outboxRepository;
        this.rabbitTemplate = rabbitTemplate;
        this.objectMapper = objectMapper;
    }

    @Scheduled(fixedDelay = 500)
    public void publishPendingEvents() {
        String tenantCode = "DEMO001";
        TenantContext.setTenantId(tenantCode);

        try {
            List<OutboxEvent> events = outboxRepository.findByStatutOrderByDateCreationAsc("PENDING", PageRequest.of(0, BATCH_SIZE));
            if (events.isEmpty()) return;

            for (OutboxEvent event : events) {
                try {
                    // On encapsule l'ID et le payload dans un message standardisé
                    Map<String, Object> message = new HashMap<>();
                    message.put("id", event.getId());
                    message.put("type", event.getType());
                    message.put("payload", event.getPayload());

                    rabbitTemplate.convertAndSend(RabbitMqConfig.EXCHANGE_NAME, event.getType(), objectMapper.writeValueAsString(message));
                    
                    event.setStatut("PUBLISHED");
                    event.setDatePublication(OffsetDateTime.now());
                    outboxRepository.save(event);
                } catch (Exception e) {
                    log.error("Échec publication {} : {}", event.getId(), e.getMessage());
                    event.setTentatives(event.getTentatives() + 1);
                    if (event.getTentatives() >= 3) event.setStatut("FAILED");
                    outboxRepository.save(event);
                }
            }
        } catch (Exception e) {
            log.error("Erreur Outbox {}", e.getMessage());
        } finally {
            TenantContext.clear();
        }
    }
}
