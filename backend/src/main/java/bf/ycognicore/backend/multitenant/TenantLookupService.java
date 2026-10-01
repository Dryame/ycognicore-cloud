package bf.ycognicore.backend.multitenant;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Resolution code tenant -> config base de donnees.
 * Lit tenant_databases du control plane.
 *
 * Ref. : ADR-006, ADR-011, NFR-SCAL-02
 */
@Service
public class TenantLookupService {

    private static final Logger logger = LoggerFactory.getLogger(TenantLookupService.class);

    private static final String SQL_FIND = """
            SELECT td.db_name, td.db_host, td.db_port, td.db_user, td.db_status,
                   t.code AS tenant_code
              FROM tenant_databases td
              JOIN tenants t ON t.id = td.tenant_id
             WHERE t.code = ?
               AND td.db_status = 'PROVISIONNEE'
            """;

    private final JdbcTemplate jdbcTemplate;
    private final long cacheTtlMs;
    private final Map<String, CachedEntry> cache = new ConcurrentHashMap<>();

    public TenantLookupService(
            @Qualifier("controlPlaneDataSource") javax.sql.DataSource controlPlaneDataSource,
            @Value("${ycc.multitenant.lookup-cache-ttl-seconds:300}") long cacheTtlSeconds
    ) {
        this.jdbcTemplate = new JdbcTemplate(controlPlaneDataSource);
        this.cacheTtlMs = cacheTtlSeconds * 1000L;
    }

    public Optional<TenantDataSourceConfig> lookup(String tenantCode) {
        if (tenantCode == null || tenantCode.isBlank()) {
            return Optional.empty();
        }

        CachedEntry cached = cache.get(tenantCode);
        if (cached != null && !cached.isExpired()) {
            return Optional.of(cached.config());
        }

        List<TenantDataSourceConfig> rows = jdbcTemplate.query(
                SQL_FIND,
                (rs, i) -> new TenantDataSourceConfig(
                        rs.getString("tenant_code"),
                        rs.getString("db_name"),
                        rs.getString("db_host"),
                        rs.getInt("db_port"),
                        rs.getString("db_user")
                ),
                tenantCode
        );

        if (rows.isEmpty()) {
            logger.debug("Aucune config trouvee pour tenantCode={}", tenantCode);
            cache.remove(tenantCode);
            return Optional.empty();
        }

        TenantDataSourceConfig config = rows.get(0);
        cache.put(tenantCode, new CachedEntry(config, System.currentTimeMillis() + cacheTtlMs));
        logger.debug("Config tenant resolue : code={} db={}", tenantCode, config.dbName());
        return Optional.of(config);
    }

    public void invalidate(String tenantCode) {
        cache.remove(tenantCode);
    }

    public void invalidateAll() {
        cache.clear();
    }

    public record TenantDataSourceConfig(
            String tenantCode,
            String dbName,
            String dbHost,
            int dbPort,
            String dbUser
    ) {
        public String jdbcUrl() {
            return "jdbc:postgresql://" + dbHost + ":" + dbPort + "/" + dbName;
        }
    }

    private record CachedEntry(TenantDataSourceConfig config, long expiresAt) {
        boolean isExpired() {
            return System.currentTimeMillis() > expiresAt;
        }
    }
}
