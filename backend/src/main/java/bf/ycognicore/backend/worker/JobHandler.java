package bf.ycognicore.backend.worker;

import com.fasterxml.jackson.databind.JsonNode;

/**
 * Interface pour les handlers de jobs asynchrones.
 * Chaque type de job (CREATION_PARTITION_AUDIT, ENVOI_NOTIFICATION, etc.)
 * a son propre handler.
 *
 * Ref. : BL-019, NFR-OPS-04
 */
public interface JobHandler {

    /**
     * Type de job supporte (ex. "CREATION_PARTITION_AUDIT").
     */
    String supportedType();

    /**
     * Execute le job. Peut lever une exception pour declencher un retry.
     */
    void handle(JsonNode payload) throws Exception;
}
