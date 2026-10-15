package bf.ycognicore.backend.service;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests empreinte appareil (sans DB).
 * Ref. : F6, T3.5.
 */
class DeviceServiceIT {

    @Test
    void empreinte_stable() {
        String h1 = DeviceService.fingerprint("Firefox/125", "fr-FR");
        String h2 = DeviceService.fingerprint("Firefox/125", "fr-FR");
        assertThat(h1).isEqualTo(h2).hasSize(64);
    }

    @Test
    void empreintes_differentes_par_userAgent() {
        String h1 = DeviceService.fingerprint("Firefox/125", "fr-FR");
        String h2 = DeviceService.fingerprint("Chrome/120", "fr-FR");
        assertThat(h1).isNotEqualTo(h2);
    }

    @Test
    void empreintes_differentes_par_langue() {
        String h1 = DeviceService.fingerprint("Firefox/125", "fr-FR");
        String h2 = DeviceService.fingerprint("Firefox/125", "en-US");
        assertThat(h1).isNotEqualTo(h2);
    }

    @Test
    void empreinte_null_safe() {
        String h1 = DeviceService.fingerprint(null, null);
        String h2 = DeviceService.fingerprint(null, null);
        assertThat(h1).isEqualTo(h2).hasSize(64);
    }
}
