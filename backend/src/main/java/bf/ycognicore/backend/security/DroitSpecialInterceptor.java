package bf.ycognicore.backend.security;

import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.service.DroitSpecialService;
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

/**
 * Verifie le droit special requis (D-11).
 * Refuse 403 si l'utilisateur ne possede pas le droit.
 * Ref. : D-11, P-06, exigence 3.3.
 */
@Component
public class DroitSpecialInterceptor implements HandlerInterceptor {

    private static final Logger log = LoggerFactory.getLogger(DroitSpecialInterceptor.class);

    private final DroitSpecialService droitSpecialService;

    public DroitSpecialInterceptor(DroitSpecialService droitSpecialService) {
        this.droitSpecialService = droitSpecialService;
    }

    @Override
    public boolean preHandle(HttpServletRequest request,
                             HttpServletResponse response,
                             Object handler) throws Exception {

        if (!(handler instanceof HandlerMethod method)) {
            return true;
        }

        RequireDroitSpecial req = method.getMethodAnnotation(RequireDroitSpecial.class);
        if (req == null) {
            req = method.getBeanType().getAnnotation(RequireDroitSpecial.class);
        }
        if (req == null) {
            return true;   // pas de droit requis
        }

        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED,
                "Authentification requise");
            return false;
        }

        UUID userId;
        try {
            userId = UUID.fromString(auth.getName());
        } catch (Exception e) {
            log.warn("Droit special : userId non-UUID {}", auth.getName());
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Identifiant invalide");
            return false;
        }

        boolean granted = droitSpecialService.hasDroitSpecial(userId, req.value());
        if (!granted) {
            log.warn("DROIT SPECIAL REFUSE : user={} droit={} tenant={}",
                userId, req.value(), TenantContext.getTenantId());
            response.sendError(HttpServletResponse.SC_FORBIDDEN,
                "Droit special manquant : " + req.value());
            return false;
        }

        log.info("DROIT SPECIAL ACCORDE : user={} droit={} tenant={}",
            userId, req.value(), TenantContext.getTenantId());
        return true;
    }
}
