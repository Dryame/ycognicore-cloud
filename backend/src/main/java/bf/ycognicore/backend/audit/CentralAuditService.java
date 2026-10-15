package bf.ycognicore.backend.audit;

import bf.ycognicore.backend.service.AuditService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;

/**
 * Point d'audit central — TOUTE écriture dans audit_log passe par ici.
 * Contrôlé par ArchUnit (AuditArchitectureTest).
 * Ref. : D-03, N-2, P3-6.
 */
@Service
public class CentralAuditService {

    private static final Logger log = LoggerFactory.getLogger(CentralAuditService.class);

    private final AuditService auditService;
    private final AuditChainService chainService;
    private final MultiTenantConnectionProviderImpl connectionProvider;

    public CentralAuditService(AuditService auditService,
                               AuditChainService chainService,
                               MultiTenantConnectionProviderImpl connectionProvider) {
        this.auditService = auditService;
        this.chainService = chainService;
        this.connectionProvider = connectionProvider;
    }

    /**
     * Persiste un événement avec chaînage.
     * @param critique opération critique ? Si null → fail-soft.
     */
    public void persist(AuditEvent event, OperationCritique critique) {
        boolean failClosed = critique != null && critique.isFailClosedStrict();
        try {
            // 1. INSERT (AuditService existant, inchangé)
            auditService.persist(event);

            // 2. Récupérer l'id généré
            Long id = fetchLastId(event);
            if (id == null) {
                throw new AuditChainService.AuditChainException(
                    "Impossible de récupérer l'id après INSERT", null);
            }

            // 3. Chaîner
            chainService.chainAndPersist(
                event.tenantCode(), id, event.userId(),
                event.action(), event.entite(), event.entiteId(),
                event.module(), event.niveau(), event.succes(),
                event.ip(), event.userAgent(), event.details(),
                event.timestamp());

        } catch (Exception e) {
            if (failClosed) {
                log.error("Audit fail-CLOSED : opération refusée — {}", e.getMessage());
                throw new AuditPersistenceException(
                    "Échec d'audit sur opération critique : " + critique, e);
            } else {
                log.warn("Audit fail-soft : perte d'entrée tolérée — {}", e.getMessage());
            }
        }
    }

    /** Wrapper fail-soft par défaut (compatibilité ascendante). */
    public void persist(AuditEvent event) {
        persist(event, null);
    }

    private Long fetchLastId(AuditEvent event) throws Exception {
        try (Connection conn = connectionProvider.getConnection(event.tenantCode());
             PreparedStatement ps = conn.prepareStatement(
                 "SELECT id FROM audit_log WHERE timestamp = ? AND action = ? " +
                 "ORDER BY id DESC LIMIT 1")) {
            ps.setObject(1, event.timestamp());
            ps.setString(2, event.action());
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) return rs.getLong(1);
            }
        }
        return null;
    }

    public static class AuditPersistenceException extends RuntimeException {
        public AuditPersistenceException(String m, Throwable c) { super(m, c); }
    }
}
