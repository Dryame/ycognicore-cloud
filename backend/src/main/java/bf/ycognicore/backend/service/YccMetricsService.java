package bf.ycognicore.backend.service;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.stereotype.Service;

/**
 * Métriques métier custom yCogniCore Cloud.
 * Exposées via Prometheus : ycc_auth_login_total, ycc_rbac_denied_total, ycc_tenant_routing_total
 */
@Service
public class YccMetricsService {

    private final Counter authLoginSuccess;
    private final Counter authLoginFailure;
    private final Counter rbacDenied;
    private final Counter tenantRouting;

    public YccMetricsService(MeterRegistry registry) {
        this.authLoginSuccess = Counter.builder("ycc.auth.login")
                .description("Nombre de connexions réussies")
                .tag("result", "success")
                .register(registry);

        this.authLoginFailure = Counter.builder("ycc.auth.login")
                .description("Nombre de connexions échouées")
                .tag("result", "failure")
                .register(registry);

        this.rbacDenied = Counter.builder("ycc.rbac.denied")
                .description("Nombre de refus d'accès RBAC (HTTP 403)")
                .register(registry);

        this.tenantRouting = Counter.builder("ycc.tenant.routing")
                .description("Nombre de routages multi-tenant")
                .register(registry);
    }

    public void incrementAuthLoginSuccess() { authLoginSuccess.increment(); }
    public void incrementAuthLoginFailure() { authLoginFailure.increment(); }
    public void incrementRbacDenied()       { rbacDenied.increment(); }
    public void incrementTenantRouting()    { tenantRouting.increment(); }
}
