package bf.ycognicore.backend.service;

import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

/**
 * Charge la politique de sessions (P-01) pour le tenant courant.
 * Fallback : SessionPolicy.DEFAUT si aucune ligne ENTREPRISE.
 * Ref. : P-01, T3.3.
 */
@Service
public class SessionPolicyService {

    private static final Logger log = LoggerFactory.getLogger(SessionPolicyService.class);

    private final MultiTenantConnectionProviderImpl connectionProvider;

    public SessionPolicyService(MultiTenantConnectionProviderImpl connectionProvider) {
        this.connectionProvider = connectionProvider;
    }

    public SessionPolicy forTenant(String tenantCode) {
        try (Connection conn = connectionProvider.getConnection(tenantCode);
             PreparedStatement ps = conn.prepareStatement(
                 "SELECT sessions_max, inactivite_minutes, duree_absolue_heures, " +
                 "       access_token_minutes, refresh_token_jours, verrouillage_seuil, " +
                 "       verrouillage_duree_minutes " +
                 "FROM politiques_session " +
                 "WHERE scope = 'ENTREPRISE' " +
                 "ORDER BY date_modification DESC LIMIT 1")) {
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return new SessionPolicy(
                        rs.getInt(1), rs.getInt(2), rs.getInt(3),
                        rs.getInt(4), rs.getInt(5), rs.getInt(6), rs.getInt(7)
                    ).clamp();
                }
            }
        } catch (Exception e) {
            log.warn("Lecture politiques_session échouée — fallback DEFAUT : {}", e.getMessage());
        }
        return SessionPolicy.DEFAUT;
    }
}
