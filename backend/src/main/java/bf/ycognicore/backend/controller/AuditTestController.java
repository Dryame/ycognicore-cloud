package bf.ycognicore.backend.controller;

import bf.ycognicore.backend.audit.Auditable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.OffsetDateTime;
import java.util.Map;

/**
 * Endpoints de test BL-014 (Audit AOP).
 */
@RestController
@RequestMapping("/api/_poc/audit")
public class AuditTestController {

    @GetMapping("/read")
    @Auditable(action = "LECTURE_TEST", module = "TEST", entite = "audit_test")
    public ResponseEntity<Map<String, Object>> read(Authentication auth) {
        return ResponseEntity.ok(Map.of(
                "endpoint", "audit/read",
                "action", "LECTURE_TEST",
                "user", auth.getName(),
                "timestamp", OffsetDateTime.now().toString()
        ));
    }

    @PostMapping("/write")
    @Auditable(action = "ECRITURE_TEST", module = "TEST", entite = "audit_test",
               niveau = "SECURITE")
    public ResponseEntity<Map<String, Object>> write(@RequestBody(required = false) Map<String, Object> body,
                                                      Authentication auth) {
        return ResponseEntity.ok(Map.of(
                "endpoint", "audit/write",
                "action", "ECRITURE_TEST",
                "user", auth.getName(),
                "received", body != null ? body.size() : 0
        ));
    }

    @GetMapping("/fail")
    @Auditable(action = "ECHEC_TEST", module = "TEST", entite = "audit_test", niveau = "ERROR")
    public ResponseEntity<Map<String, Object>> fail() {
        throw new RuntimeException("Erreur simulee pour test audit");
    }
}
