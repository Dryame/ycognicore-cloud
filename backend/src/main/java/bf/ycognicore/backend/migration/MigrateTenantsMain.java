package bf.ycognicore.backend.migration;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.output.MigrateResult;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

/**
 * Runner de migration tenant standalone (sans Spring Boot).
 *
 * Usage :
 *   java -cp target/classes:$(deps) bf.ycognicore.backend.migration.MigrateTenantsMain
 *
 * Variables d'environnement :
 *   CP_HOST, CP_PORT, CP_DB, CP_USER, CP_PASSWORD    (control plane)
 *   TENANT_PASSWORD                                   (password des bases tenant)
 *
 * Ref. : T0.9, T0.10, M30, D-01
 */
public class MigrateTenantsMain {

    private static final Logger log = LoggerFactory.getLogger(MigrateTenantsMain.class);

    static final String MIGRATION_LOCATION = "filesystem:/home/idrissa_yameogo/projets/ycognicore-cloud/db/migration/tenant";
    static final String BASELINE_VERSION = "13";

    public static void main(String[] args) throws Exception {
        String cpHost = env("CP_HOST", "localhost");
        int cpPort = Integer.parseInt(env("CP_PORT", "5432"));
        String cpDb = env("CP_DB", "ycc_control_plane");
        String cpUser = env("CP_USER", "postgres");
        String cpPassword = env("CP_PASSWORD", "postgres");
        String tenantPassword = env("TENANT_PASSWORD", "postgres");

        String cpUrl = "jdbc:postgresql://" + cpHost + ":" + cpPort + "/" + cpDb;
        log.info("Control plane : {}", cpUrl);

        List<TenantInfo> tenants = loadTenants(cpUrl, cpUser, cpPassword);
        log.info("Tenants trouvés : {}", tenants.size());

        MigrationReport report = new MigrationReport();

        for (TenantInfo t : tenants) {
            try {
                migrateTenant(t, cpHost, cpPort, tenantPassword);
                report.addSuccess(t.dbName);
            } catch (Exception e) {
                log.error("Échec tenant {}", t.dbName, e);
                report.addFailure(t.dbName, e.getMessage());
            }
        }

        log.info("=== Rapport : {} ===", report.summary());

        if (report.failureCount() > 0) {
            System.exit(1);
        }
    }

    private static List<TenantInfo> loadTenants(String url, String user, String password) throws Exception {
        List<TenantInfo> list = new ArrayList<>();
        try (Connection conn = DriverManager.getConnection(url, user, password);
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(
                     "SELECT db_name, db_host, db_port, db_user FROM tenant_databases ORDER BY db_name")) {
            while (rs.next()) {
                list.add(new TenantInfo(
                        rs.getString("db_name"),
                        rs.getString("db_host"),
                        rs.getInt("db_port"),
                        rs.getString("db_user")
                ));
            }
        }
        return list;
    }

    private static void migrateTenant(TenantInfo t, String defaultHost, int defaultPort, String password) {
        String host = t.host != null ? t.host : defaultHost;
        int port = t.port > 0 ? t.port : defaultPort;
        String url = "jdbc:postgresql://" + host + ":" + port + "/" + t.dbName;
        log.info("Tenant {} — {}", t.dbName, url);

        Flyway flyway = Flyway.configure()
                .dataSource(url, t.user, password)
                .locations(MIGRATION_LOCATION)
                .baselineOnMigrate(true)
                .baselineVersion(BASELINE_VERSION)
                .table("flyway_schema_history")
                .validateOnMigrate(true)
                .cleanDisabled(true)
                .load();

        MigrateResult result = flyway.migrate();
        log.info("Tenant {} — {} migration(s) appliquée(s), cible V{}",
                t.dbName, result.migrationsExecuted,
                result.targetSchemaVersion != null ? result.targetSchemaVersion : BASELINE_VERSION);
    }

    private static String env(String key, String defaultValue) {
        String v = System.getenv(key);
        return (v != null && !v.isBlank()) ? v : defaultValue;
    }

    record TenantInfo(String dbName, String host, int port, String user) {}
}
