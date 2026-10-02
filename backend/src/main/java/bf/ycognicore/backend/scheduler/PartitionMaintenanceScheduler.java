package bf.ycognicore.backend.scheduler;

import bf.ycognicore.backend.service.PartitionMaintenanceService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class PartitionMaintenanceScheduler {

    private static final Logger logger = LoggerFactory.getLogger(PartitionMaintenanceScheduler.class);

    private final PartitionMaintenanceService service;

    public PartitionMaintenanceScheduler(PartitionMaintenanceService service) {
        this.service = service;
    }

    @Scheduled(cron = "${ycc.partition.cron:0 0 2 1 * *}")
    public void maintenanceMensuelle() {
        logger.info("=== [SCHEDULER] Maintenance mensuelle ===");
        try {
            var result = service.runMaintenance("SCHEDULER");
            logger.info("=== [SCHEDULER] Resultat : {} tenants, {} partitions, {} erreurs ===",
                    result.nbTenants(), result.nbPartitionsCrees(), result.nbErreurs());
        } catch (Exception e) {
            logger.error("=== [SCHEDULER] Echec ===", e);
        }
    }
}
