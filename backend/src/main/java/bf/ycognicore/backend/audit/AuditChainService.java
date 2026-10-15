package bf.ycognicore.backend.audit;

import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.HexFormat;
import java.util.UUID;

/**
 * Calcul et écriture de la chaîne d'audit (SHA-256).
 * Formule identique à verifier_chaine_audit() en V17.
 * Ref. : D-03, D17-1, R2 (verrou consultatif).
 */
@Service
public class AuditChainService {

    private static final Logger log = LoggerFactory.getLogger(AuditChainService.class);

    private static final DateTimeFormatter TS_FMT =
        DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSSSSS").withZone(ZoneOffset.UTC);

    private final MultiTenantConnectionProviderImpl connectionProvider;

    public AuditChainService(MultiTenantConnectionProviderImpl connectionProvider) {
        this.connectionProvider = connectionProvider;
    }

    /** Représentation canonique pour le hash — identique à V17. */
    public static String canonicalize(String hashPrecedent, long id, UUID userId,
                                      String action, String entite, UUID entiteId,
                                      OffsetDateTime timestamp, JsonNode details) {
        return nz(hashPrecedent) + "|"
             + id + "|"
             + nz(userId != null ? userId.toString() : null) + "|"
             + nz(action) + "|"
             + nz(entite) + "|"
             + nz(entiteId != null ? entiteId.toString() : null) + "|"
             + TS_FMT.format(timestamp.withOffsetSameInstant(ZoneOffset.UTC)) + "|"
             + nz(details != null ? details.toString() : null);
    }

    public static String sha256Hex(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(input.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 indisponible", e);
        }
    }

    /** Écrit une entrée chaînée dans audit_log pour le tenant courant. */
    public void chainAndPersist(String tenantCode, long id, UUID userId,
                                String action, String entite, UUID entiteId,
                                String module, String niveau, boolean succes,
                                String ip, String userAgent, JsonNode details,
                                OffsetDateTime timestamp) {
        try (Connection conn = connectionProvider.getConnection(tenantCode)) {
            conn.setAutoCommit(false);
            try {
                // 1. Verrou consultatif par tenant (R2)
                try (PreparedStatement ps = conn.prepareStatement(
                        "SELECT pg_advisory_xact_lock(hashtext(?))")) {
                    ps.setString(1, tenantCode);
                    ps.execute();
                }

                // 2. Récupérer le dernier hash de la chaîne
                String hashPrecedent = null;
                try (PreparedStatement ps = conn.prepareStatement(
                        "SELECT hash_entree FROM audit_log " +
                        "WHERE hash_entree IS NOT NULL " +
                        "ORDER BY id DESC LIMIT 1")) {
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) hashPrecedent = rs.getString(1);
                    }
                }

                // 3. Calculer hash_entree
                String canon = canonicalize(hashPrecedent, id, userId, action,
                        entite, entiteId, timestamp, details);
                String hashEntree = sha256Hex(canon);

                // 4. UPDATE de la ligne (écrite d'abord par AuditService)
                try (PreparedStatement ps = conn.prepareStatement(
                        "UPDATE audit_log SET hash_precedent = ?, hash_entree = ? " +
                        "WHERE id = ? AND timestamp = ?")) {
                    ps.setString(1, hashPrecedent);
                    ps.setString(2, hashEntree);
                    ps.setLong(3, id);
                    ps.setObject(4, timestamp);
                    int rows = ps.executeUpdate();
                    if (rows != 1) {
                        throw new IllegalStateException(
                            "Chaînage : UPDATE attendu 1 ligne, obtenu " + rows);
                    }
                }
                conn.commit();
                log.debug("Chaînage OK tenant={} id={} hash={}…",
                    tenantCode, id, hashEntree.substring(0, 12));
            } catch (Exception e) {
                conn.rollback();
                throw e;
            }
        } catch (Exception e) {
            throw new AuditChainException("Échec chaînage tenant=" + tenantCode, e);
        }
    }

    private static String nz(String s) { return s == null ? "" : s; }

    /** Exception spécifique pour permettre au CentralAuditService de décider fail-soft / fail-closed. */
    public static class AuditChainException extends RuntimeException {
        public AuditChainException(String message, Throwable cause) { super(message, cause); }
    }
}
