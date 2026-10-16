package bf.ycognicore.backend.service;

import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
import bf.ycognicore.backend.multitenant.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.UUID;

/**
 * Verification des droits speciaux (D-11).
 * Un utilisateur a un droit special si l'un de ses roles le porte.
 * Ref. : D-11, P-06, V17.
 */
@Service
public class DroitSpecialService {

    private static final Logger log = LoggerFactory.getLogger(DroitSpecialService.class);

    private final MultiTenantConnectionProviderImpl connectionProvider;

    public DroitSpecialService(MultiTenantConnectionProviderImpl connectionProvider) {
        this.connectionProvider = connectionProvider;
    }

    /**
     * Verifie si l'utilisateur possede le droit special via l'un de ses roles.
     * @param userId        identifiant utilisateur
     * @param codeDroit     code du droit (ex. CONSOLE_SECURITE)
     * @return true si le droit est attribue
     */
    public boolean hasDroitSpecial(UUID userId, String codeDroit) {
        if (userId == null || codeDroit == null || codeDroit.isBlank()) return false;

        String tenantCode = TenantContext.getTenantId();
        if (tenantCode == null) {
            log.debug("Droit special ignore (pas de TenantContext) : user={} droit={}",
                userId, codeDroit);
            return false;
        }

        String sql = """
            SELECT 1
              FROM user_roles ur
              JOIN role_droits_speciaux rds ON rds.role_id = ur.role_id
              JOIN droits_speciaux ds       ON ds.id      = rds.droit_special_id
             WHERE ur.user_id = ?
               AND ds.code    = ?
             LIMIT 1
            """;

        try (Connection conn = connectionProvider.getConnection(tenantCode);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setObject(1, userId);
            ps.setString(2, codeDroit);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();
            }
        } catch (Exception e) {
            log.warn("Verification droit special echouee (user={} droit={}) : {}",
                userId, codeDroit, e.getMessage());
            return false;
        }
    }
}
