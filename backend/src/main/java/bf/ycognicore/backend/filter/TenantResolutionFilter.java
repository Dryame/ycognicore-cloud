package bf.ycognicore.backend.filter;

import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.security.JwtAuthenticationFilter;
import bf.ycognicore.backend.service.YccMetricsService;
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

@Component
@Order(1)
public class TenantResolutionFilter extends OncePerRequestFilter {

    private static final Logger logger = LoggerFactory.getLogger(TenantResolutionFilter.class);

    public static final String HEADER_TENANT = "X-Tenant-Code";

    private final YccMetricsService metrics;

    public TenantResolutionFilter(YccMetricsService metrics) {
        this.metrics = metrics;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        String tenantCode = (String) request.getAttribute(JwtAuthenticationFilter.ATTR_TENANT_CODE);
        String source = "JWT";

        if (tenantCode == null || tenantCode.isBlank()) {
            tenantCode = request.getHeader(HEADER_TENANT);
            source = "HEADER";
        }

        try {
            if (tenantCode != null && !tenantCode.isBlank()) {
                TenantContext.setTenantId(tenantCode.trim().toUpperCase());
                metrics.incrementTenantRouting();
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
