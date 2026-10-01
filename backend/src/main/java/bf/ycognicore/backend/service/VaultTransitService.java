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

    public VaultTransitService(VaultProperties props) {
        this.transitKey = props.getTransitKey();
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
}
