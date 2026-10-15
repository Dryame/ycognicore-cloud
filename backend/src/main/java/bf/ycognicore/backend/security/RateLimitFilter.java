package bf.ycognicore.backend.security;

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
import java.time.Duration;
import java.util.Set;

/**
 * Limitation de debit (F7) : par compte + IP + route sensible.
 * Fenetre glissante : N requetes / T secondes sur cle Redis.
 * Fail-open si Redis KO sur routes non sensibles (R-a).
 * Ref. : F7, T3.6, D-05, P-01.
 */
@Component
public class RateLimitFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(RateLimitFilter.class);
    private static final String KEY_PREFIX = "ycc:rate:";

    /** Routes protegees + seuils (requetes / fenetre secondes). */
    private static final Set<String> SENSITIVE_PATHS = Set.of(
        "/api/auth/login", "/api/auth/refresh", "/api/auth/change-password",
        "/api/mfa/setup", "/api/mfa/verify", "/api/mfa/challenge-verify"
    );

    private final StringRedisTemplate redis;

    public RateLimitFilter(StringRedisTemplate redis) {
        this.redis = redis;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res,
                                    FilterChain chain) throws ServletException, IOException {
        String path = req.getRequestURI();
        boolean sensitive = SENSITIVE_PATHS.contains(path);
        if (!sensitive && !path.startsWith("/api/")) {
            chain.doFilter(req, res);
            return;
        }

        // Seuils par route sensible (P-01)
        int limit = sensitive ? 10 : 300;   // 10 / minute sensible ; 300 / minute general
        int window = 60;                     // secondes

        String ip = clientIp(req);
        String account = currentAccount();
        String key = KEY_PREFIX + req.getMethod() + ":" + path + ":" + ip + ":" + account;

        try {
            Long count = redis.opsForValue().increment(key);
            if (count != null && count == 1L) {
                redis.expire(key, Duration.ofSeconds(window));
            }
            if (count != null && count > limit) {
                log.warn("Rate limit depasse : {} {} ip={} count={}", req.getMethod(), path, ip, count);
                reject(res);
                return;
            }
        } catch (Exception e) {
            // Fail-open sur non-sensible, fail-closed sur sensible
            if (sensitive) {
                log.error("Redis KO sur route sensible {} — fail-closed", path);
                res.setStatus(503);
                res.setContentType("application/json");
                res.getWriter().write("{\"error\":\"Service indisponible\"}");
                return;
            }
            log.warn("Redis KO sur {} — fail-open : {}", path, e.getMessage());
        }

        chain.doFilter(req, res);
    }

    private static String clientIp(HttpServletRequest req) {
        String xff = req.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) {
            return xff.split(",")[0].trim();
        }
        return req.getRemoteAddr();
    }

    private static String currentAccount() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getName() == null) return "anonymous";
        return auth.getName();
    }

    private static void reject(HttpServletResponse res) throws IOException {
        res.setStatus(429);
        res.setContentType("application/json");
        res.setHeader("Retry-After", "60");
        res.getWriter().write("{\"error\":\"Trop de requetes\"}");
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        String p = req.getRequestURI();
        return p.startsWith("/actuator") || p.startsWith("/error");
    }
}
