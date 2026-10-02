package bf.ycognicore.backend.service;

import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
import bf.ycognicore.backend.multitenant.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class UserRoleLoader {

    private static final Logger logger = LoggerFactory.getLogger(UserRoleLoader.class);

    private static final String SQL_ROLES = """
            SELECT r.nom
              FROM user_roles ur
              JOIN roles r ON r.id = ur.role_id
             WHERE ur.user_id = ?
               AND ur.statut = 'ACTIF'
            """;

    public static final String ROLE_ADMIN_CLIENT = "Administrateur Client";

    private final MultiTenantConnectionProviderImpl connectionProvider;

    public UserRoleLoader(MultiTenantConnectionProviderImpl connectionProvider) {
        this.connectionProvider = connectionProvider;
    }

    public List<String> loadRoles(UUID userId) {
        String tenant = TenantContext.getTenantId();
        if (tenant == null) {
            return List.of();
        }

        List<String> roles = new ArrayList<>();
        try (Connection conn = connectionProvider.getConnection(tenant);
             PreparedStatement ps = conn.prepareStatement(SQL_ROLES)) {

            ps.setObject(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    roles.add(rs.getString("nom"));
                }
            }
            logger.debug("Roles charges user={} tenant={} -> {}", userId, tenant, roles);
        } catch (Exception e) {
            logger.error("Erreur chargement roles user={} : {}", userId, e.getMessage());
        }
        return roles;
    }

    public boolean isAdminClient(List<String> roles) {
        return roles.stream().anyMatch(ROLE_ADMIN_CLIENT::equalsIgnoreCase);
    }
}
