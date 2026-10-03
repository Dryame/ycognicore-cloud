package bf.ycognicore.backend.worker.notification;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Sender SMS (mock pour Sprint H2).
 * En H3+ : integration operateur (Orange Money, Moov, etc.) via passerelle.
 *
 * Ref. : BL-018
 */
@Component
public class SmsNotificationSender implements NotificationSender {

    private static final Logger logger = LoggerFactory.getLogger(SmsNotificationSender.class);

    @Override
    public String supportedChannel() {
        return "SMS";
    }

    @Override
    public void send(String destinataire, String sujet, String contenu) throws Exception {
        logger.info("[SMS MOCK] to={} body={}",
                destinataire,
                contenu.length() > 50 ? contenu.substring(0, 50) + "..." : contenu);
    }
}
