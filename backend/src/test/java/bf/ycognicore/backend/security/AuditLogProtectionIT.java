package bf.ycognicore.backend.security;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Test de protection du registre d'audit contre TRUNCATE (V15) et RBAC strict (V16).
 *
 * Ref. : T1.3, M11, C3, C31, exigence 2.7.
 * Stratégie : applique le SQL de V15 et V16 directement sur le conteneur
 * (pas de Flyway — le schéma complet V1-V14 n'est pas requis ici).
 */
@Testcontainers
class AuditLogProtectionIT {

    @Container
    static PostgreSQLContainer<?> pg = new PostgreSQLContainer<>("postgres:16")
            .withDatabaseName("ycc_tenant_security")
            .withUsername("postgres")
            .withPassword("postgres");

    static DriverManagerDataSource ds;

    @BeforeAll
    static void setupSchemaAndApplyV15V16() throws Exception {
        ds = new DriverManagerDataSource();
        ds.setDriverClassName("org.postgresql.Driver");
        ds.setUrl(pg.getJdbcUrl());
        ds.setUsername(pg.getUsername());
        ds.setPassword(pg.getPassword());

        try (Connection conn = ds.getConnection();
             Statement stmt = conn.createStatement()) {

            // 1. Rôle applicatif
            stmt.execute("CREATE ROLE ycc_tenant_app LOGIN PASSWORD 'test'");

            // 2. Table audit_log (pour V15)
            stmt.execute("CREATE TABLE audit_log (id BIGSERIAL PRIMARY KEY, action TEXT)");

            // 3. Tables minimales pour V16 (les 7 tables C31)
            stmt.execute("CREATE TABLE users (id SERIAL PRIMARY KEY)");
            stmt.execute("CREATE TABLE roles (id SERIAL PRIMARY KEY)");
            stmt.execute("CREATE TABLE role_permissions (id SERIAL PRIMARY KEY)");
            stmt.execute("CREATE TABLE user_roles (id SERIAL PRIMARY KEY)");
            stmt.execute("CREATE TABLE sessions_history (id SERIAL PRIMARY KEY)");
            stmt.execute("CREATE TABLE numero_sequences (id SERIAL PRIMARY KEY)");
            stmt.execute("CREATE TABLE user_invitations (id SERIAL PRIMARY KEY)");

            // 4. GRANT initial (simule V1/V4/V5)
            stmt.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON users, roles, " +
                    "role_permissions, user_roles, sessions_history, numero_sequences, " +
                    "user_invitations TO ycc_tenant_app");

            // 5. V15 — fonction + trigger + REVOKE TRUNCATE
            stmt.execute("""
                CREATE OR REPLACE FUNCTION forbid_truncate()
                RETURNS TRIGGER AS $fn$
                BEGIN
                    RAISE EXCEPTION 'TRUNCATE interdit sur % (protection append-only)',
                        TG_TABLE_NAME
                        USING ERRCODE = '42501';
                END;
                $fn$ LANGUAGE plpgsql
            """);
            stmt.execute("DROP TRIGGER IF EXISTS trg_audit_log_no_truncate ON audit_log");
            stmt.execute("""
                CREATE TRIGGER trg_audit_log_no_truncate
                    BEFORE TRUNCATE ON audit_log
                    FOR EACH STATEMENT
                    EXECUTE FUNCTION forbid_truncate()
            """);
            stmt.execute("REVOKE TRUNCATE ON audit_log FROM ycc_tenant_app");

            // 6. V16 — REVOKE DELETE sur les 7 tables
            stmt.execute("REVOKE DELETE ON users            FROM ycc_tenant_app");
            stmt.execute("REVOKE DELETE ON roles            FROM ycc_tenant_app");
            stmt.execute("REVOKE DELETE ON role_permissions FROM ycc_tenant_app");
            stmt.execute("REVOKE DELETE ON user_roles       FROM ycc_tenant_app");
            stmt.execute("REVOKE DELETE ON sessions_history FROM ycc_tenant_app");
            stmt.execute("REVOKE DELETE ON numero_sequences FROM ycc_tenant_app");
            stmt.execute("REVOKE DELETE ON user_invitations FROM ycc_tenant_app");
        }
    }

    @Test
    void truncate_audit_log_est_bloque_par_trigger() {
        assertThatThrownBy(() -> {
            try (Connection conn = ds.getConnection();
                 Statement stmt = conn.createStatement()) {
                stmt.execute("TRUNCATE audit_log");
            }
        })
        .as("TRUNCATE doit être refusé par le trigger BEFORE TRUNCATE")
        .isInstanceOf(SQLException.class)
        .hasMessageContaining("TRUNCATE interdit");
    }

    @Test
    void role_applicatif_n_a_plus_delete_sur_les_7_tables() throws Exception {
        try (Connection conn = ds.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(
                     "SELECT COUNT(*) FROM information_schema.role_table_grants " +
                     "WHERE grantee = 'ycc_tenant_app' " +
                     "  AND privilege_type = 'DELETE' " +
                     "  AND table_name IN ('users', 'roles', 'role_permissions', " +
                     "                      'user_roles', 'sessions_history', " +
                     "                      'numero_sequences', 'user_invitations')")) {
            rs.next();
            assertThat(rs.getInt(1))
                    .as("Aucun GRANT DELETE ne doit subsister sur les 7 tables (C31)")
                    .isEqualTo(0);
        }
    }

    @Test
    void role_applicatif_n_a_plus_truncate_sur_audit_log() throws Exception {
        try (Connection conn = ds.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(
                     "SELECT COUNT(*) FROM information_schema.role_table_grants " +
                     "WHERE grantee = 'ycc_tenant_app' " +
                     "  AND privilege_type = 'TRUNCATE' " +
                     "  AND table_name = 'audit_log'")) {
            rs.next();
            assertThat(rs.getInt(1))
                    .as("Aucun GRANT TRUNCATE ne doit subsister sur audit_log")
                    .isEqualTo(0);
        }
    }
}
