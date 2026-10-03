package bf.ycognicore.backend.worker.notification;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class NotificationScheduler {

    private static final Logger logger = LoggerFactory.getLogger(NotificationScheduler.class);

    private final NotificationWorker worker;

    public NotificationScheduler(NotificationWorker worker) {
        this.worker = worker;
    }

    @Scheduled(fixedDelay = 5000)
    public void processNotifications() {
        try {
            int processed = worker.processBatch();
            if (processed > 0) {
                logger.info("=== [NOTIF WORKER] {} notifications traitees ===", processed);
            }
        } catch (Exception e) {
            logger.error("Erreur worker notifications : {}", e.getMessage());
        }
    }
}
