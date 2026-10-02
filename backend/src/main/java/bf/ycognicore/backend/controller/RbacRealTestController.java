package bf.ycognicore.backend.controller;

import bf.ycognicore.backend.security.RequirePermission;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/rbac-test")
public class RbacRealTestController {

    @GetMapping("/ventes/lire")
    @RequirePermission(module = "VENTES", permission = "LIRE")
    public ResponseEntity<Map<String, Object>> ventesLire(Authentication auth) {
        return ResponseEntity.ok(Map.of(
                "endpoint", "rbac-test/ventes/lire",
                "requiresPermission", "VENTES.LIRE",
                "user", auth.getName(),
                "granted", true
        ));
    }

    @GetMapping("/comptabilite/valider")
    @RequirePermission(module = "COMPTABILITE", permission = "VALIDER")
    public ResponseEntity<Map<String, Object>> comptaValider(Authentication auth) {
        return ResponseEntity.ok(Map.of(
                "endpoint", "rbac-test/comptabilite/valider",
                "requiresPermission", "COMPTABILITE.VALIDER",
                "user", auth.getName(),
                "granted", true
        ));
    }
}
