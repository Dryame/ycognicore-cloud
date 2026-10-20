package bf.ycognicore.backend.service;

import bf.ycognicore.backend.config.VaultProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Map;

/**
 * Client HTTP pour Vault transit encrypt/decrypt.
 * La cle ne sort jamais de Vault (ADR-002).
 *
 * Ref. : ADR-002, ADR-005, NFR-SEC-21, BL-012
 */
@Service
public class VaultTransitService {

    private static final Logger logger = LoggerFactory.getLogger(VaultTransitService.class);

    private final RestClient client;
    private final String transitKey;
    private final String masterKey;

    public VaultTransitService(VaultProperties props) {
        this.transitKey = props.getTransitKey();
        this.masterKey = props.getMasterKey() != null
            ? props.getMasterKey() : "ycc-master-key";
        this.client = RestClient.builder()
                .baseUrl(props.getUrl())
                .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .defaultHeader("X-Vault-Token", props.getToken())
                .build();
    }

    /**
     * Chiffre un texte clair. Retourne le ciphertext Vault (vault:v1:...).
     */
    @SuppressWarnings("unchecked")
    public String encrypt(String plaintext) {
        String b64 = Base64.getEncoder()
                .encodeToString(plaintext.getBytes(StandardCharsets.UTF_8));

        Map<String, Object> body = Map.of("plaintext", b64);

        Map<String, Object> resp = client.post()
                .uri("/v1/transit/encrypt/{key}", transitKey)
                .body(body)
                .retrieve()
                .body(Map.class);

        if (resp == null || resp.get("data") == null) {
            throw new IllegalStateException("Reponse Vault encrypt invalide");
        }
        Map<String, Object> data = (Map<String, Object>) resp.get("data");
        String ct = (String) data.get("ciphertext");
        logger.debug("Vault encrypt OK (key={})", transitKey);
        return ct;
    }

    /**
     * Dechiffre un ciphertext Vault. Retourne le texte clair.
     */
    @SuppressWarnings("unchecked")
    public String decrypt(String ciphertext) {
        Map<String, Object> body = Map.of("ciphertext", ciphertext);

        Map<String, Object> resp = client.post()
                .uri("/v1/transit/decrypt/{key}", transitKey)
                .body(body)
                .retrieve()
                .body(Map.class);

        if (resp == null || resp.get("data") == null) {
            throw new IllegalStateException("Reponse Vault decrypt invalide");
        }
        Map<String, Object> data = (Map<String, Object>) resp.get("data");
        String b64 = (String) data.get("plaintext");
        logger.debug("Vault decrypt OK (key={})", transitKey);
        return new String(Base64.getDecoder().decode(b64), StandardCharsets.UTF_8);
    }

    /**
     * Genere une cle de donnees AES-256 via Vault Transit.
     * Le plaintext est en memoire ; le ciphertext (vault:vN:...) est a persister.
     * Ref. : D-P4-1.
     */
    @SuppressWarnings("unchecked")
    public DataKeyResult generateDataKey() {
        Map<String, Object> resp = client.post()
            .uri("/v1/transit/datakey/plaintext/{key}", masterKey)
            .body(Map.of())
            .retrieve()
            .body(Map.class);

        if (resp == null || resp.get("data") == null) {
            throw new IllegalStateException("Reponse Vault datakey invalide");
        }
        Map<String, Object> data = (Map<String, Object>) resp.get("data");
        String plaintextB64 = (String) data.get("plaintext");
        String ciphertext = (String) data.get("ciphertext");
        if (plaintextB64 == null || ciphertext == null) {
            throw new IllegalStateException("Reponse Vault datakey incomplete");
        }
        byte[] plaintext = Base64.getDecoder().decode(plaintextB64);
        logger.debug("Vault datakey genere ({} octets, {})", plaintext.length, ciphertext);
        return new DataKeyResult(plaintext, ciphertext);
    }

    /**
     * Dechiffre une cle de donnees enveloppee (vault:vN:...).
     * Retourne les 32 octets de la cle AES-256.
     * Ref. : D-P4-1.
     */
    @SuppressWarnings("unchecked")
    public byte[] decryptWrapped(String ciphertext) {
        Map<String, Object> body = Map.of("ciphertext", ciphertext);
        Map<String, Object> resp = client.post()
            .uri("/v1/transit/decrypt/{key}", masterKey)
            .body(body)
            .retrieve()
            .body(Map.class);

        if (resp == null || resp.get("data") == null) {
            throw new IllegalStateException("Reponse Vault decrypt invalide");
        }
        Map<String, Object> data = (Map<String, Object>) resp.get("data");
        String plaintextB64 = (String) data.get("plaintext");
        if (plaintextB64 == null) {
            throw new IllegalStateException("Reponse Vault decrypt sans plaintext");
        }
        return Base64.getDecoder().decode(plaintextB64);
    }

    /** Resultat d'une generation de cle : plaintext AES + ciphertext enveloppe. */
    public record DataKeyResult(byte[] plaintext, String ciphertext) {}
}
