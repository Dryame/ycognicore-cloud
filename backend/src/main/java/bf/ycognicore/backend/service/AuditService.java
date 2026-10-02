package bf.ycognicore.backend.service;

import bf.ycognicore.backend.audit.AuditEvent;
import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
import bf.ycognicore.backend.multitenant.TenantContext;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.Timestamp;

@Service
public class AuditService {

    private static final Logger logger = LoggerFactory.getLogger(AuditService.class);

    private static final String SQL_INSERT = """
            INSERT INTO audit_log
                (user_id, action, entite, entite_id, timestamp, ip, user_agent,
                 niveau, succes, details)
            VALUES (?, ?, ?, NULL, ?, ?::inet, ?, ?, ?, ?::jsonb)
            """;

    private final MultiTenantConnectionProviderImpl connectionProvider;
    private final ObjectMapper objectMapper;

    public AuditService(MultiTenantConnectionProviderImpl connectionProvider,
                        ObjectMapper objectMapper) {
        this.connectionProvider = connectionProvider;
        this.objectMapper = objectMapper;
    }

    public void persist(AuditEvent event) {
        String tenant = TenantContext.getTenantId();
        if (tenant == null) {
            logger.debug("Audit ignore (pas de TenantContext) : {}", event.action());
            return;
        }

        String detailsJson = null;
        try {
            if (event.details() != null) {
                detailsJson = objectMapper.writeValueAsString(event.details());
            }
        } catch (Exception e) {
            logger.warn("Serialisation details audit echouee : {}", e.getMessage());
        }

        try (Connection conn = connectionProvider.getConnection(tenant);
             PreparedStatement ps = conn.prepareStatement(SQL_INSERT)) {

            ps.setObject(1, event.userId());
            ps.setString(2, event.action());
            ps.setString(3, event.entite());
            ps.setTimestamp(4, Timestamp.from(event.timestamp().toInstant()));
            ps.setString(5, event.ip());
            ps.setString(6, event.userAgent());
            ps.setString(7, event.niveau());
            ps.setBoolean(8, event.succes());
            ps.setString(9, detailsJson);

            int rows = ps.executeUpdate();
            logger.debug("Audit persiste : {} rows pour action={}", rows, event.action());

        } catch (Exception e) {
            logger.error("Erreur persistance audit (best-effort) : {}", e.getMessage());
        }
    }
}
