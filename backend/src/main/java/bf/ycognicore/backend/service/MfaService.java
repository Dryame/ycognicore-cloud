package bf.ycognicore.backend.service;

import bf.ycognicore.backend.config.VaultProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.warrenstrange.googleauth.GoogleAuthenticator;
import com.warrenstrange.googleauth.GoogleAuthenticatorKey;
import com.warrenstrange.googleauth.GoogleAuthenticatorQRGenerator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.Instant;

@Service
public class MfaService {

    private static final Logger logger = LoggerFactory.getLogger(MfaService.class);

    private final VaultTransitService vault;
    private final VaultProperties props;
    private final ObjectMapper objectMapper;
    private final GoogleAuthenticator gAuth = new GoogleAuthenticator();

    public MfaService(VaultTransitService vault, VaultProperties props, ObjectMapper objectMapper) {
        this.vault = vault;
        this.props = props;
        this.objectMapper = objectMapper;
    }

    public MfaSetupResult setup(String userEmail) {
        GoogleAuthenticatorKey key = gAuth.createCredentials();
        String secret = key.getKey();
        String qrUrl = GoogleAuthenticatorQRGenerator.getOtpAuthTotpURL(
                props.getIssuer(), userEmail, key);
        logger.info("MFA setup pour {} (secret genere, {}-char)", userEmail, secret.length());
        return new MfaSetupResult(secret, qrUrl);
    }

    public JsonNode encryptSecret(String secret) {
        String ciphertext = vault.encrypt(secret);
        ObjectNode node = objectMapper.createObjectNode();
        node.put("algo", "aes256-gcm96");
        node.put("vault_ct", ciphertext);
        node.put("version", 1);
        node.put("created_at", Instant.now().toString());
        return node;
    }

    public String decryptSecret(JsonNode jsonPackage) {
        if (jsonPackage == null || !jsonPackage.has("vault_ct")) {
            throw new IllegalArgumentException("Format package MFA invalide : vault_ct absent");
        }
        String ciphertext = jsonPackage.get("vault_ct").asText();
        return vault.decrypt(ciphertext);
    }

    public boolean verifyCode(String secret, int code) {
        boolean ok = gAuth.authorize(secret, code);
        logger.debug("Verification MFA : resultat={}", ok);
        return ok;
    }

    public record MfaSetupResult(String secret, String qrUrl) {}

    public record MfaVerifyResult(boolean success, String message) {}
}
