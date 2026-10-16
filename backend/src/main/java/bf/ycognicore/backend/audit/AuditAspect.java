package bf.ycognicore.backend.audit;

import bf.ycognicore.backend.multitenant.TenantContext;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import jakarta.servlet.http.HttpServletRequest;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.reflect.MethodSignature;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.time.OffsetDateTime;
import java.util.UUID;

@Aspect
@Component
public class AuditAspect {

    private static final Logger logger = LoggerFactory.getLogger(AuditAspect.class);

    private final CentralAuditService centralAuditService;
    private final ObjectMapper objectMapper;

    public AuditAspect(CentralAuditService centralAuditService, ObjectMapper objectMapper) {
        this.centralAuditService = centralAuditService;
        this.objectMapper = objectMapper;
    }

    @Around("@annotation(auditable)")
    public Object around(ProceedingJoinPoint pjp, Auditable auditable) throws Throwable {
        long start = System.currentTimeMillis();
        boolean succes = true;
        String erreur = null;
        try {
            return pjp.proceed();
        } catch (Throwable t) {
            succes = false;
            erreur = t.getClass().getSimpleName() + " : " + t.getMessage();
            throw t;
        } finally {
            try {
                AuditEvent event = buildEvent(pjp, auditable, succes, erreur,
                    System.currentTimeMillis() - start);
                OperationCritique critique = resolveCritique(auditable.action());
                centralAuditService.persist(event, critique);
            } catch (Exception e) {
                logger.warn("Audit non persisté : {}", e.getMessage());
            }
        }
    }

    /** Map action → OperationCritique (null si non critique). */
    private OperationCritique resolveCritique(String action) {
        if (action == null) return null;
        try {
            return OperationCritique.valueOf(action);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    private AuditEvent buildEvent(ProceedingJoinPoint pjp, Auditable auditable,
                                  boolean succes, String erreur, long dureeMs) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        UUID userId = null;
        if (auth != null && auth.getName() != null) {
            try { userId = UUID.fromString(auth.getName()); } catch (Exception ignored) {}
        }
        UUID entiteId = null;

        String ip = "0.0.0.0";
        String userAgent = "inconnu";
        var attrs = RequestContextHolder.getRequestAttributes();
        if (attrs instanceof ServletRequestAttributes sra) {
            HttpServletRequest req = sra.getRequest();
            ip = extractRealIp(req);
            userAgent = req.getHeader("User-Agent");
            if (userAgent != null && userAgent.length() > 250) {
                userAgent = userAgent.substring(0, 250);
            }
        }

        ObjectNode details = objectMapper.createObjectNode();
        details.put("dureeMs", dureeMs);
        if (erreur != null) details.put("erreur", erreur);
        MethodSignature sig = (MethodSignature) pjp.getSignature();
        details.put("methode", sig.toShortString());

        String tenantCode = TenantContext.getTenantId();

        return new AuditEvent(
            userId, tenantCode, auditable.action(), auditable.entite(),
            entiteId, auditable.module(), auditable.niveau(), succes,
            ip, userAgent, details, OffsetDateTime.now()
        );
    }

    /** Extrait l'IP reelle derriere un reverse proxy (T3.7). */
    private static String extractRealIp(HttpServletRequest req) {
        String xff = req.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) {
            return xff.split(",")[0].trim();
        }
        String xri = req.getHeader("X-Real-IP");
        if (xri != null && !xri.isBlank()) {
            return xri.trim();
        }
        return req.getRemoteAddr();
    }
}
