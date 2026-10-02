package bf.ycognicore.backend.audit;

import com.fasterxml.jackson.databind.JsonNode;

import java.time.OffsetDateTime;
import java.util.UUID;

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
        JsonNode details,
        OffsetDateTime timestamp
) {}
