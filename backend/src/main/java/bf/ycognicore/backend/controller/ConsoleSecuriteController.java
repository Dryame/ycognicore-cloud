package bf.ycognicore.backend.controller;

import bf.ycognicore.backend.security.RequireDroitSpecial;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Console de securite du tenant (F9, 3.3).
 * Acces protege par le droit special CONSOLE_SECURITE (D-11).
 * Endpoints metier a completer en L6.
 */
@RestController
@RequestMapping("/api/console-securite")
@RequireDroitSpecial("CONSOLE_SECURITE")
public class ConsoleSecuriteController {

    /** Ping protege — permet de valider la protection par droit special. */
    @GetMapping("/ping")
    public ResponseEntity<Map<String, Object>> ping() {
        return ResponseEntity.ok(Map.of(
            "status", "ok",
            "message", "Acces console autorise"
        ));
    }
}
