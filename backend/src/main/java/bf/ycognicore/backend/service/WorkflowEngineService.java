package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.tenant.WorkflowDefinition;
import bf.ycognicore.backend.entity.tenant.WorkflowExecution;
import bf.ycognicore.backend.repository.tenant.WorkflowDefinitionRepository;
import bf.ycognicore.backend.repository.tenant.WorkflowExecutionRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class WorkflowEngineService {

    private static final Logger log = LoggerFactory.getLogger(WorkflowEngineService.class);

    private final WorkflowDefinitionRepository definitionRepo;
    private final WorkflowExecutionRepository executionRepo;
    private final ObjectMapper objectMapper;

    public WorkflowEngineService(WorkflowDefinitionRepository definitionRepo,
                                 WorkflowExecutionRepository executionRepo,
                                 ObjectMapper objectMapper) {
        this.definitionRepo = definitionRepo;
        this.executionRepo = executionRepo;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public void executeWorkflows(String typeEvenement, String payloadJson, UUID eventId) {
        try {
            JsonNode payload = objectMapper.readTree(payloadJson);
            List<WorkflowDefinition> workflows = definitionRepo.findByTypeEvenementAndActifTrue(typeEvenement);

            for (WorkflowDefinition wf : workflows) {
                if (evaluateConditions(wf.getConditions(), payload)) {
                    executeActions(wf, payload, eventId);
                }
            }
        } catch (Exception e) {
            log.error("Erreur lors de l'exécution du workflow pour l'événement {}", eventId, e);
        }
    }

    private boolean evaluateConditions(JsonNode conditions, JsonNode payload) {
        // Pour l'instant, si pas de conditions, on exécute toujours
        if (conditions == null || conditions.isEmpty()) return true;
        
        // TODO: Implémenter le moteur d'évaluation JSON (ex: data.montant > 100000)
        // Pour la Phase 5, on simule une évaluation basique
        return true; 
    }

    private void executeActions(WorkflowDefinition wf, JsonNode payload, UUID eventId) {
        log.info("Exécution du workflow '{}' pour l'événement {}", wf.getNom(), eventId);
        
        JsonNode actions = wf.getActions();
        if (actions != null && actions.isArray()) {
            for (JsonNode action : actions) {
                String typeAction = action.path("type").asText();
                log.info(" -> Action exécutée : {}", typeAction);
                // Simulation de l'action (dans un vrai système, on appellerait le service métier)
            }
        }

        // Journalisation de l'exécution
        WorkflowExecution execution = new WorkflowExecution();
        execution.setWorkflow(wf);
        execution.setEventId(eventId);
        execution.setStatut("SUCCES");
        execution.setJournal(payload);
        executionRepo.save(execution);
    }
}
