package bf.ycognicore.backend.service;

import bf.ycognicore.backend.dto.LoginRequest;
import bf.ycognicore.backend.dto.LoginResponse;
import bf.ycognicore.backend.repository.tenant.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.UUID;

/**
 * Wrap AuthDispatcherService : ajoute la verification MFA obligatoire.
 * Si user.mfa_enabled=true -> retourne mfaRequired + challengeToken.
 * Ref. : F1, T3.2.
 */
@Service
public class AuthMfaAwareService {

    private static final Logger log = LoggerFactory.getLogger(AuthMfaAwareService.class);

    private final AuthDispatcherService authDispatcher;
    private final UserRepository userRepository;
    private final MfaChallengeService challengeService;

    public AuthMfaAwareService(AuthDispatcherService authDispatcher,
                               UserRepository userRepository,
                               MfaChallengeService challengeService) {
        this.authDispatcher = authDispatcher;
        this.userRepository = userRepository;
        this.challengeService = challengeService;
    }

    /** Point d'entree : dispatche + verifie MFA. */
    public LoginResponse authenticate(LoginRequest req) {
        // 1. Deleguer a AuthDispatcherService (mot de passe + statut)
        LoginResponse response = authDispatcher.authenticate(req);

        // 2. Verifier si MFA requis (uniquement comptes tenant, pas superadmin)
        String email = req.email();
        boolean mfaRequired = userRepository.findByEmail(email)
            .filter(u -> u.isMfaEnabled() && u.getMfaSecretPackage() != null)
            .isPresent();

        if (!mfaRequired) {
            return response;
        }

        // 3. MFA requis : ne pas emettre de tokens, emettre un challenge
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
        log.info("MFA requis pour {} — challenge emis", email);

        return LoginResponse.mfaRequired(challengeToken, response.user());
    }
}
