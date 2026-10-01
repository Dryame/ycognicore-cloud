package bf.ycognicore.backend.multitenant;

/**
 * Contexte de tenant courant, lie au thread de la requete HTTP.
 *
 * <p>Positionne par TenantResolutionFilter, lu par TenantIdentifierResolver.</p>
 *
 * Ref. : ADR-006, NFR-SEC-01
 */
public final class TenantContext {

    private static final ThreadLocal<String> CURRENT_TENANT = new ThreadLocal<>();

    private TenantContext() {
        // utilitaire
    }

    public static String getTenantId() {
        return CURRENT_TENANT.get();
    }

    public static void setTenantId(String tenantId) {
        CURRENT_TENANT.set(tenantId);
    }

    public static void clear() {
        CURRENT_TENANT.remove();
    }

    public static boolean hasTenant() {
        return CURRENT_TENANT.get() != null;
    }
}
