package bf.ycognicore.backend.audit;

import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.service.AuditService;
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

/**
 * Aspect AOP qui intercepte @Auditable et journalise dans audit_log.
 * Ref. : NFR-SEC-16, NFR-SEC-19, BL-014
 */
@Aspect
@Component
public class AuditAspect {

    private static final Logger logger = LoggerFactory.getLogger(AuditAspect.class);

    private final AuditService auditService;

    public AuditAspect(AuditService auditService) {
        this.auditService = auditService;
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
                auditService.persist(event);
            } catch (Exception e) {
                logger.warn("Audit non persiste : {}", e.getMessage());
            }
        }
    }

    private AuditEvent buildEvent(ProceedingJoinPoint pjp, Auditable a,
                                   boolean succes, String erreur, long dureeMs) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        UUID userId = null;
        if (auth != null && auth.getName() != null) {
            try { userId = UUID.fromString(auth.getName()); } catch (Exception ignored) {}
        }

        String ip = "0.0.0.0";
        String userAgent = "unknown";
        var attrs = RequestContextHolder.getRequestAttributes();
        if (attrs instanceof ServletRequestAttributes sra) {
            HttpServletRequest req = sra.getRequest();
            ip = req.getRemoteAddr();
            userAgent = req.getHeader("User-Agent");
            if (userAgent != null && userAgent.length() > 250) {
                userAgent = userAgent.substring(0, 250);
            }
        }

        String details = String.format(
                "{\"method\":\"%s\",\"dureeMs\":%d%s}",
                ((MethodSignature) pjp.getSignature()).getMethod().getName(),
                dureeMs,
                erreur != null ? ",\"erreur\":\"" + erreur.replace("\"", "'") + "\"" : ""
        );

        return new AuditEvent(
                userId,
                TenantContext.getTenantId(),
                a.action(),
                a.entite(),
                a.module(),
                a.niveau(),
                succes,
                ip,
                userAgent,
                details,
                OffsetDateTime.now()
        );
    }
}
