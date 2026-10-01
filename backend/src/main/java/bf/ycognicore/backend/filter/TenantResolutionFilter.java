package bf.ycognicore.backend.filter;

import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.security.JwtAuthenticationFilter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Filtre d'extraction du tenant courant.
 * Priorite 1 = APRES Spring Security (JWT).
 * - Si le JWT a pose un attribut jwt.tenantCode, on l'utilise.
 * - Sinon, fallback sur le header X-Tenant-Code (POC/tests).
 *
 * Ref. : ADR-006, NFR-SEC-11, BL-011
 */
@Component
@Order(1)
public class TenantResolutionFilter extends OncePerRequestFilter {

    private static final Logger logger = LoggerFactory.getLogger(TenantResolutionFilter.class);

    public static final String HEADER_TENANT = "X-Tenant-Code";

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        // 1. Priorite au JWT
        String tenantCode = (String) request.getAttribute(JwtAuthenticationFilter.ATTR_TENANT_CODE);
        String source = "JWT";

        // 2. Fallback header (POC)
        if (tenantCode == null || tenantCode.isBlank()) {
            tenantCode = request.getHeader(HEADER_TENANT);
            source = "HEADER";
        }

        try {
            if (tenantCode != null && !tenantCode.isBlank()) {
                TenantContext.setTenantId(tenantCode.trim().toUpperCase());
                logger.debug("Tenant resolu (source={}) pour {} {} : {}",
                        source, request.getMethod(), request.getRequestURI(), tenantCode);
            }
            filterChain.doFilter(request, response);
        } finally {
            TenantContext.clear();
        }
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();
        return path.startsWith("/actuator") || path.startsWith("/favicon");
    }
}
