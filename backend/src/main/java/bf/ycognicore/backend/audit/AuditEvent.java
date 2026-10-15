package bf.ycognicore.backend.audit;

import com.fasterxml.jackson.databind.JsonNode;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Événement d'audit — entrée unique du point d'audit central.
 * Ref. : D-03, ADR-030, V17 (hash_precedent, hash_entree)
 */
public record AuditEvent(
    UUID userId,
    String tenantCode,
    String action,
    String entite,
    UUID entiteId,
    String module,
    String niveau,
    boolean succes,
    String ip,
    String userAgent,
    JsonNode details,
    OffsetDateTime timestamp
) {}
