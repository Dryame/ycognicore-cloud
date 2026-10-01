package bf.ycognicore.backend.multitenant;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.hibernate.engine.jdbc.connections.spi.MultiTenantConnectionProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.SQLFeatureNotSupportedException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Fournit a Hibernate une connexion JDBC vers la base du tenant courant.
 * Implemente egalement DataSource pour pouvoir etre passe comme
 * dataSource() a l'EMF tenant.
 *
 * Ref. : ADR-006, ADR-011, NFR-SEC-29
 */
@Component
public class MultiTenantConnectionProviderImpl
        implements MultiTenantConnectionProvider<String>, DataSource {

    private static final Logger logger = LoggerFactory.getLogger(MultiTenantConnectionProviderImpl.class);

    private final TenantLookupService tenantLookupService;
    private final String dbUser;
    private final String dbPassword;
    private final int poolMaxSize;
    private final int poolMinIdle;
    private final long connectionTimeoutMs;
    private final long idleTimeoutMs;
    private final long maxLifetimeMs;

    private final Map<String, HikariDataSource> poolsByTenant = new ConcurrentHashMap<>();

    public MultiTenantConnectionProviderImpl(
            TenantLookupService tenantLookupService,
            @Value("${ycc.partition.db-password:postgres}") String dbPassword,
            @Value("${ycc.multitenant.tenant-pool.maximum-pool-size:5}") int poolMaxSize,
            @Value("${ycc.multitenant.tenant-pool.minimum-idle:1}") int poolMinIdle,
            @Value("${ycc.multitenant.tenant-pool.connection-timeout-ms:10000}") long connectionTimeoutMs,
            @Value("${ycc.multitenant.tenant-pool.idle-timeout-ms:300000}") long idleTimeoutMs,
            @Value("${ycc.multitenant.tenant-pool.max-lifetime-ms:900000}") long maxLifetimeMs
    ) {
        this.tenantLookupService = tenantLookupService;
        this.dbUser = "postgres";
        this.dbPassword = dbPassword;
        this.poolMaxSize = poolMaxSize;
        this.poolMinIdle = poolMinIdle;
        this.connectionTimeoutMs = connectionTimeoutMs;
        this.idleTimeoutMs = idleTimeoutMs;
        this.maxLifetimeMs = maxLifetimeMs;
    }

    private HikariDataSource poolFor(String tenantId) throws SQLException {
        HikariDataSource existing = poolsByTenant.get(tenantId);
        if (existing != null && !existing.isClosed()) {
            return existing;
        }
        return poolsByTenant.compute(tenantId, (k, old) -> {
            if (old != null && !old.isClosed()) {
                return old;
            }
            TenantLookupService.TenantDataSourceConfig cfg =
                    tenantLookupService.lookup(tenantId)
                            .orElseThrow(() -> new IllegalStateException(
                                    "Tenant inconnu ou non PROVISIONNEE : " + tenantId));
            logger.info("Creation pool HikariCP tenant={} url={}", tenantId, cfg.jdbcUrl());

            HikariConfig hc = new HikariConfig();
            hc.setJdbcUrl(cfg.jdbcUrl());
            hc.setUsername(dbUser);
            hc.setPassword(dbPassword);
            hc.setPoolName("tenant-" + tenantId);
            hc.setMaximumPoolSize(poolMaxSize);
            hc.setMinimumIdle(poolMinIdle);
            hc.setConnectionTimeout(connectionTimeoutMs);
            hc.setIdleTimeout(idleTimeoutMs);
            hc.setMaxLifetime(maxLifetimeMs);
            hc.setAutoCommit(true);
            return new HikariDataSource(hc);
        });
    }

    @Override
    public Connection getAnyConnection() throws SQLException {
        if (poolsByTenant.isEmpty()) {
            throw new SQLException(
                    "Aucun pool tenant initialise - getAnyConnection() appele hors contexte");
        }
        return poolsByTenant.values().iterator().next().getConnection();
    }

    @Override
    public void releaseAnyConnection(Connection connection) throws SQLException {
        connection.close();
    }

    @Override
    public Connection getConnection(String tenantIdentifier) throws SQLException {
        return poolFor(tenantIdentifier).getConnection();
    }

    @Override
    public void releaseConnection(String tenantIdentifier, Connection connection) throws SQLException {
        connection.close();
    }

    @Override
    public boolean supportsAggressiveRelease() {
        return false;
    }

    @Override
    public boolean isUnwrappableAs(Class<?> unwrapType) {
        return false;
    }

    @Override
    public <T> T unwrap(Class<T> unwrapType) {
        throw new UnsupportedOperationException("Not unwrappable: " + unwrapType);
    }

    @Override
    public Connection getConnection() throws SQLException {
        String tenant = TenantContext.getTenantId();
        return tenant != null ? getConnection(tenant) : getAnyConnection();
    }

    @Override
    public Connection getConnection(String username, String password) throws SQLException {
        return getConnection();
    }

    @Override
    public PrintWriter getLogWriter() {
        return null;
    }

    @Override
    public void setLogWriter(PrintWriter out) {
    }

    @Override
    public void setLoginTimeout(int seconds) {
    }

    @Override
    public int getLoginTimeout() {
        return 0;
    }

    @Override
    public java.util.logging.Logger getParentLogger() throws SQLFeatureNotSupportedException {
        throw new SQLFeatureNotSupportedException("Not supported");
    }

    @Override
    public boolean isWrapperFor(Class<?> iface) {
        return false;
    }

    @jakarta.annotation.PreDestroy
    public void shutdown() {
        logger.info("Fermeture des {} pools tenant", poolsByTenant.size());
        poolsByTenant.values().forEach(ds -> {
            try { ds.close(); } catch (Exception ignored) { }
        });
        poolsByTenant.clear();
    }
}
