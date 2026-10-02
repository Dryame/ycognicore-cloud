package bf.ycognicore.backend.config;

import bf.ycognicore.backend.security.RbacInterceptor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Enregistrement de l'intercepteur RBAC.
 * Ref. : NFR-SEC-12, BL-013
 */
@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    private final RbacInterceptor rbacInterceptor;

    public WebMvcConfig(RbacInterceptor rbacInterceptor) {
        this.rbacInterceptor = rbacInterceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(rbacInterceptor)
                .addPathPatterns("/api/rbac-test/**")
                .excludePathPatterns(
                        "/api/auth/**",
                        "/api/_poc/**",
                        "/api/admin/partitions/**",
                        "/error"
                );
    }
}
