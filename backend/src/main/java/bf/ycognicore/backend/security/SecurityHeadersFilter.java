package bf.ycognicore.backend.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * En-tetes de securite HTTP (OWASP recommandations).
 * Ref. : T3.7, exigence 2.6.
 */
@Component
public class SecurityHeadersFilter extends OncePerRequestFilter {

    @Value("${ycc.security.hsts-max-age:31536000}")
    private long hstsMaxAge;

    @Value("${ycc.security.frame-options:DENY}")
    private String frameOptions;

    @Value("${ycc.security.referrer-policy:strict-origin-when-cross-origin}")
    private String referrerPolicy;

    @Value("${ycc.security.csp:default-src 'self'; frame-ancestors 'none'; object-src 'none'; base-uri 'self'}")
    private String contentSecurityPolicy;

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res,
                                    FilterChain chain) throws ServletException, IOException {
        // HSTS : force HTTPS (ignorer si deja en HTTP en dev)
        if (req.isSecure()) {
            res.setHeader("Strict-Transport-Security",
                "max-age=" + hstsMaxAge + "; includeSubDomains");
        }

        // Empêche le MIME sniffing
        res.setHeader("X-Content-Type-Options", "nosniff");

        // Anti-clickjacking
        res.setHeader("X-Frame-Options", frameOptions);

        // Referrer policy
        res.setHeader("Referrer-Policy", referrerPolicy);

        // CSP
        res.setHeader("Content-Security-Policy", contentSecurityPolicy);

        // Désactive les fonctionnalités navigateur non utilisées
        res.setHeader("Permissions-Policy",
            "geolocation=(), microphone=(), camera=(), payment=()");

        chain.doFilter(req, res);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        // Ne pas appliquer sur /actuator (Prometheus scrape)
        return req.getRequestURI().startsWith("/actuator");
    }
}
