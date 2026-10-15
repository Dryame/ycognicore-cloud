package bf.ycognicore.backend.controller;

import bf.ycognicore.backend.dto.MfaSetupResponse;
import bf.ycognicore.backend.dto.MfaVerifyRequest;
import bf.ycognicore.backend.service.MfaChallengeService;
import bf.ycognicore.backend.service.MfaService;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Endpoints MFA (setup + verification).
 * Ref. : NFR-SEC-07, NFR-SEC-21, BL-012
 */
@RestController
@RequestMapping("/api/auth/mfa")
public class MfaController {

    private static final Logger logger = LoggerFactory.getLogger(MfaController.class);

    private final MfaService mfaService;
    private final MfaChallengeService mfaChallengeService;
    private final bf.ycognicore.backend.repository.tenant.UserRepository userRepository;

    public MfaController(MfaService mfaService,
                          MfaChallengeService mfaChallengeService,
                          bf.ycognicore.backend.repository.tenant.UserRepository userRepository) {
        this.mfaService = mfaService;
        this.mfaChallengeService = mfaChallengeService;
        this.userRepository = userRepository;
    }

    /**
     * Genere un nouveau secret TOTP pour l'utilisateur connecte.
     * Le secret n'est PAS encore stocke en base (voir /verify).
     */
    @PostMapping("/setup")
    public ResponseEntity<MfaSetupResponse> setup(Authentication auth) {
        if (auth == null) {
            return ResponseEntity.status(401).build();
        }
        String email = (String) auth.getPrincipal();
        logger.info("MFA setup demande par {}", email);

        var result = mfaService.setup(email);
        return ResponseEntity.ok(new MfaSetupResponse(
                result.secret(),
                result.qrUrl(),
                "Scannez le QR code avec Google Authenticator puis validez avec /verify"
        ));
    }

    /**
     * Verifie un code TOTP contre un secret fourni en clair.
     * (En BL-012, on ne stocke pas encore le package chiffre - ce sera un BL ulterieur)
     */
    @PostMapping("/verify")
    public ResponseEntity<Map<String, Object>> verify(
            @Valid @RequestBody MfaVerifyRequest req,
            Authentication auth) {
        if (auth == null) {
            return ResponseEntity.status(401).build();
        }

        boolean ok = mfaService.verifyCode(req.secret(), req.code());
        logger.info("MFA verify pour {} : {}", auth.getName(), ok);

        if (ok) {
            return ResponseEntity.ok(Map.of(
                    "success", true,
                    "message", "Code MFA valide"
            ));
        }
        return ResponseEntity.status(400).body(Map.of(
                "success", false,
                "message", "Code MFA invalide"
        ));
    }

    /**
     * Verification MFA par challenge (F1).
     * Remplace l'ancien /verify (secret en clair).
     */
    @org.springframework.web.bind.annotation.PostMapping("/challenge-verify")
    public org.springframework.http.ResponseEntity<bf.ycognicore.backend.dto.LoginResponse> verifyChallenge(
            @jakarta.validation.Valid @org.springframework.web.bind.annotation.RequestBody
            bf.ycognicore.backend.dto.MfaChallengeVerifyRequest req,
            org.springframework.security.core.Authentication auth) {

        var challenge = mfaChallengeService.consume(req.challengeToken());
        if (challenge == null) {
            return org.springframework.http.ResponseEntity.status(401).build();
        }

        int code;
        try { code = Integer.parseInt(req.code()); }
        catch (NumberFormatException e) {
            return org.springframework.http.ResponseEntity.status(400).build();
        }

        var user = userRepository.findById(challenge.userId()).orElse(null);
        if (user == null || !user.isMfaEnabled() || user.getMfaSecretPackage() == null) {
            return org.springframework.http.ResponseEntity.status(401).build();
        }

        boolean ok = mfaService.verifyCode(
            mfaService.decryptSecret(user.getMfaSecretPackage()), code);
        if (!ok) {
            return org.springframework.http.ResponseEntity.status(401).build();
        }

        // Emettre les tokens via AuthDispatcherService (deja valides par challenge)
        // Simplification : on retourne juste 200 pour l'instant, la generation
        // complete des tokens sera branchee en L3.5 avec SessionService.create()
        return org.springframework.http.ResponseEntity.ok().build();
    }

}
