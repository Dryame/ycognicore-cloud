package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.tenant.WorkflowDefinition;
import bf.ycognicore.backend.repository.tenant.WorkflowDefinitionRepository;
import bf.ycognicore.backend.repository.tenant.WorkflowExecutionRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class WorkflowEngineIT {

    @Mock
    private WorkflowDefinitionRepository definitionRepo;

    @Mock
    private WorkflowExecutionRepository executionRepo;

    private WorkflowEngineService workflowEngine;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        // Instanciation manuelle pour fournir le vrai ObjectMapper
        workflowEngine = new WorkflowEngineService(definitionRepo, executionRepo, objectMapper);
    }

    @Test
    void executeWorkflows_declenche_les_actions_et_journalise() {
        // 1. Préparation des données
        UUID eventId = UUID.randomUUID();
        String typeEvenement = "vente.commande.creee";
        String payloadJson = "{\"montant\": 150000, \"client\": \"ACME\"}";

        WorkflowDefinition definition = new WorkflowDefinition();
        definition.setId(UUID.randomUUID());
        definition.setNom("Test Workflow");
        definition.setTypeEvenement(typeEvenement);
        definition.setActif(true);
        
        ObjectNode actions = objectMapper.createObjectNode();
        actions.putArray("actions").addObject().put("type", "NOTIFIER");
        definition.setActions(actions);

        when(definitionRepo.findByTypeEvenementAndActifTrue(typeEvenement))
                .thenReturn(List.of(definition));

        // 2. Exécution
        workflowEngine.executeWorkflows(typeEvenement, payloadJson, eventId);

        // 3. Vérifications
        verify(executionRepo, times(1)).save(argThat(execution -> 
            execution.getStatut().equals("SUCCES") && 
            execution.getEventId().equals(eventId) &&
            execution.getWorkflow().getNom().equals("Test Workflow")
        ));
    }

    @Test
    void executeWorkflows_ignore_les_workflows_inactifs() {
        UUID eventId = UUID.randomUUID();
        String typeEvenement = "vente.commande.creee";
        String payloadJson = "{}";

        // On simule l'absence de workflow actif
        when(definitionRepo.findByTypeEvenementAndActifTrue(typeEvenement))
                .thenReturn(List.of());

        workflowEngine.executeWorkflows(typeEvenement, payloadJson, eventId);

        verify(executionRepo, never()).save(any());
    }
}
