package bf.ycognicore.backend.audit;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Marque une methode dont l'execution doit etre journalisee dans audit_log.
 * Ref. : NFR-SEC-16, NFR-SEC-19, BL-014
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Auditable {

    String action();
    String module();
    String entite();
    String niveau() default "INFO";
}
