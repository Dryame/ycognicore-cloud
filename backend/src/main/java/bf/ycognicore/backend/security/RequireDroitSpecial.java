package bf.ycognicore.backend.security;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Annotation declarant un droit special requis pour acceder a un endpoint.
 * Distincte des 6 permissions fixes RBAC (D-11).
 * Controle effectue par DroitSpecialInterceptor.
 *
 * Exemple :
 *   @RequireDroitSpecial("CONSOLE_SECURITE")
 *
 * Ref. : D-11, P-06, catalogue 5.3, exigence 3.3.
 */
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface RequireDroitSpecial {

    /** Code du droit special (ex. CONSOLE_SECURITE). */
    String value();
}
