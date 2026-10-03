package bf.ycognicore.backend.worker.notification;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class EmailNotificationSender implements NotificationSender {

    private static final Logger logger = LoggerFactory.getLogger(EmailNotificationSender.class);

    @Override
    public String supportedChannel() {
        return "EMAIL";
    }

    @Override
    public void send(String destinataire, String sujet, String contenu) throws Exception {
        logger.info("[EMAIL MOCK] to={} subject={} body={}",
                destinataire,
                sujet != null ? sujet : "(sans sujet)",
                contenu.length() > 50 ? contenu.substring(0, 50) + "..." : contenu);
    }
}
