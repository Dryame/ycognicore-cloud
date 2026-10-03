package bf.ycognicore.backend.worker;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Scheduler du worker jobs_async.
 * Execution toutes les 10 secondes.
 *
 * Ref. : BL-019, NFR-OPS-04
 */
@Component
public class JobAsyncScheduler {

    private static final Logger logger = LoggerFactory.getLogger(JobAsyncScheduler.class);

    private final JobAsyncWorker worker;

    public JobAsyncScheduler(JobAsyncWorker worker) {
        this.worker = worker;
    }

    @Scheduled(fixedDelay = 10000)
    public void processJobs() {
        try {
            int processed = worker.processBatch();
            if (processed > 0) {
                logger.info("=== [WORKER] {} jobs traites ===", processed);
            }
        } catch (Exception e) {
            logger.error("Erreur worker jobs_async : {}", e.getMessage());
        }
    }
}
