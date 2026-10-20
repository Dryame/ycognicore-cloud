package bf.ycognicore.backend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.HexFormat;

/**
 * HMAC-SHA256 pour la recherche exacte sur champs chiffres.
 * Normalisation par champ avant calcul (D-P4-4, D-P4-9, ADR-042).
 * Ref. : P4 L2, fiche P4 section 5.1.
 */
@Service
public class HmacService {

    private static final Logger log = LoggerFactory.getLogger(HmacService.class);
    private static final String ALGORITHM = "HmacSHA256";

    public String hmac(String field, String value, byte[] hmacKey) {
        if (value == null || value.isBlank()) return null;
        if (hmacKey == null || hmacKey.length < 16) {
            throw new IllegalArgumentException("Cle HMAC invalide (min 16 octets)");
        }

        String normalized = normalize(field, value);
        if (normalized == null || normalized.isEmpty()) return null;

        try {
            Mac mac = Mac.getInstance(ALGORITHM);
            mac.init(new SecretKeySpec(hmacKey, ALGORITHM));
            byte[] result = mac.doFinal(normalized.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(result);
        } catch (Exception e) {
            log.error("Calcul HMAC echoue pour field={} : {}", field, e.getMessage());
            throw new IllegalStateException("HMAC indisponible", e);
        }
    }

    public String normalize(String field, String value) {
        if (value == null) return null;

        return switch (field) {
            case "EMAIL" -> value.trim().toLowerCase();
            case "IFU", "RCCM" -> value.trim()
                .replaceAll("[\\s\\-\\.\\/]", "")
                .toUpperCase();
            case "TELEPHONE" -> normalizeTelephone(value);
            default -> value.trim();
        };
    }

    private String normalizeTelephone(String value) {
        String cleaned = value.trim().replaceAll("[\\s\\-\\.\\(\\)]", "");
        if (cleaned.startsWith("+226")) cleaned = cleaned.substring(4);
        else if (cleaned.startsWith("00226")) cleaned = cleaned.substring(5);
        else if (cleaned.startsWith("226") && cleaned.length() == 11) cleaned = cleaned.substring(3);
        return cleaned;
    }
}
