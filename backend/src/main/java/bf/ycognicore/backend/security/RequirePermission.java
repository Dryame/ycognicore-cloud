package bf.ycognicore.backend.security;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Annotation declarant la permission requise pour acceder a un endpoint.
 * Le controle est effectue par RbacInterceptor.
 *
 * Exemple :
 *   @RequirePermission(module = "VENTES", permission = "LIRE")
 *
 * Ref. : NFR-SEC-12, NFR-SEC-13, BL-013
 */
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface RequirePermission {

    /** Code du module (ex. VENTES, COMPTABILITE, STOCK). */
    String module();

    /** Code de la permission (ex. LIRE, CREER, MODIFIER, SUPPRIMER, VALIDER, EXPORTER). */
    String permission();
}
