package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.controlplane.PartitionMaintenanceLog;
import bf.ycognicore.backend.repository.controlplane.PartitionMaintenanceLogRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.sql.DataSource;
import java.sql.*;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Service de maintenance des partitions mensuelles.
 *
 * Crée automatiquement les partitions pour audit_log et login_attempts
 * sur toutes les bases tenant actives.
 *
 * Réf. : BL-005, NFR-CONF-04, NFR-OPS-04
 */
@Service
@Transactional("controlPlaneTransactionManager")
public class PartitionMaintenanceService {

    private static final Logger logger = LoggerFactory.getLogger(PartitionMaintenanceService.class);
    private static final DateTimeFormatter FORMAT_PARTITION = DateTimeFormatter.ofPattern("yyyy_MM");

    @Qualifier("controlPlaneDataSource")
    private final DataSource controlPlaneDataSource;
    private final PartitionMaintenanceLogRepository logRepository;

    @Value("${ycc.partition.months-ahead:3}")
    private int monthsAhead;

    @Value("${ycc.partition.db-password:postgres}")
    private String dbPassword;

    @Value("${ycc.partition.db-host:localhost}")
    private String dbHost;

    public PartitionMaintenanceService(@Qualifier("controlPlaneDataSource") DataSource controlPlaneDataSource,
                                       PartitionMaintenanceLogRepository logRepository) {
        this.controlPlaneDataSource = controlPlaneDataSource;
        this.logRepository = logRepository;
    }

    public PartitionMaintenanceResult runMaintenance(String executePar) {
        logger.info("=== Début maintenance partitions (executePar={}, monthsAhead={}) ===",
                    executePar, monthsAhead);

        List<TenantInfo> tenants = chargerTenants();
        logger.info("  → {} tenants actifs", tenants.size());

        List<PartitionMaintenanceLog> logs = new ArrayList<>();
        int totalPartitions = 0;
        int totalErreurs = 0;

        for (TenantInfo tenant : tenants) {
            for (int i = 0; i < monthsAhead; i++) {
                LocalDate mois = LocalDate.now().withDayOfMonth(1).plusMonths(i);

                for (String table : new String[]{"audit_log", "login_attempts"}) {
                    PartitionMaintenanceLog log = creerPartition(tenant, table, mois, executePar);
                    logs.add(log);
                    if ("SUCCES".equals(log.getStatut())) totalPartitions++;
                    else totalErreurs++;
                }
            }
        }

        logRepository.saveAll(logs);

        logger.info("=== Maintenance terminée : {} partitions, {} erreurs ===",
                    totalPartitions, totalErreurs);

        return new PartitionMaintenanceResult(
            tenants.size(), totalPartitions, totalErreurs, executePar);
    }

    private PartitionMaintenanceLog creerPartition(TenantInfo tenant, String table,
                                                     LocalDate mois, String executePar) {
        String nomPartition = table + "_" + mois.format(FORMAT_PARTITION);
        LocalDate debut = mois;
        LocalDate fin = mois.plusMonths(1);

        PartitionMaintenanceLog log = new PartitionMaintenanceLog(
            tenant.id, tenant.dbName, table, nomPartition, mois, "SUCCES", executePar);

        try {
            String sql = String.format(
                "CREATE TABLE IF NOT EXISTS %s PARTITION OF %s FOR VALUES FROM ('%s') TO ('%s')",
                nomPartition, table, debut, fin);

            try (Connection conn = DriverManager.getConnection(
                    tenant.jdbcUrl, tenant.dbUser, tenant.dbPassword);
                 Statement stmt = conn.createStatement()) {
                stmt.execute(sql);
                logger.debug("  ✓ {}.{}", tenant.dbName, nomPartition);
            }
        } catch (SQLException e) {
            log.setStatut("ECHEC");
            log.setErreur(e.getMessage());
            logger.error("  ✗ {}.{} — {}", tenant.dbName, nomPartition, e.getMessage());
        }

        return log;
    }

    private List<TenantInfo> chargerTenants() {
        List<TenantInfo> tenants = new ArrayList<>();
        String sql = """
            SELECT t.id, td.db_name, td.db_host, td.db_port, td.db_user
            FROM tenants t
            JOIN tenant_databases td ON td.tenant_id = t.id
            WHERE t.statut IN ('TRIAL', 'ACTIF')
              AND td.db_status = 'PROVISIONNEE'
            """;

        try (Connection conn = controlPlaneDataSource.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {

            while (rs.next()) {
                TenantInfo info = new TenantInfo();
                info.id = rs.getObject("id", UUID.class);
                info.dbName = rs.getString("db_name");
                info.dbUser = rs.getString("db_user");
                info.dbPassword = dbPassword;
                info.jdbcUrl = String.format("jdbc:postgresql://%s:%d/%s",
                    dbHost, rs.getInt("db_port"), info.dbName);
                tenants.add(info);
            }
        } catch (SQLException e) {
            logger.error("Erreur chargement tenants : {}", e.getMessage());
        }

        return tenants;
    }

    private static class TenantInfo {
        UUID id;
        String dbName;
        String dbUser;
        String dbPassword;
        String jdbcUrl;
    }

    public record PartitionMaintenanceResult(
        int nbTenants, int nbPartitionsCreees, int nbErreurs, String executePar) {}
}
