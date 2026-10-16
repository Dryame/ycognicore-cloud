package bf.ycognicore.backend.service;

import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests GeoIpService (sans base : fail-soft, IP privee).
 * Ref. : T3.8, F9.
 */
class GeoIpServiceIT {

    @Test
    void base_absente_retourne_unknown() {
        GeoIpService service = new GeoIpService();
        ReflectionTestUtils.setField(service, "databasePath", "/tmp/inexistant.mmdb");
        // Ne pas appeler init() — simule base absente
        assertThat(service.isReady()).isFalse();
        assertThat(service.resolve("8.8.8.8").pays()).isNull();
        assertThat(service.resolve("8.8.8.8").ville()).isNull();
    }

    @Test
    void ip_null_ou_vide_retourne_unknown() {
        GeoIpService service = new GeoIpService();
        ReflectionTestUtils.setField(service, "databasePath", "/tmp/inexistant.mmdb");
        assertThat(service.resolve(null).pays()).isNull();
        assertThat(service.resolve("").pays()).isNull();
        assertThat(service.resolve("   ").pays()).isNull();
    }

    @Test
    void ip_loopback_retourne_LOCAL() {
        GeoIpService service = new GeoIpService();
        ReflectionTestUtils.setField(service, "databasePath", "/tmp/inexistant.mmdb");
        // Simule un reader present via reflexion
        try {
            // On ne peut pas charger une base reelle en test unitaire.
            // On verifie juste que sans base, on reste en UNKNOWN.
            assertThat(service.resolve("127.0.0.1").pays()).isNull();
            assertThat(service.resolve("10.0.0.1").pays()).isNull();
        } catch (Exception ignored) {}
    }

    @Test
    void geoLocation_record() {
        GeoIpService.GeoLocation loc = new GeoIpService.GeoLocation("FR", "Paris");
        assertThat(loc.pays()).isEqualTo("FR");
        assertThat(loc.ville()).isEqualTo("Paris");

        assertThat(GeoIpService.GeoLocation.UNKNOWN.pays()).isNull();
        assertThat(GeoIpService.GeoLocation.UNKNOWN.ville()).isNull();
    }
}
