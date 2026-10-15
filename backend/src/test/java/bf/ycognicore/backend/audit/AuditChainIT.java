package bf.ycognicore.backend.audit;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@Testcontainers
class AuditChainIT {

    @Container
    static PostgreSQLContainer<?> pg = new PostgreSQLContainer<>("postgres:16")
        .withDatabaseName("ycc_tenant_chain")
        .withUsername("postgres")
        .withPassword("postgres");

    static DriverManagerDataSource ds;

    @BeforeAll
    static void setup() throws Exception {
        ds = new DriverManagerDataSource();
        ds.setDriverClassName("org.postgresql.Driver");
        ds.setUrl(pg.getJdbcUrl());
        ds.setUsername(pg.getUsername());
        ds.setPassword(pg.getPassword());

        try (Connection conn = ds.getConnection();
             Statement stmt = conn.createStatement()) {
            stmt.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto");
        }
    }

    @Test
    void calcul_hash_identique_java_pg() throws Exception {
        UUID userId = UUID.randomUUID();
        UUID entiteId = UUID.randomUUID();
        OffsetDateTime ts = OffsetDateTime.of(2026, 10, 15, 12, 0, 0, 123456000, ZoneOffset.UTC);

        String canon = AuditChainService.canonicalize(
            null, 1L, userId, "TEST", "users", entiteId, ts,
            new ObjectMapper().readTree("{\"a\":1}"));

        String javaHash = AuditChainService.sha256Hex(canon);

        try (Connection conn = ds.getConnection();
             Statement stmt = conn.createStatement()) {
            stmt.execute("CREATE TEMP TABLE t_canon AS SELECT '" +
                canon.replace("'", "''") + "'::text AS c");
            try (ResultSet rs = stmt.executeQuery(
                    "SELECT encode(digest(c, 'sha256'), 'hex') FROM t_canon")) {
                rs.next();
                assertThat(rs.getString(1)).isEqualTo(javaHash);
            }
        }
    }
}
