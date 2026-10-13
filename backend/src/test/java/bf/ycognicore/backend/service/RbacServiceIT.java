package bf.ycognicore.backend.service;

import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
import bf.ycognicore.backend.multitenant.TenantContext;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests RBAC : vérification des permissions par utilisateur.
 *
 * Ref. : T1.2, M33, M41, exigences 2.1 et 2.7.
 * Stratégie : Testcontainers + implémentation anonyme du provider
 * (plus fiable qu'un mock : garantit une vraie connexion).
 */
@Testcontainers
class RbacServiceIT {

    static final String TENANT = "demo001";

    @Container
    static PostgreSQLContainer<?> pg = new PostgreSQLContainer<>("postgres:16")
            .withDatabaseName("ycc_tenant_rbac")
            .withUsername("postgres")
            .withPassword("postgres");

    RbacService rbacService;
    UUID adminUserId;
    UUID userUserId;

    @BeforeAll
    static void schemaSetup() throws Exception {
        try (Connection conn = DriverManager.getConnection(
                pg.getJdbcUrl(), pg.getUsername(), pg.getPassword());
             Statement stmt = conn.createStatement()) {

            stmt.execute("CREATE TABLE IF NOT EXISTS modules (id INTEGER PRIMARY KEY, code VARCHAR(50) NOT NULL)");
            stmt.execute("CREATE TABLE IF NOT EXISTS permissions (id INTEGER PRIMARY KEY, code VARCHAR(50) NOT NULL)");
            stmt.execute("CREATE TABLE IF NOT EXISTS roles (id INTEGER PRIMARY KEY, code VARCHAR(50) NOT NULL)");
            stmt.execute("CREATE TABLE IF NOT EXISTS user_roles (user_id UUID NOT NULL, role_id INTEGER NOT NULL, statut VARCHAR(20) NOT NULL)");
            stmt.execute("CREATE TABLE IF NOT EXISTS role_permissions (role_id INTEGER NOT NULL, module_id INTEGER NOT NULL, permission_id INTEGER NOT NULL)");

            stmt.execute("INSERT INTO modules (id, code) VALUES (1, 'VTE'), (2, 'ACH') ON CONFLICT DO NOTHING");
            stmt.execute("INSERT INTO permissions (id, code) VALUES (1, 'LIRE'), (2, 'CREER') ON CONFLICT DO NOTHING");
            stmt.execute("INSERT INTO roles (id, code) VALUES (1, 'ADMIN'), (2, 'LECTEUR') ON CONFLICT DO NOTHING");
            stmt.execute("INSERT INTO role_permissions (role_id, module_id, permission_id) VALUES (1, 1, 1), (1, 1, 2)");
            stmt.execute("INSERT INTO role_permissions (role_id, module_id, permission_id) VALUES (2, 1, 1)");
        }
    }

    @BeforeEach
    void setUp() throws Exception {
        TenantContext.setTenantId(TENANT);

        adminUserId = UUID.randomUUID();
        userUserId = UUID.randomUUID();

        try (Connection conn = DriverManager.getConnection(
                pg.getJdbcUrl(), pg.getUsername(), pg.getPassword());
             Statement stmt = conn.createStatement()) {
            stmt.execute("DELETE FROM user_roles");
            stmt.execute("INSERT INTO user_roles (user_id, role_id, statut) VALUES " +
                         "('" + adminUserId + "', 1, 'ACTIF'), " +
                         "('" + userUserId + "', 2, 'ACTIF')");
        }

        // Implémentation anonyme : garantit une vraie connexion, pas de mock
        MultiTenantConnectionProviderImpl provider = new MultiTenantConnectionProviderImpl(
                null, null, 5, 1, 10000L, 300000L, 900000L
        ) {
            @Override
            public Connection getConnection(String tenantIdentifier) throws SQLException {
                return DriverManager.getConnection(pg.getJdbcUrl(), pg.getUsername(), pg.getPassword());
            }

            @Override
            public Connection getAnyConnection() throws SQLException {
                return getConnection(null);
            }

            @Override
            public void releaseConnection(String tenantIdentifier, Connection connection) throws SQLException {
                connection.close();
            }

            @Override
            public void releaseAnyConnection(Connection connection) throws SQLException {
                connection.close();
            }
        };

        rbacService = new RbacService(provider);
    }

    @AfterEach
    void tearDown() throws Exception {
        try { TenantContext.clear(); } catch (Exception ignored) {}

        try (Connection conn = DriverManager.getConnection(
                pg.getJdbcUrl(), pg.getUsername(), pg.getPassword());
             Statement stmt = conn.createStatement()) {
            stmt.execute("DELETE FROM user_roles");
        }
    }

    @Test
    void admin_a_la_permission_CREER_sur_VTE() {
        assertThat(rbacService.hasPermission(adminUserId, "VTE", "CREER"))
                .as("L'admin doit avoir CREER sur VTE")
                .isTrue();
    }

    @Test
    void admin_a_la_permission_LIRE_sur_VTE() {
        assertThat(rbacService.hasPermission(adminUserId, "VTE", "LIRE")).isTrue();
    }

    @Test
    void lecteur_n_a_pas_la_permission_CREER_sur_VTE() {
        assertThat(rbacService.hasPermission(userUserId, "VTE", "CREER"))
                .as("Le lecteur ne doit PAS avoir CREER sur VTE")
                .isFalse();
    }

    @Test
    void lecteur_a_la_permission_LIRE_sur_VTE() {
        assertThat(rbacService.hasPermission(userUserId, "VTE", "LIRE")).isTrue();
    }

    @Test
    void refuse_une_permission_sur_un_module_inexistant() {
        assertThat(rbacService.hasPermission(adminUserId, "XXX", "LIRE")).isFalse();
    }

    @Test
    void refuse_un_utilisateur_inconnu() {
        UUID inconnu = UUID.randomUUID();
        assertThat(rbacService.hasPermission(inconnu, "VTE", "LIRE")).isFalse();
    }
}
