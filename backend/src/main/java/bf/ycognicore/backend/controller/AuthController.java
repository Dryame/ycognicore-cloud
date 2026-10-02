package bf.ycognicore.backend.controller;

import bf.ycognicore.backend.dto.LoginRequest;
import bf.ycognicore.backend.dto.LoginResponse;
import bf.ycognicore.backend.dto.RefreshRequest;
import bf.ycognicore.backend.dto.RefreshResponse;
import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.service.AuthDispatcherService;
import bf.ycognicore.backend.service.RefreshService;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private static final Logger logger = LoggerFactory.getLogger(AuthController.class);

    private final AuthDispatcherService authDispatcher;
    private final RefreshService refreshService;

    public AuthController(AuthDispatcherService authDispatcher,
                          RefreshService refreshService) {
        this.authDispatcher = authDispatcher;
        this.refreshService = refreshService;
    }

    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@Valid @RequestBody LoginRequest req) {
        return ResponseEntity.ok(authDispatcher.authenticate(req));
    }

    @PostMapping("/refresh")
    public ResponseEntity<RefreshResponse> refresh(@Valid @RequestBody RefreshRequest req) {
        // Le tenant est requis pour retrouver l'utilisateur en base
        // (soit via header X-Tenant-Code, soit via le filtrage JWT)
        String tenantCode = TenantContext.getTenantId();
        logger.info("Refresh demande (tenant={})", tenantCode != null ? tenantCode : "superadmin");
        return ResponseEntity.ok(refreshService.refresh(req.refreshToken()));
    }

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
}
