package bf.ycognicore.backend.service;

import bf.ycognicore.backend.config.VaultProperties;
import com.warrenstrange.googleauth.GoogleAuthenticator;
import com.warrenstrange.googleauth.GoogleAuthenticatorKey;
import com.warrenstrange.googleauth.GoogleAuthenticatorQRGenerator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

/**
 * Service MFA : generation secret TOTP, chiffrement via Vault,
 * verification du code a 6 chiffres.
 *
 * Ref. : ADR-002, ADR-005, NFR-SEC-21, NFR-SEC-07, BL-012
 */
@Service
public class MfaService {

    private static final Logger logger = LoggerFactory.getLogger(MfaService.class);

    private final VaultTransitService vault;
    private final VaultProperties props;
    private final GoogleAuthenticator gAuth = new GoogleAuthenticator();

    public MfaService(VaultTransitService vault, VaultProperties props) {
        this.vault = vault;
        this.props = props;
    }

    /**
     * Genere un nouveau secret TOTP pour un utilisateur.
     * Retourne le secret en clair (a afficher une seule fois) + l'URL otpauth://.
     */
    public MfaSetupResult setup(String userEmail) {
        GoogleAuthenticatorKey key = gAuth.createCredentials();
        String secret = key.getKey();

        String qrUrl = GoogleAuthenticatorQRGenerator.getOtpAuthTotpURL(
                props.getIssuer(), userEmail, key);

        logger.info("MFA setup pour {} (secret genere, {}-char)", userEmail, secret.length());
        return new MfaSetupResult(secret, qrUrl);
    }

    /**
     * Empaquette un secret (JSON serialise) et le chiffre via Vault.
     * Retourne la string JSONB a stocker dans mfa_secret_package.
     */
    public String encryptSecret(String secret) {
        String ciphertext = vault.encrypt(secret);
        // Format JSONB auto-descriptif (ADR-005)
        String json = String.format(
                "{\"algo\":\"aes256-gcm96\",\"vault_ct\":\"%s\",\"version\":1,\"created_at\":\"%s\"}",
                ciphertext, Instant.now().toString());
        return json;
    }

    /**
     * Dechiffre un package JSONB (mfa_secret_package) et retourne le secret en clair.
     */
    public String decryptSecret(String jsonPackage) {
        // Extraction naive du ciphertext (pas de dep JSON lourde)
        String marker = "\"vault_ct\":\"";
        int start = jsonPackage.indexOf(marker);
        if (start < 0) {
            throw new IllegalArgumentException("Format package MFA invalide : vault_ct absent");
        }
        start += marker.length();
        int end = jsonPackage.indexOf('"', start);
        if (end < 0) {
            throw new IllegalArgumentException("Format package MFA invalide : fin de chaine absente");
        }
        String ciphertext = jsonPackage.substring(start, end);
        return vault.decrypt(ciphertext);
    }

    /**
     * Verifie un code TOTP a 6 chiffres contre le secret en clair.
     */
    public boolean verifyCode(String secret, int code) {
        boolean ok = gAuth.authorize(secret, code);
        logger.debug("Verification MFA : resultat={}", ok);
        return ok;
    }

    /**
     * Resultat d'un setup MFA : secret en clair + URL QR.
     */
    public record MfaSetupResult(String secret, String qrUrl) {}

    /**
     * Resultat d'une verification MFA : statut + message.
     */
    public record MfaVerifyResult(boolean success, String message) {}
}
