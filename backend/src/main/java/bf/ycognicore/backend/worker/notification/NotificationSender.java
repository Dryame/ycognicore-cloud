package bf.ycognicore.backend.worker.notification;

/**
 * Interface pour les senders de notifications par canal.
 * Ref. : BL-018, NFR-UX-07
 */
public interface NotificationSender {

    /**
     * Canal supporte : EMAIL, SMS, WHATSAPP, TELEGRAM, PUSH, FACEBOOK.
     */
    String supportedChannel();

    /**
     * Envoie la notification. Peut lever une exception pour declencher un retry.
     */
    void send(String destinataire, String sujet, String contenu) throws Exception;
}
