package bf.ycognicore.backend.runner;

import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.service.EncryptionMigrationService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.UUID;

/**
 * Runner de migration P4 — chiffre les champs sensibles existants.
 * Usage : --tenants=<uuid1>,<uuid2>
 * Ref. : P4 L3.3.
 */
@Component
@Profile("migration")
public class EncryptionMigrationRunner implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(EncryptionMigrationRunner.class);

    private final EncryptionMigrationService migrationService;
    private final DataSource controlPlaneDataSource;

    public EncryptionMigrationRunner(EncryptionMigrationService migrationService,
                                     @Qualifier("controlPlaneDataSource") DataSource controlPlaneDataSource) {
        this.migrationService = migrationService;
        this.controlPlaneDataSource = controlPlaneDataSource;
    }

    @Override
    public void run(String... args) throws Exception {
        log.info("=== DEMARRAGE MIGRATION CHIFFREMENT P4 ===");
        String[] tenantsArg = extractTenants(args);
        if (tenantsArg.length == 0) {
            log.warn("Aucun tenant specifie (--tenants=<uuid1>,<uuid2>). Arret.");
            return;
        }

        int totalTiers = 0;
        int totalUsers = 0;

        for (String s : tenantsArg) {
            UUID tenantId = UUID.fromString(s.trim());
            String tenantCode = fetchTenantCode(tenantId);
            if (tenantCode == null) {
                log.warn("Tenant {} introuvable dans control plane — skip", tenantId);
                continue;
            }

            log.info("--- Migration tenant {} (code={}) ---", tenantId, tenantCode);
            TenantContext.setTenantId(tenantCode);
            try {
                totalTiers += migrationService.migrateTiersInitial(tenantId);
                totalUsers += migrationService.migrateUsersInitial(tenantId);
            } finally {
                TenantContext.clear();
            }
        }

        log.info("=== MIGRATION TERMINEE : {} tiers, {} users ===", totalTiers, totalUsers);
    }

    private String fetchTenantCode(UUID tenantId) throws Exception {
        try (Connection conn = controlPlaneDataSource.getConnection();
             PreparedStatement ps = conn.prepareStatement(
                 "SELECT code FROM tenants WHERE id = ?")) {
            ps.setObject(1, tenantId);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getString("code");
            }
        }
        return null;
    }

    private static String[] extractTenants(String[] args) {
        for (String arg : args) {
            if (arg.startsWith("--tenants=")) {
                String v = arg.substring("--tenants=".length());
                return v.isBlank() ? new String[0] : v.split(",");
            }
        }
        return new String[0];
    }
}
