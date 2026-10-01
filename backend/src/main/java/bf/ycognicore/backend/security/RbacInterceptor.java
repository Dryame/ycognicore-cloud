package bf.ycognicore.backend.security;

import bf.ycognicore.backend.multitenant.TenantContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.UUID;

/**
 * Intercepteur RBAC : verifie @RequirePermission avant l'execution
 * d'une methode de controller.
 *
 * Ref. : NFR-SEC-12, NFR-SEC-13, BL-013
 */
@Component
public class RbacInterceptor implements HandlerInterceptor {

    private static final Logger logger = LoggerFactory.getLogger(RbacInterceptor.class);

    @Override
    public boolean preHandle(HttpServletRequest request,
                              HttpServletResponse response,
                              Object handler) throws Exception {

        if (!(handler instanceof HandlerMethod method)) {
            return true;   // static resources, error pages...
        }

        RequirePermission req = method.getMethodAnnotation(RequirePermission.class);
        if (req == null) {
            req = method.getBeanType().getAnnotation(RequirePermission.class);
        }
        if (req == null) {
            return true;   // pas de controle RBAC
        }

        // Recuperer userId du SecurityContext
        var auth = org.springframework.security.core.context.SecurityContextHolder
                .getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Authentification requise");
            return false;
        }

        // Pour BL-013, la vérification fine est déléguée.
        // On log la décision et on laisse passer (la vraie vérif viendra en BL-013.1).
        logger.info("RBAC check : user={} module={} perm={} tenant={}",
                auth.getName(), req.module(), req.permission(), TenantContext.getTenantId());
        return true;
    }
}
