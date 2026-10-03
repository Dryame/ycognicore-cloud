package bf.ycognicore.backend.worker;

import org.springframework.beans.factory.annotation.Qualifier;
import javax.sql.DataSource;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.sql.*;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Worker qui consomme la table jobs_async (control plane).
 * Traite les jobs par priorite avec retry exponentiel.
 *
 * Ref. : BL-019, NFR-OPS-04
 */
@Service
public class JobAsyncWorker {

    private static final Logger logger = LoggerFactory.getLogger(JobAsyncWorker.class);
    private static final int BATCH_SIZE = 10;

    private static final String SQL_SELECT = """
            SELECT id, type_job, tenant_id, payload, priorite, tentatives, max_tentatives
              FROM jobs_async
             WHERE statut = 'EN_ATTENTE'
               AND (next_retry_at IS NULL OR next_retry_at <= now())
             ORDER BY priorite ASC, date_creation ASC
             LIMIT ?
            """;

    private static final String SQL_UPDATE_EN_COURS = """
            UPDATE jobs_async
               SET statut = 'EN_COURS',
                   date_debut = now(),
                   tentatives = tentatives + 1
             WHERE id = ?
            """;

    private static final String SQL_UPDATE_TERMINE = """
            UPDATE jobs_async
               SET statut = 'TERMINE',
                   date_fin = now()
             WHERE id = ?
            """;

    private static final String SQL_UPDATE_ECHOUE = """
            UPDATE jobs_async
               SET statut = 'ECHOUE',
                   date_fin = now(),
                   erreur = ?
             WHERE id = ?
            """;

    private static final String SQL_UPDATE_RETRY = """
            UPDATE jobs_async
               SET statut = 'EN_ATTENTE',
                   next_retry_at = now() + (? * INTERVAL '1 second'),
                   erreur = ?
             WHERE id = ?
            """;

    private final DataSource controlPlaneDataSource;
    private final ObjectMapper objectMapper;
    private final Map<String, JobHandler> handlers = new HashMap<>();

    public JobAsyncWorker(@Qualifier("controlPlaneDataSource") DataSource controlPlaneDataSource,
                          ObjectMapper objectMapper,
                          List<JobHandler> handlerList) {
        this.controlPlaneDataSource = controlPlaneDataSource;
        this.objectMapper = objectMapper;
        for (JobHandler h : handlerList) {
            this.handlers.put(h.supportedType(), h);
            logger.info("Handler enregistre : {} -> {}",
                    h.supportedType(), h.getClass().getSimpleName());
        }
    }

    /**
     * Traite un batch de jobs en attente.
     * @return nombre de jobs traites (succes + echecs)
     */
    public int processBatch() {
        int processed = 0;
        try (Connection conn = controlPlaneDataSource.getConnection()) {

            List<Long> ids = new ArrayList<>();
            try (PreparedStatement ps = conn.prepareStatement(SQL_SELECT)) {
                ps.setInt(1, BATCH_SIZE);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        long id = rs.getLong("id");
                        String typeJob = rs.getString("type_job");
                        String payloadStr = rs.getString("payload");
                        int tentatives = rs.getInt("tentatives");
                        int maxTentatives = rs.getInt("max_tentatives");

                        if (executeJob(conn, id, typeJob, payloadStr, tentatives, maxTentatives)) {
                            processed++;
                        }
                    }
                }
            }
        } catch (Exception e) {
            logger.error("Erreur processBatch : {}", e.getMessage());
        }
        return processed;
    }

    private boolean executeJob(Connection conn, long id, String typeJob,
                                String payloadStr, int tentatives, int maxTentatives)
            throws SQLException {

        // 1. Passer en EN_COURS
        try (PreparedStatement ps = conn.prepareStatement(SQL_UPDATE_EN_COURS)) {
            ps.setLong(1, id);
            ps.executeUpdate();
        }

        // 2. Dispatcher vers le bon handler
        JobHandler handler = handlers.get(typeJob);
        if (handler == null) {
            logger.warn("Aucun handler pour type_job={}", typeJob);
            markEchoue(conn, id, "Handler introuvable : " + typeJob);
            return true;
        }

        try {
            JsonNode payload = objectMapper.readTree(payloadStr);
            handler.handle(payload);

            // 3. Succes
            try (PreparedStatement ps = conn.prepareStatement(SQL_UPDATE_TERMINE)) {
                ps.setLong(1, id);
                ps.executeUpdate();
            }
            logger.info("Job {} ({}) termine", id, typeJob);
            return true;

        } catch (Exception e) {
            logger.error("Echec job {} ({}) : {}", id, typeJob, e.getMessage());
            int currentTentative = tentatives + 1;

            if (currentTentative < maxTentatives) {
                // Retry : backoff = 2^tentative secondes
                long delaySeconds = (long) Math.pow(2, currentTentative);
                try (PreparedStatement ps = conn.prepareStatement(SQL_UPDATE_RETRY)) {
                    ps.setLong(1, delaySeconds);
                    ps.setString(2, "Tentative " + currentTentative + " : " + e.getMessage());
                    ps.setLong(3, id);
                    ps.executeUpdate();
                }
                logger.info("Job {} reprogramme dans {}s", id, delaySeconds);
            } else {
                markEchoue(conn, id, "Echec apres " + maxTentatives + " tentatives : " + e.getMessage());
            }
            return true;
        }
    }

    private void markEchoue(Connection conn, long id, String erreur) throws SQLException {
        try (PreparedStatement ps = conn.prepareStatement(SQL_UPDATE_ECHOUE)) {
            ps.setString(1, erreur.length() > 500 ? erreur.substring(0, 500) : erreur);
            ps.setLong(2, id);
            ps.executeUpdate();
        }
    }
}
