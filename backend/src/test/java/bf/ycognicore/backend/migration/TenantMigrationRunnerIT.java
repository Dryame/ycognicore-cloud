package bf.ycognicore.backend.migration;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;

import static org.assertj.core.api.Assertions.assertThat;

@Testcontainers
class TenantMigrationRunnerIT {

    @Container
    static PostgreSQLContainer<?> pg = new PostgreSQLContainer<>("postgres:16")
            .withDatabaseName("ycc_tenant_test")
            .withUsername("postgres")
            .withPassword("postgres");

    @Test
    void baseline_then_apply_migrations() throws Exception {
        DriverManagerDataSource ds = new DriverManagerDataSource();
        ds.setDriverClassName("org.postgresql.Driver");
        ds.setUrl(pg.getJdbcUrl());
        ds.setUsername(pg.getUsername());
        ds.setPassword(pg.getPassword());

        try (Connection conn = ds.getConnection();
             Statement stmt = conn.createStatement()) {
            stmt.execute("CREATE TABLE IF NOT EXISTS users (id SERIAL PRIMARY KEY)");
        }

        Flyway flyway = Flyway.configure()
                .dataSource(ds)
                .locations("filesystem:../db/migration/tenant")
                .baselineOnMigrate(true)
                .baselineVersion("13")
                .table("flyway_schema_history")
                .validateOnMigrate(true)
                .cleanDisabled(true)
                .load();

        var result = flyway.migrate();

        assertThat(result.migrationsExecuted).isGreaterThanOrEqualTo(1);
        assertThat(Integer.parseInt(result.targetSchemaVersion)).isGreaterThanOrEqualTo(14);

        try (Connection conn = ds.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(
                     "SELECT column_name FROM information_schema.columns " +
                     "WHERE table_name='users' AND column_name='mfa_secret_package'")) {
            assertThat(rs.next()).isTrue();
        }
    }
}
