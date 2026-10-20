package bf.ycognicore.backend.service;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Tests HmacService — normalisation + HMAC.
 * Ref. : P4 L2, fiche P4 section 5.1.
 */
class HmacServiceTest {

    private static final byte[] KEY = "test-hmac-key-32-bytes-minimum-ok".getBytes(StandardCharsets.UTF_8);
    private final HmacService service = new HmacService();

    @Test
    void normalisation_email() {
        assertThat(service.normalize("EMAIL", "  Alice@Example.COM "))
            .isEqualTo("alice@example.com");
    }

    @Test
    void normalisation_ifu() {
        assertThat(service.normalize("IFU", " 123-456 ")).isEqualTo("123456");
        assertThat(service.normalize("IFU", "123.456")).isEqualTo("123456");
        assertThat(service.normalize("IFU", "abc-123")).isEqualTo("ABC123");
    }

    @Test
    void normalisation_rccm() {
        assertThat(service.normalize("RCCM", "BF-OUA-2019-B-1234"))
            .isEqualTo("BFOUA2019B1234");
    }

    @Test
    void normalisation_telephone() {
        assertThat(service.normalize("TELEPHONE", "+226 70-12-34-56")).isEqualTo("70123456");
        assertThat(service.normalize("TELEPHONE", "0022670123456")).isEqualTo("70123456");
        assertThat(service.normalize("TELEPHONE", "(+226) 70123456")).isEqualTo("70123456");
        assertThat(service.normalize("TELEPHONE", "70 12 34 56")).isEqualTo("70123456");
    }

    @Test
    void hmac_email_stable() {
        String h1 = service.hmac("EMAIL", "  Alice@Example.COM ", KEY);
        String h2 = service.hmac("EMAIL", "alice@example.com", KEY);
        assertThat(h1).isEqualTo(h2).hasSize(64);
    }

    @Test
    void hmac_ifu_avec_et_sans_separateurs_identiques() {
        String h1 = service.hmac("IFU", " 123-456 ", KEY);
        String h2 = service.hmac("IFU", "123456", KEY);
        assertThat(h1).isEqualTo(h2);
    }

    @Test
    void hmac_telephone_avec_prefixes_identiques() {
        String h1 = service.hmac("TELEPHONE", "+226 70-12-34-56", KEY);
        String h2 = service.hmac("TELEPHONE", "70123456", KEY);
        assertThat(h1).isEqualTo(h2);
    }

    @Test
    void hmac_valeurs_differentes_donnent_hmac_differents() {
        String h1 = service.hmac("EMAIL", "alice@example.com", KEY);
        String h2 = service.hmac("EMAIL", "bob@example.com", KEY);
        assertThat(h1).isNotEqualTo(h2);
    }

    @Test
    void hmac_null_retourne_null() {
        assertThat(service.hmac("EMAIL", null, KEY)).isNull();
        assertThat(service.hmac("EMAIL", "", KEY)).isNull();
        assertThat(service.hmac("EMAIL", "   ", KEY)).isNull();
    }

    @Test
    void hmac_cle_invalide_leve_exception() {
        assertThatThrownBy(() -> service.hmac("EMAIL", "a@b.c", new byte[4]))
            .isInstanceOf(IllegalArgumentException.class);
    }
}
