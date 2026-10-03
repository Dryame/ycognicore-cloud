package bf.ycognicore.backend.worker.notification;

public interface NotificationSender {
    String supportedChannel();
    void send(String destinataire, String sujet, String contenu) throws Exception;
}
