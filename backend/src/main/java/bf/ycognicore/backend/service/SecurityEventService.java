package bf.ycognicore.backend.service;

import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
import bf.ycognicore.backend.multitenant.TenantContext;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.util.UUID;

/**
 * Ecriture dans evenements_securite (V17).
 * Chaque evenement peut etre associe a un utilisateur, une session, un appareil.
 * Ref. : T3.11, D-06, ADR-037.
 */
@Service
public class SecurityEventService {

    private static final Logger log = LoggerFactory.getLogger(SecurityEventService.class);

    private final MultiTenantConnectionProviderImpl connectionProvider;
    private final ObjectMapper objectMapper;

    public SecurityEventService(MultiTenantConnectionProviderImpl connectionProvider,
                                ObjectMapper objectMapper) {
        this.connectionProvider = connectionProvider;
        this.objectMapper = objectMapper;
    }

    /**
     * Enregistre un evenement de securite.
     * @param type     code de la regle (ex. R_N2_NOUVEL_APPAREIL)
     * @param gravite  INFO | WARN | ERROR | CRITIQUE
     * @param userId   utilisateur concerne (nullable)
     * @param sessionId session concernee (nullable)
     * @param appareilId appareil concerne (nullable)
     * @param ip       adresse IP (nullable)
     * @param pays     code pays ISO 2 lettres (nullable)
     * @param ville    ville (nullable)
     * @param details  details libres JSON
     */
    public void enregistrer(String type, String gravite, UUID userId,
                            UUID sessionId, UUID appareilId,
                            String ip, String pays, String ville,
                            JsonNode details) {
        String tenantCode = TenantContext.getTenantId();
        if (tenantCode == null) {
            log.debug("Evenement securite ignore (pas de TenantContext) : {}", type);
            return;
        }

        String sql = """
            INSERT INTO evenements_securite
              (type, gravite, user_id, session_id, appareil_id,
               ip, pays, ville, details)
            VALUES (?, ?, ?, ?, ?, ?::inet, ?, ?, ?::jsonb)
            """;

        try (Connection conn = connectionProvider.getConnection(tenantCode);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, type);
            ps.setString(2, gravite);
            ps.setObject(3, userId);
            ps.setObject(4, sessionId);
            ps.setObject(5, appareilId);
            ps.setString(6, ip);
            ps.setString(7, pays);
            ps.setString(8, ville);
            ps.setString(9, details != null ? details.toString() : "{}");
            ps.executeUpdate();
            log.info("Evenement securite : type={} gravite={} user={} tenant={}",
                type, gravite, userId, tenantCode);
        } catch (Exception e) {
            log.error("Ecriture evenement securite echouee ({}) : {}", type, e.getMessage());
        }
    }

    /** Raccourci sans details. */
    public void enregistrer(String type, String gravite, UUID userId) {
        enregistrer(type, gravite, userId, null, null, null, null, null, null);
    }

    /** Helper pour construire un details JSON. */
    public JsonNode details(Object... keyValues) {
        var node = objectMapper.createObjectNode();
        for (int i = 0; i + 1 < keyValues.length; i += 2) {
            String k = String.valueOf(keyValues[i]);
            Object v = keyValues[i + 1];
            if (v == null) node.putNull(k);
            else node.put(k, String.valueOf(v));
        }
        return node;
    }
}
