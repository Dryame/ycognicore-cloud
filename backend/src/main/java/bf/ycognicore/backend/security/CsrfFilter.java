package bf.ycognicore.backend.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.Set;

/**
 * Protection CSRF par double-submit cookie (D-13).
 * Mode observation (log.warn) tant que le frontend n'est pas migre.
 * Ref. : D-13, F8, T3.6.
 */
@Component
public class CsrfFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(CsrfFilter.class);
    private static final String COOKIE_NAME = "XSRF-TOKEN";
    private static final String HEADER_NAME = "X-XSRF-TOKEN";
    private static final SecureRandom RNG = new SecureRandom();
    private static final Set<String> MUTATING_METHODS = Set.of("POST", "PUT", "PATCH", "DELETE");

    @Value("${ycc.csrf.enforce:false}")
    private boolean enforce;

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res,
                                    FilterChain chain) throws ServletException, IOException {
        String cookieToken = readCookie(req, COOKIE_NAME);
        if (cookieToken == null) {
            cookieToken = randomToken();
            Cookie c = new Cookie(COOKIE_NAME, cookieToken);
            c.setHttpOnly(false);
            c.setSecure(true);
            c.setPath("/");
            c.setMaxAge(-1);
            res.addCookie(c);
        }

        if (MUTATING_METHODS.contains(req.getMethod())) {
            String headerToken = req.getHeader(HEADER_NAME);
            if (headerToken == null || !constantTimeEquals(cookieToken, headerToken)) {
                if (enforce) {
                    log.warn("CSRF refuse : {} {}", req.getMethod(), req.getRequestURI());
                    res.setStatus(403);
                    res.setContentType("application/json");
                    res.getWriter().write("{\"error\":\"CSRF invalide\"}");
                    return;
                } else {
                    log.info("CSRF observe : {} {} (non-bloquant)",
                        req.getMethod(), req.getRequestURI());
                }
            }
        }

        chain.doFilter(req, res);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        String p = req.getRequestURI();
        return p.equals("/api/auth/login")
            || p.startsWith("/actuator")
            || p.startsWith("/error");
    }

    private static String readCookie(HttpServletRequest req, String name) {
        Cookie[] cookies = req.getCookies();
        if (cookies == null) return null;
        for (Cookie c : cookies) {
            if (name.equals(c.getName())) return c.getValue();
        }
        return null;
    }

    private static boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null) return false;
        return MessageDigest.isEqual(
            a.getBytes(java.nio.charset.StandardCharsets.UTF_8),
            b.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    private static String randomToken() {
        byte[] b = new byte[32];
        RNG.nextBytes(b);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(b);
    }
}
