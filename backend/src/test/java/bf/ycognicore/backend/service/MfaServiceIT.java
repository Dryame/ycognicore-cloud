package bf.ycognicore.backend.service;

import bf.ycognicore.backend.config.VaultProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.warrenstrange.googleauth.GoogleAuthenticator;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

/**
 * Tests du service MFA : setup + vérification du code TOTP.
 *
 * Ref. : T1.2, M33, M41, exigence 2.2.
 * Stratégie : VaultTransitService mocké (pas de Vault réel).
 */
class MfaServiceIT {

    MfaService mfaService;

    @BeforeEach
    void setUp() {
        VaultTransitService vaultMock = Mockito.mock(VaultTransitService.class);
        when(vaultMock.encrypt(anyString())).thenAnswer(inv -> "enc:" + inv.getArgument(0));
        when(vaultMock.decrypt(anyString())).thenAnswer(inv -> {
            String c = inv.getArgument(0);
            return c.startsWith("enc:") ? c.substring(4) : c;
        });

        VaultProperties vaultProperties = new VaultProperties();
        ObjectMapper objectMapper = new ObjectMapper();

        mfaService = new MfaService(vaultMock, vaultProperties, objectMapper);
    }

    @Test
    void setup_genere_un_secret_et_une_qr_url() {
        var result = mfaService.setup("user@example.com");

        assertThat(result).isNotNull();
        assertThat(result.secret()).isNotBlank();
        assertThat(result.qrUrl()).isNotBlank();
        assertThat(result.qrUrl()).contains("otpauth");
        assertThat(result.qrUrl()).contains("user@example.com");
    }

    @Test
    void verifyCode_accepte_un_code_valide() {
        var setup = mfaService.setup("user@example.com");
        String secret = setup.secret();

        int codeValide = new GoogleAuthenticator().getTotpPassword(secret);

        boolean ok = mfaService.verifyCode(secret, codeValide);
        assertThat(ok)
                .as("Le code TOTP valide doit être accepté")
                .isTrue();
    }

    @Test
    void verifyCode_refuse_un_code_invalide() {
        var setup = mfaService.setup("user@example.com");
        String secret = setup.secret();

        boolean ok = mfaService.verifyCode(secret, 0);
        assertThat(ok)
                .as("Le code invalide doit être refusé")
                .isFalse();
    }

    @Test
    void verifyCode_refuse_un_code_proche_mais_incorrect() {
        var setup = mfaService.setup("user@example.com");
        String secret = setup.secret();

        int bonCode = new GoogleAuthenticator().getTotpPassword(secret);
        int mauvaisCode = (bonCode + 1) % 1_000_000;

        boolean ok = mfaService.verifyCode(secret, mauvaisCode);
        assertThat(ok)
                .as("Un code proche mais incorrect doit être refusé")
                .isFalse();
    }
}
