package bf.ycognicore.backend.controller;

import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.service.EventPublisherService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

/**
 * Contrôleur de démonstration pour tester le flux d'événements et de workflow.
 * (À des fins de tests, non destiné à la production).
 */
@RestController
@RequestMapping("/api/demo/workflow")
public class DemoWorkflowController {

    private final EventPublisherService eventPublisher;

    public DemoWorkflowController(EventPublisherService eventPublisher) {
        this.eventPublisher = eventPublisher;
    }

    @PostMapping("/vente")
    public ResponseEntity<Map<String, String>> simulerVente(@RequestBody Map<String, Object> payload) {
        // On définit le contexte manuellement puisque ce n'est pas un vrai utilisateur authentifié
        TenantContext.setTenantId("DEMO001");
        try {
            // On publie un événement de type "vente.commande.creee"
            eventPublisher.publish(
                    "vente.commande.creee", 
                    "Vente", 
                    UUID.randomUUID(), 
                    payload
            );
            return ResponseEntity.ok(Map.of(
                "status", "Événement publié",
                "message", "Le workflow asynchrone va s'exécuter dans les secondes à venir."
            ));
        } finally {
            TenantContext.clear();
        }
    }
}
