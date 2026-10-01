package bf.ycognicore.backend.controller;

import bf.ycognicore.backend.multitenant.TenantContext;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Controleur de validation du POC BL-010 (routing multi-tenant).
 * Temporaire : sera supprime apres validation du POC.
 *
 * Ref. : ADR-006, BL-010
 */
@RestController
@RequestMapping("/api/_poc")
public class PocTenantController {

    @PersistenceContext(unitName = "tenant")
    private EntityManager tenantEntityManager;

    @GetMapping("/whoami")
    public ResponseEntity<Map<String, Object>> whoami() {
        Map<String, Object> body = new LinkedHashMap<>();

        String tenantCode = TenantContext.getTenantId();
        body.put("tenantCode", tenantCode != null ? tenantCode : "(aucun)");
        body.put("hasTenant", TenantContext.hasTenant());
        body.put("serverTime", OffsetDateTime.now().toString());

        if (tenantCode == null) {
            body.put("warning",
                    "Header X-Tenant-Code absent - aucune base tenant ne peut etre resolue");
            return ResponseEntity.ok(body);
        }

        try {
            Object[] row = (Object[]) tenantEntityManager
                    .createNativeQuery("SELECT current_database(), current_user")
                    .getSingleResult();
            body.put("pgDatabase", row[0]);
            body.put("pgUser", row[1]);
            body.put("routing", "OK");
        } catch (Exception e) {
            body.put("routing", "ERREUR");
            body.put("error", e.getClass().getSimpleName() + " : " + e.getMessage());
        }

        return ResponseEntity.ok(body);
    }
}
