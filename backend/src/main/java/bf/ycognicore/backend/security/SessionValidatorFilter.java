package bf.ycognicore.backend.security;

import bf.ycognicore.backend.service.TokenService;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Set;
import java.util.UUID;

/**
 * Vérifie la validité de session via Redis à chaque requête (F5, D-04).
 * Fail-closed sur routes sensibles si Redis indisponible (R-a).
 * Ref. : D-04, D-13, F3, F5, R-a.
 */
@Component
public class SessionValidatorFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(SessionValidatorFilter.class);
    private static final String KEY_PREFIX = "ycc:session:";
    private static final String BEARER = "Bearer ";

    /** Routes sensibles : fail-closed si Redis KO. */
    private static final Set<String> SENSITIVE_PATHS = Set.of(
        "/api/auth/refresh",
        "/api/auth/logout",
        "/api/auth/change-password",
        "/api/mfa/setup",
        "/api/mfa/verify"
    );

    private final TokenService tokenService;
    private final StringRedisTemplate redis;

    public SessionValidatorFilter(TokenService tokenService, StringRedisTemplate redis) {
        this.tokenService = tokenService;
        this.redis = redis;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res,
                                    FilterChain chain) throws ServletException, IOException {
        String token = extractBearer(req);
        if (token == null) {
            chain.doFilter(req, res);
            return;
        }

        String jti;
        String tenantCode;
        try {
            Claims claims = tokenService.parseToken(token);
            jti = claims.getId();
            tenantCode = (String) claims.get("tenantCode");
        } catch (Exception e) {
            // JwtAuthenticationFilter gérera le refus
            chain.doFilter(req, res);
            return;
        }

        if (jti == null || tenantCode == null) {
            // token sans jti = issu de l'ancienne API — laisser passer (compat)
            chain.doFilter(req, res);
            return;
        }

        UUID sessionId = tokenService.extractSessionIdFromJtiOrId(jti);
        if (sessionId == null) {
            // jti simple (access token) → sessionId = jti
            try { sessionId = UUID.fromString(jti); } catch (Exception ignored) {}
        }

        String path = req.getRequestURI();
        boolean sensitive = SENSITIVE_PATHS.contains(path) || path.startsWith("/api/mfa/");

        if (sessionId == null) {
            reject(res, "Session invalide");
            return;
        }

        String redisKey = KEY_PREFIX + tenantCode + ":" + sessionId;
        try {
            Boolean exists = redis.hasKey(redisKey);
            if (exists == null || !exists) {
                reject(res, "Session expirée ou révoquée");
                return;
            }
        } catch (Exception e) {
            if (sensitive) {
                log.error("Redis KO + route sensible {} — fail-closed", path);
                reject(res, "Service indisponible");
                return;
            }
            log.warn("Redis KO sur {} — fail-open : {}", path, e.getMessage());
        }

        chain.doFilter(req, res);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        String p = req.getRequestURI();
        return p.startsWith("/api/auth/login")
            || p.equals("/api/auth/refresh")   // refresh gère sa propre logique
            || p.startsWith("/actuator")
            || p.startsWith("/error")
            || p.startsWith("/api/poc")
            || p.startsWith("/api/admin/partitions");
    }

    private static String extractBearer(HttpServletRequest req) {
        String h = req.getHeader("Authorization");
        if (h == null || !h.startsWith(BEARER)) return null;
        return h.substring(BEARER.length()).trim();
    }

    private static void reject(HttpServletResponse res, String message) throws IOException {
        res.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        res.setContentType("application/json");
        res.getWriter().write("{\"error\":\"" + message + "\"}");
    }
}
