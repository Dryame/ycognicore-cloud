package bf.ycognicore.backend.security;

import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.service.RbacService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.UUID;

@Component
public class RbacInterceptor implements HandlerInterceptor {

    private static final Logger logger = LoggerFactory.getLogger(RbacInterceptor.class);

    private final RbacService rbacService;

    public RbacInterceptor(RbacService rbacService) {
        this.rbacService = rbacService;
    }

    @Override
    public boolean preHandle(HttpServletRequest request,
                              HttpServletResponse response,
                              Object handler) throws Exception {

        if (!(handler instanceof HandlerMethod method)) {
            return true;
        }

        RequirePermission req = method.getMethodAnnotation(RequirePermission.class);
        if (req == null) {
            req = method.getBeanType().getAnnotation(RequirePermission.class);
        }
        if (req == null) {
            return true;
        }

        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Authentification requise");
            return false;
        }

        UUID userId;
        try {
            userId = UUID.fromString(auth.getName());
        } catch (Exception e) {
            logger.warn("RBAC: userId non-UUID {}", auth.getName());
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Identifiant invalide");
            return false;
        }

        boolean granted = rbacService.hasPermission(userId, req.module(), req.permission());

        if (!granted) {
            logger.warn("RBAC REFUSE : user={} module={} perm={} tenant={}",
                    userId, req.module(), req.permission(), TenantContext.getTenantId());
            response.sendError(HttpServletResponse.SC_FORBIDDEN,
                    "Permission manquante : " + req.module() + "." + req.permission());
            return false;
        }

        logger.info("RBAC ACCORDE : user={} module={} perm={} tenant={}",
                userId, req.module(), req.permission(), TenantContext.getTenantId());
        return true;
    }
}
