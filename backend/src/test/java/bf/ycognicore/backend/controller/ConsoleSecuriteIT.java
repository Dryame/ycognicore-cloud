package bf.ycognicore.backend.controller;

import bf.ycognicore.backend.security.RequireDroitSpecial;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.prepost.PreAuthorize;

import java.lang.reflect.Method;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests structurels ConsoleSecuriteController (annotations + endpoints).
 * Ref. : T3.13, D-11, ADR-038.
 */
class ConsoleSecuriteIT {

    @Test
    void controller_protege_par_droit_special() {
        RequireDroitSpecial ann = ConsoleSecuriteController.class
            .getAnnotation(RequireDroitSpecial.class);
        assertThat(ann).isNotNull();
        assertThat(ann.value()).isEqualTo("CONSOLE_SECURITE");
    }

    @Test
    void endpoints_session_exposes() {
        String[] noms = {"listSessions", "revokeSession"};
        for (String nom : noms) {
            boolean trouve = false;
            for (Method m : ConsoleSecuriteController.class.getDeclaredMethods()) {
                if (m.getName().equals(nom)) { trouve = true; break; }
            }
            assertThat(trouve).as("Methode " + nom).isTrue();
        }
    }

    @Test
    void endpoints_appareils_exposes() {
        String[] noms = {"listDevices", "blockDevice", "unblockDevice"};
        for (String nom : noms) {
            boolean trouve = false;
            for (Method m : ConsoleSecuriteController.class.getDeclaredMethods()) {
                if (m.getName().equals(nom)) { trouve = true; break; }
            }
            assertThat(trouve).as("Methode " + nom).isTrue();
        }
    }

    @Test
    void endpoints_evenements_exposes() {
        boolean trouve = false;
        for (Method m : ConsoleSecuriteController.class.getDeclaredMethods()) {
            if (m.getName().equals("listEvents")) { trouve = true; break; }
        }
        assertThat(trouve).isTrue();
    }

    @Test
    void platform_controller_protege_superadmin() {
        PreAuthorize ann = PlatformController.class.getAnnotation(PreAuthorize.class);
        assertThat(ann).isNotNull();
        assertThat(ann.value()).contains("SUPERADMIN");
    }
}
