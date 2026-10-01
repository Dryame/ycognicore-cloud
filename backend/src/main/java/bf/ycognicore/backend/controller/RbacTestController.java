package bf.ycognicore.backend.controller;

import bf.ycognicore.backend.security.RequirePermission;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.util.Map;

/**
 * Endpoints de test RBAC (BL-013).
 * Seront supprimes apres validation.
 */
@RestController
@RequestMapping("/api/_poc/rbac")
public class RbacTestController {

    @GetMapping("/public")
    public ResponseEntity<Map<String, Object>> publicEndpoint(Authentication auth) {
        return ResponseEntity.ok(Map.of(
                "endpoint", "public",
                "requiresPermission", false,
                "user", auth != null ? auth.getName() : "anonymous",
                "timestamp", OffsetDateTime.now().toString()
        ));
    }

    @GetMapping("/ventes/lire")
    @RequirePermission(module = "VENTES", permission = "LIRE")
    public ResponseEntity<Map<String, Object>> ventesLire(Authentication auth) {
        return ResponseEntity.ok(Map.of(
                "endpoint", "ventes/lire",
                "requiresPermission", "VENTES.LIRE",
                "user", auth.getName(),
                "granted", true
        ));
    }

    @GetMapping("/comptabilite/valider")
    @RequirePermission(module = "COMPTABILITE", permission = "VALIDER")
    public ResponseEntity<Map<String, Object>> comptaValider(Authentication auth) {
        return ResponseEntity.ok(Map.of(
                "endpoint", "comptabilite/valider",
                "requiresPermission", "COMPTABILITE.VALIDER",
                "user", auth.getName(),
                "granted", true
        ));
    }
}
