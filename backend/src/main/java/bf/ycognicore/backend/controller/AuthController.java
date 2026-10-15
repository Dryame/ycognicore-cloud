package bf.ycognicore.backend.controller;

import bf.ycognicore.backend.dto.LoginRequest;
import bf.ycognicore.backend.dto.LoginResponse;
import bf.ycognicore.backend.dto.RefreshRequest;
import bf.ycognicore.backend.dto.RefreshResponse;
import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.service.AuthDispatcherService;
import bf.ycognicore.backend.service.AuthMfaAwareService;
import bf.ycognicore.backend.dto.ChangePasswordRequest;
import bf.ycognicore.backend.repository.tenant.UserRepository;
import bf.ycognicore.backend.service.SessionService;
import bf.ycognicore.backend.service.TokenService;
import org.springframework.security.crypto.password.PasswordEncoder;
import bf.ycognicore.backend.service.RefreshService;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private static final Logger logger = LoggerFactory.getLogger(AuthController.class);

    private final AuthMfaAwareService authMfaAware;
    private final RefreshService refreshService;
    private final PasswordEncoder passwordEncoder;
    private final UserRepository userRepository;
    private final SessionService sessionService;
    private final TokenService tokenService;

    public AuthController(AuthMfaAwareService authMfaAware,
                           RefreshService refreshService,
                           PasswordEncoder passwordEncoder,
                           UserRepository userRepository,
                           SessionService sessionService,
                           TokenService tokenService) {
        this.authMfaAware = authMfaAware;
        this.refreshService = refreshService;
        this.passwordEncoder = passwordEncoder;
        this.userRepository = userRepository;
        this.sessionService = sessionService;
        this.tokenService = tokenService;
    }

    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@Valid @RequestBody LoginRequest req) {
        return ResponseEntity.ok(authMfaAware.authenticate(req));
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

    /**
     * Changement de mot de passe (F4). Invalide toutes les sessions sauf la courante.
     * Ref. : F4, N-3, D-13.
     */
    @PostMapping("/change-password")
    public ResponseEntity<Map<String, Object>> changePassword(
            @Valid @RequestBody ChangePasswordRequest req,
            Authentication auth,
            @org.springframework.web.bind.annotation.RequestHeader(value = "Authorization", required = false) String authorization) {

        if (auth == null || auth.getName() == null) {
            return ResponseEntity.status(401).build();
        }

        var userOpt = userRepository.findById(UUID.fromString(auth.getName()));
        if (userOpt.isEmpty()) {
            return ResponseEntity.status(401).build();
        }
        var user = userOpt.get();

        // 1. Verifier l'ancien mot de passe
        if (!passwordEncoder.matches(req.ancienMotDePasse(), user.getMotDePasseHash())) {
            logger.warn("Change MDP refuse : ancien incorrect user={}", user.getId());
            return ResponseEntity.status(400).body(Map.of("error", "Ancien mot de passe incorrect"));
        }

        // 2. Hacher et mettre a jour
        user.setMotDePasseHash(passwordEncoder.encode(req.nouveauMotDePasse()));
        user.setMotDePasseAChanger(false);
        userRepository.save(user);

        // 3. Revoquer toutes les sessions sauf la courante
        UUID currentSessionId = null;
        if (authorization != null && authorization.startsWith("Bearer ")) {
            try {
                String jti = tokenService.extractJti(authorization.substring(7).trim());
                currentSessionId = tokenService.extractSessionIdFromJtiOrId(jti);
            } catch (Exception ignored) {}
        }
        String tenantCode = TenantContext.getTenantId();
        if (tenantCode != null) {
            try {
                sessionService.revokeAll(tenantCode, user.getId(),
                    "CHANGEMENT_MDP", currentSessionId);
            } catch (Exception e) {
                logger.warn("revokeAll apres change MDP echoue : {}", e.getMessage());
                return ResponseEntity.status(503).body(Map.of("error", "Service indisponible"));
            }
        }

        logger.info("Mot de passe change user={}", user.getId());
        return ResponseEntity.ok(Map.of("success", true, "message", "Mot de passe change"));
    }

}
