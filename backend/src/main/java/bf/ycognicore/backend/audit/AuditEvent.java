package bf.ycognicore.backend.audit;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Evenement d'audit.
 * Ref. : NFR-SEC-16, BL-014
 */
public record AuditEvent(
        UUID userId,
        String tenantCode,
        String action,
        String entite,
        String module,
        String niveau,
        boolean succes,
        String ip,
        String userAgent,
        String details,
        OffsetDateTime timestamp
) {}
