package bf.ycognicore.backend.listener;

import bf.ycognicore.backend.config.RabbitMqConfig;
import bf.ycognicore.backend.entity.tenant.EvenementsTraites;
import bf.ycognicore.backend.repository.tenant.EvenementsTraitesRepository;
import bf.ycognicore.backend.service.WorkflowEngineService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Component
public class OutboxEventListener {

    private static final Logger log = LoggerFactory.getLogger(OutboxEventListener.class);
    private final WorkflowEngineService workflowEngine;
    private final EvenementsTraitesRepository traitesRepo;
    private final ObjectMapper objectMapper;

    public OutboxEventListener(WorkflowEngineService workflowEngine, EvenementsTraitesRepository traitesRepo, ObjectMapper objectMapper) {
        this.workflowEngine = workflowEngine;
        this.traitesRepo = traitesRepo;
        this.objectMapper = objectMapper;
    }

    @RabbitListener(queues = RabbitMqConfig.QUEUE_NAME)
    @Transactional
    public void handleEvent(String rawMessage) {
        try {
            JsonNode message = objectMapper.readTree(rawMessage);
            UUID eventId = UUID.fromString(message.get("id").asText());
            String type = message.get("type").asText();
            String payload = message.get("payload").asText();

            // 1. Vérification de l'idempotence (D-P5-4)
            String consommateur = "workflow-engine";
            if (traitesRepo.existsByEventIdAndConsommateur(eventId, consommateur)) {
                log.info("Événement {} déjà traité par {}. Ignoré.", eventId, consommateur);
                return;
            }

            // 2. Définition du contexte tenant (car pas de requête HTTP)
            bf.ycognicore.backend.multitenant.TenantContext.setTenantId("DEMO001");
            
            // 3. Exécution du workflow
            log.info("Traitement de l'événement {} (type: {})", eventId, type);
            workflowEngine.executeWorkflows(type, payload, eventId);
            
            // 4. Marquage comme traité (après exécution)

            // 3. Marquage comme traité
            traitesRepo.save(new EvenementsTraites(eventId, consommateur));
            bf.ycognicore.backend.multitenant.TenantContext.clear();

        } catch (Exception e) {
            log.error("Erreur lors du traitement du message : {}", e.getMessage(), e);
        }
    }
}
