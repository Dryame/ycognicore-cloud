package bf.ycognicore.backend.security;

import bf.ycognicore.backend.service.JwtService;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/**
 * Filtre JWT : valide le token Bearer et remplit le SecurityContext.
 * Le tenantId est expose via un attribut de requete pour que
 * TenantResolutionFilter le recupere.
 *
 * Ref. : NFR-SEC-11, BL-011
 */
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    public static final String ATTR_TENANT_CODE = "jwt.tenantCode";
    private static final Logger logger = LoggerFactory.getLogger(JwtAuthenticationFilter.class);
    private static final String BEARER_PREFIX = "Bearer ";

    private final JwtService jwtService;

    public JwtAuthenticationFilter(JwtService jwtService) {
        this.jwtService = jwtService;
    }

    @Override
    @SuppressWarnings("unchecked")
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith(BEARER_PREFIX)) {
            String token = header.substring(BEARER_PREFIX.length()).trim();
            try {
                Claims claims = jwtService.parseToken(token);
                String userId = claims.getSubject();
                String tenantCode = claims.get("tenantCode", String.class);
                List<String> roles = claims.get("roles", List.class);

                List<SimpleGrantedAuthority> authorities = roles == null
                        ? List.of()
                        : roles.stream().map(SimpleGrantedAuthority::new).toList();

                UsernamePasswordAuthenticationToken auth =
                        new UsernamePasswordAuthenticationToken(userId, null, authorities);
                SecurityContextHolder.getContext().setAuthentication(auth);

                if (tenantCode != null && !tenantCode.isBlank()) {
                    request.setAttribute(ATTR_TENANT_CODE, tenantCode);
                }

                logger.debug("JWT valide pour user={} tenant={}", userId, tenantCode);
            } catch (Exception e) {
                logger.debug("JWT invalide : {}", e.getMessage());
                SecurityContextHolder.clearContext();
            }
        }

        filterChain.doFilter(request, response);
    }
}
