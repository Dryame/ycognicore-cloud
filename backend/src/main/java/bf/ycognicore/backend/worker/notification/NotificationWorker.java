package bf.ycognicore.backend.worker.notification;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;

import javax.sql.DataSource;
import java.sql.*;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class NotificationWorker {

    private static final Logger logger = LoggerFactory.getLogger(NotificationWorker.class);
    private static final int BATCH_SIZE = 20;
    private static final short MAX_TENTATIVES = 3;

    private static final String SQL_SELECT = """
            SELECT id, destinataire, canal, sujet, contenu, tentatives
              FROM notifications_queue
             WHERE statut = 'EN_ATTENTE'
               AND (next_retry_at IS NULL OR next_retry_at <= now())
             ORDER BY date_creation ASC
             LIMIT ?
            """;

    private static final String SQL_ENVOYEE = """
            UPDATE notifications_queue
               SET statut = 'ENVOYEE',
                   date_envoi = now(),
                   tentatives = tentatives + 1
             WHERE id = ?
            """;

    private static final String SQL_ECHOUEE = """
            UPDATE notifications_queue
               SET statut = 'ECHOUEE',
                   tentatives = tentatives + 1,
                   erreur = ?
             WHERE id = ?
            """;

    private static final String SQL_RETRY = """
            UPDATE notifications_queue
               SET tentatives = tentatives + 1,
                   next_retry_at = now() + (? * INTERVAL '1 second'),
                   erreur = ?
             WHERE id = ?
            """;

    private final DataSource controlPlaneDataSource;
    private final Map<String, NotificationSender> senders = new HashMap<>();

    public NotificationWorker(
            @Qualifier("controlPlaneDataSource") DataSource controlPlaneDataSource,
            List<NotificationSender> senderList) {
        this.controlPlaneDataSource = controlPlaneDataSource;
        for (NotificationSender s : senderList) {
            this.senders.put(s.supportedChannel(), s);
            logger.info("Sender enregistre : {} -> {}",
                    s.supportedChannel(), s.getClass().getSimpleName());
        }
    }

    public int processBatch() {
        int processed = 0;
        try (Connection conn = controlPlaneDataSource.getConnection();
             PreparedStatement ps = conn.prepareStatement(SQL_SELECT)) {

            ps.setInt(1, BATCH_SIZE);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    long id = rs.getLong("id");
                    String destinataire = rs.getString("destinataire");
                    String canal = rs.getString("canal");
                    String sujet = rs.getString("sujet");
                    String contenu = rs.getString("contenu");
                    short tentatives = rs.getShort("tentatives");

                    executeNotification(conn, id, destinataire, canal, sujet, contenu, tentatives);
                    processed++;
                }
            }
        } catch (Exception e) {
            logger.error("Erreur processBatch notifications : {}", e.getMessage());
        }
        return processed;
    }

    private void executeNotification(Connection conn, long id, String destinataire,
                                     String canal, String sujet, String contenu,
                                     short tentatives) throws SQLException {

        NotificationSender sender = senders.get(canal);
        if (sender == null) {
            logger.warn("Aucun sender pour canal={}", canal);
            markEchouee(conn, id, "Sender introuvable : " + canal);
            return;
        }

        try {
            sender.send(destinataire, sujet, contenu);

            try (PreparedStatement ps = conn.prepareStatement(SQL_ENVOYEE)) {
                ps.setLong(1, id);
                ps.executeUpdate();
            }
            logger.info("Notification {} ({}) envoyee a {}", id, canal, destinataire);

        } catch (Exception e) {
            logger.error("Echec notification {} ({}) : {}", id, canal, e.getMessage());
            short currentTentative = (short) (tentatives + 1);

            if (currentTentative < MAX_TENTATIVES) {
                long delaySeconds = (long) Math.pow(2, currentTentative);
                try (PreparedStatement ps = conn.prepareStatement(SQL_RETRY)) {
                    ps.setLong(1, delaySeconds);
                    ps.setString(2, "Tentative " + currentTentative + " : " + e.getMessage());
                    ps.setLong(3, id);
                    ps.executeUpdate();
                }
                logger.info("Notification {} reprogrammee dans {}s", id, delaySeconds);
            } else {
                markEchouee(conn, id, "Echec apres " + MAX_TENTATIVES + " tentatives : " + e.getMessage());
            }
        }
    }

    private void markEchouee(Connection conn, long id, String erreur) throws SQLException {
        try (PreparedStatement ps = conn.prepareStatement(SQL_ECHOUEE)) {
            ps.setString(1, erreur.length() > 500 ? erreur.substring(0, 500) : erreur);
            ps.setLong(2, id);
            ps.executeUpdate();
        }
    }
}
