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
import bf.ycognicore.backend.repository.controlplane.TenantRepository;
import bf.ycognicore.backend.service.SessionService;
import bf.ycognicore.backend.service.TokenService;
import bf.ycognicore.backend.service.UserService;
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
    private final UserService userService;
    private final TenantRepository tenantRepository;
    private final SessionService sessionService;
    private final TokenService tokenService;
    private final bf.ycognicore.backend.service.DeviceService deviceService;

    public AuthController(AuthMfaAwareService authMfaAware,
                          RefreshService refreshService,
                          PasswordEncoder passwordEncoder,
                          UserRepository userRepository,
                          UserService userService,
                          TenantRepository tenantRepository,
                          SessionService sessionService,
                          TokenService tokenService,
                          bf.ycognicore.backend.service.DeviceService deviceService) {
        this.authMfaAware = authMfaAware;
        this.refreshService = refreshService;
        this.passwordEncoder = passwordEncoder;
        this.userRepository = userRepository;
        this.userService = userService;
        this.tenantRepository = tenantRepository;
        this.sessionService = sessionService;
        this.tokenService = tokenService;
        this.deviceService = deviceService;
    }

    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@Valid @RequestBody LoginRequest req,
                                               jakarta.servlet.http.HttpServletRequest httpReq) {
        LoginResponse response = authMfaAware.authenticate(req);

        // MFA requis : pas de session tant que MFA non validée
        if (Boolean.TRUE.equals(response.mfaRequired())) {
            return ResponseEntity.ok(response);
        }

        String tenantCode = req.tenantCode();
        if (tenantCode == null || tenantCode.isBlank()) {
            // Superadmin : pas de session (fallback)
            return ResponseEntity.ok(response);
        }

        try {
            UUID userId = UUID.fromString(response.user().userId());
            String ip = extractRealIp(httpReq);
            String userAgent = httpReq.getHeader("User-Agent");
            String acceptLang = httpReq.getHeader("Accept-Language");

            // Appareil : resolveOrCreate
            UUID appareilId = deviceService.resolveOrCreate(
                    tenantCode, userId, userAgent, acceptLang, ip);

            // Créer la session avec le refresh placeholder
            UUID sessionId = sessionService.create(tenantCode, userId, ip,
                    userAgent, appareilId, response.refreshToken());

            // Regenerer access + refresh avec jti = sessionId
            String newAccess = tokenService.generateAccessToken(userId,
                    response.user().email(), response.user().userType(), tenantCode,
                    java.util.List.of(response.user().userType()), sessionId);
            String newRefresh = tokenService.generateRefreshToken(userId, sessionId);

            // Rotation : remplacer le hash placeholder par le vrai
            sessionService.rotateRefresh(tenantCode, sessionId, newRefresh);

            return ResponseEntity.ok(new LoginResponse(
                    newAccess, newRefresh, "Bearer", 1800L, response.user(), false, null));

        } catch (Exception e) {
            logger.warn("Création session après login échouée : {}", e.getMessage());
            // Fail-soft : on retourne la réponse initiale (tokens sans jti)
            return ResponseEntity.ok(response);
        }
    }

    private static String extractRealIp(jakarta.servlet.http.HttpServletRequest req) {
        String xff = req.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) {
            return xff.split(",")[0].trim();
        }
        return req.getRemoteAddr();
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

        // 2. Hacher et mettre à jour
        user.setMotDePasseHash(passwordEncoder.encode(req.nouveauMotDePasse()));
        user.setMotDePasseAChanger(false);

        // Récupération de l'UUID du tenant pour passer par le service sécurisé (L3.4)
        String tenantCode = TenantContext.getTenantId();
        UUID tenantId = tenantRepository.findByCode(tenantCode)
                .orElseThrow(() -> new IllegalStateException("Tenant introuvable"))
                .getId();
        
        userService.save(user, tenantId); // Utilisation du service pour HMAC/Chiffrement

        // 3. Revoquer toutes les sessions sauf la courante
        UUID currentSessionId = null;
        if (authorization != null && authorization.startsWith("Bearer ")) {
            try {
                String jti = tokenService.extractJti(authorization.substring(7).trim());
                currentSessionId = tokenService.extractSessionIdFromJtiOrId(jti);
            } catch (Exception ignored) {}
        }

        if (tenantCode != null) {
            try {
                sessionService.revokeAll(tenantCode, user.getId(),
                        "CHANGEMENT_MDP", currentSessionId);
            } catch (Exception e) {
                logger.warn("revokeAll après change MDP échoue : {}", e.getMessage());
                return ResponseEntity.status(503).body(Map.of("error", "Service indisponible"));
            }
        }

        logger.info("Mot de passe change user={}", user.getId());
        return ResponseEntity.ok(Map.of("success", true, "message", "Mot de passe changé"));
    }
}
