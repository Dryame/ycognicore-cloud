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

@Service
public class RbacService {

    private static final Logger logger = LoggerFactory.getLogger(RbacService.class);

    private static final String SQL_CHECK = """
            SELECT COUNT(*) FROM user_roles ur
              JOIN role_permissions rp ON rp.role_id = ur.role_id
              JOIN modules m ON m.id = rp.module_id
              JOIN permissions p ON p.id = rp.permission_id
             WHERE ur.user_id = ?
               AND ur.statut = 'ACTIF'
               AND m.code = ?
               AND p.code = ?
            """;

    private final MultiTenantConnectionProviderImpl connectionProvider;

    public RbacService(MultiTenantConnectionProviderImpl connectionProvider) {
        this.connectionProvider = connectionProvider;
    }

    public boolean hasPermission(UUID userId, String moduleCode, String permissionCode) {
        String tenant = TenantContext.getTenantId();
        if (tenant == null) {
            logger.warn("hasPermission sans TenantContext (userId={})", userId);
            return false;
        }

        try (Connection conn = connectionProvider.getConnection(tenant);
             PreparedStatement ps = conn.prepareStatement(SQL_CHECK)) {

            ps.setObject(1, userId);
            ps.setString(2, moduleCode);
            ps.setString(3, permissionCode);

            try (ResultSet rs = ps.executeQuery()) {
                boolean ok = rs.next() && rs.getInt(1) > 0;
                logger.debug("hasPermission user={} module={} perm={} tenant={} -> {}",
                        userId, moduleCode, permissionCode, tenant, ok);
                return ok;
            }
        } catch (Exception e) {
            logger.error("Erreur hasPermission : {}", e.getMessage());
            return false;
        }
    }
}
