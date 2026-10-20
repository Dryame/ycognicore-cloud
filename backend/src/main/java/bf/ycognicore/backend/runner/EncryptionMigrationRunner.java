package bf.ycognicore.backend.runner;

import bf.ycognicore.backend.service.EncryptionMigrationService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.util.UUID;

@Component
@Profile("migration")
public class EncryptionMigrationRunner implements CommandLineRunner {
    private static final Logger log = LoggerFactory.getLogger(EncryptionMigrationRunner.class);
    private final EncryptionMigrationService migrationService;

    public EncryptionMigrationRunner(EncryptionMigrationService migrationService) {
        this.migrationService = migrationService;
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
            log.info("--- Migration tenant {} ---", tenantId);
            totalTiers += migrationService.migrateTiers(tenantId);
            totalUsers += migrationService.migrateUsers(tenantId);
        }
        log.info("=== MIGRATION TERMINEE : {} tiers, {} users ===", totalTiers, totalUsers);
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
