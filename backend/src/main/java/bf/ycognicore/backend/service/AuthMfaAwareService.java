package bf.ycognicore.backend.service;

import bf.ycognicore.backend.dto.LoginRequest;
import bf.ycognicore.backend.dto.LoginResponse;
import bf.ycognicore.backend.repository.controlplane.TenantRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
public class AuthMfaAwareService {
    private static final Logger log = LoggerFactory.getLogger(AuthMfaAwareService.class);

    private final AuthDispatcherService authDispatcher;
    private final UserService userService;
    private final TenantRepository tenantRepository;
    private final MfaChallengeService challengeService;

    public AuthMfaAwareService(AuthDispatcherService authDispatcher,
                               UserService userService,
                               TenantRepository tenantRepository,
                               MfaChallengeService challengeService) {
        this.authDispatcher = authDispatcher;
        this.userService = userService;
        this.tenantRepository = tenantRepository;
        this.challengeService = challengeService;
    }

    public LoginResponse authenticate(LoginRequest req) {
        LoginResponse response = authDispatcher.authenticate(req);

        String email = req.email();
        if (req.tenantCode() == null || req.tenantCode().isBlank()) {
            return response; // Superadmin : pas de MFA
        }

        UUID tenantId = tenantRepository.findByCode(req.tenantCode().trim().toUpperCase())
                .orElseThrow().getId();

        boolean mfaRequired = userService.findByEmail(email, tenantId)
                .filter(u -> u.isMfaEnabled() && u.getMfaSecretPackage() != null)
                .isPresent();

        if (!mfaRequired) {
            return response;
        }

        UUID userId = null;
        if (response.user() != null && response.user().userId() != null) {
            try { userId = UUID.fromString(response.user().userId()); }
            catch (Exception ignored) {}
        }
        if (userId == null) {
            log.warn("MFA requis mais userId introuvable pour {}", email);
            throw new IllegalStateException("MFA requis mais identifiant manquant");
        }

        String challengeToken = challengeService.create(userId, req.tenantCode());
        log.info("MFA requis pour {} - challenge emis", email);
        return LoginResponse.mfaRequired(challengeToken, response.user());
    }
}
