package bf.ycognicore.backend.tenant;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@Testcontainers
class TenantIsolationIT {

    static final String TENANT_A_DB = "ycc_tenant_a";
    static final String TENANT_B_DB = "ycc_tenant_b";

    @Container
    static PostgreSQLContainer<?> pg = new PostgreSQLContainer<>("postgres:16")
            .withDatabaseName(TENANT_A_DB)
            .withUsername("postgres")
            .withPassword("postgres");

    @BeforeAll
    static void createTenantB() throws Exception {
        try (Connection conn = DriverManager.getConnection(
                pg.getJdbcUrl(), pg.getUsername(), pg.getPassword());
             Statement stmt = conn.createStatement()) {
            stmt.execute("CREATE DATABASE " + TENANT_B_DB);
        }
    }

    private Connection openConnection(String dbName) throws Exception {
        String url = "jdbc:postgresql://" + pg.getHost() + ":" + pg.getMappedPort(5432) + "/" + dbName;
        return DriverManager.getConnection(url, pg.getUsername(), pg.getPassword());
    }

    @Test
    void utilisateur_du_tenant_A_n_est_pas_visible_dans_le_tenant_B() throws Exception {
        UUID userAId = UUID.randomUUID();

        try (Connection connA = openConnection(TENANT_A_DB);
             Statement stmt = connA.createStatement()) {
            stmt.execute("CREATE TABLE IF NOT EXISTS users (id UUID PRIMARY KEY, email VARCHAR(255))");
        }
        try (Connection connB = openConnection(TENANT_B_DB);
             Statement stmt = connB.createStatement()) {
            stmt.execute("CREATE TABLE IF NOT EXISTS users (id UUID PRIMARY KEY, email VARCHAR(255))");
        }

        try (Connection connA = openConnection(TENANT_A_DB);
             var ps = connA.prepareStatement("INSERT INTO users (id, email) VALUES (?, ?)")) {
            ps.setObject(1, userAId);
            ps.setString(2, "user.a@tenant-a.example");
            ps.executeUpdate();
        }

        try (Connection connB = openConnection(TENANT_B_DB);
             Statement stmt = connB.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM users")) {
            rs.next();
            assertThat(rs.getInt(1))
                    .as("Le tenant B ne doit contenir aucun utilisateur du tenant A")
                    .isEqualTo(0);
        }

        try (Connection connA = openConnection(TENANT_A_DB);
             Statement stmt = connA.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM users WHERE id = '" + userAId + "'")) {
            rs.next();
            assertThat(rs.getInt(1))
                    .as("Le tenant A doit contenir son propre utilisateur")
                    .isEqualTo(1);
        }
    }

    @Test
    void creation_table_isolee_par_base() throws Exception {
        String tableName = "isolation_test_" + UUID.randomUUID().toString().replace("-", "");

        try (Connection connA = openConnection(TENANT_A_DB);
             Statement stmt = connA.createStatement()) {
            stmt.execute("CREATE TABLE " + tableName + " (id SERIAL PRIMARY KEY)");
        }

        try (Connection connB = openConnection(TENANT_B_DB);
             Statement stmt = connB.createStatement();
             ResultSet rs = stmt.executeQuery(
                     "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '" + tableName + "'")) {
            rs.next();
            assertThat(rs.getInt(1))
                    .as("La table créée dans tenant A ne doit pas exister dans tenant B")
                    .isEqualTo(0);
        }
    }
}
