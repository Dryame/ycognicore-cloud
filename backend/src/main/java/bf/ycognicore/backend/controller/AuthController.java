package bf.ycognicore.backend.controller;

import bf.ycognicore.backend.dto.LoginRequest;
import bf.ycognicore.backend.dto.LoginResponse;
import bf.ycognicore.backend.service.AuthDispatcherService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Endpoints d'authentification (Auth Dispatcher).
 * Ref. : NFR-SEC-06, NFR-SEC-11, BL-011
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthDispatcherService authDispatcher;

    public AuthController(AuthDispatcherService authDispatcher) {
        this.authDispatcher = authDispatcher;
    }

    /**
     * Login unique : identifie le profil et retourne un JWT.
     */
    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@Valid @RequestBody LoginRequest req) {
        return ResponseEntity.ok(authDispatcher.authenticate(req));
    }

    /**
     * Retourne les infos du user connecte (subject du JWT).
     */
    @GetMapping("/me")
    public ResponseEntity<Map<String, Object>> me(Authentication auth) {
        if (auth == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(Map.of(
                "userId", auth.getName(),
                "authenticated", auth.isAuthenticated(),
                "authorities", auth.getAuthorities()
        ));
    }

    /**
     * Placeholder refresh (implementation complete prevue en H2).
     */
    @PostMapping("/refresh")
    public ResponseEntity<Map<String, String>> refresh(@RequestBody Map<String, String> body) {
        return ResponseEntity.status(501).body(Map.of(
                "error", "Not implemented yet",
                "hint", "Prevu en H2"
        ));
    }
}
