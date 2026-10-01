package bf.ycognicore.backend.multitenant;

import org.hibernate.context.spi.CurrentTenantIdentifierResolver;
import org.springframework.stereotype.Component;

/**
 * Resolveur d'identifiant tenant pour Hibernate.
 *
 * Ref. : ADR-006
 */
@Component
public class TenantIdentifierResolver implements CurrentTenantIdentifierResolver<String> {

    public static final String DEFAULT_TENANT = "PUBLIC";

    @Override
    public String resolveCurrentTenantIdentifier() {
        String tenant = TenantContext.getTenantId();
        return tenant != null ? tenant : DEFAULT_TENANT;
    }

    @Override
    public boolean validateExistingCurrentSessions() {
        return false;
    }
}
