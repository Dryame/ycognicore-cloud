package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.controlplane.PartitionMaintenanceLog;
import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
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

@Service
@Transactional("controlPlaneTransactionManager")
public class PartitionMaintenanceService {

    private static final Logger logger = LoggerFactory.getLogger(PartitionMaintenanceService.class);
    private static final DateTimeFormatter FORMAT_PARTITION = DateTimeFormatter.ofPattern("yyyy_MM");

    private final DataSource controlPlaneDataSource;
    private final PartitionMaintenanceLogRepository logRepository;
    private final MultiTenantConnectionProviderImpl connectionProvider;

    @Value("${ycc.partition.months-ahead:3}")
    private int monthsAhead;

    public PartitionMaintenanceService(
            @Qualifier("controlPlaneDataSource") DataSource controlPlaneDataSource,
            PartitionMaintenanceLogRepository logRepository,
            MultiTenantConnectionProviderImpl connectionProvider) {
        this.controlPlaneDataSource = controlPlaneDataSource;
        this.logRepository = logRepository;
        this.connectionProvider = connectionProvider;
    }

    public PartitionMaintenanceResult runMaintenance(String executePar) {
        logger.info("=== Debut maintenance partitions (executePar={}, monthsAhead={}) ===",
                executePar, monthsAhead);

        List<TenantInfo> tenants = chargerTenants();
        logger.info(" -> {} tenants actifs", tenants.size());

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
        logger.info("=== Maintenance terminee : {} partitions, {} erreurs ===",
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

            try (Connection conn = connectionProvider.getConnection(tenant.code);
                 Statement stmt = conn.createStatement()) {
                stmt.execute(sql);
                logger.debug("  {} . {}", tenant.dbName, nomPartition);
            }
        } catch (SQLException e) {
            logger.error("Echec creation partition {} sur {} : {}",
                    nomPartition, tenant.dbName, e.getMessage());
            log.setStatut("ECHEC");
            log.setErreur(e.getMessage());
        }

        return log;
    }

    private List<TenantInfo> chargerTenants() {
        List<TenantInfo> tenants = new ArrayList<>();
        String sql = """
                SELECT t.id, t.code, td.db_name
                  FROM tenants t
                  JOIN tenant_databases td ON td.tenant_id = t.id
                 WHERE t.statut IN ('TRIAL','ACTIF')
                   AND td.db_status = 'PROVISIONNEE'
                """;

        try (Connection conn = controlPlaneDataSource.getConnection();
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(sql)) {

            while (rs.next()) {
                TenantInfo info = new TenantInfo();
                info.id = rs.getObject("id", UUID.class);
                info.code = rs.getString("code");
                info.dbName = rs.getString("db_name");
                tenants.add(info);
            }
        } catch (SQLException e) {
            logger.error("Erreur chargement tenants : {}", e.getMessage());
        }

        return tenants;
    }

    private static class TenantInfo {
        UUID id;
        String code;
        String dbName;
    }

    public record PartitionMaintenanceResult(
            int nbTenants, int nbPartitionsCrees, int nbErreurs, String executePar) {}
}
