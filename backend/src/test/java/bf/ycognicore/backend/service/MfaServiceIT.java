package bf.ycognicore.backend.service;

import bf.ycognicore.backend.config.VaultProperties;
import bf.ycognicore.backend.repository.controlplane.TenantRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.warrenstrange.googleauth.GoogleAuthenticator;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

class MfaServiceIT {

    MfaService mfaService;

    @BeforeEach
    void setup() {
        VaultTransitService vaultMock = Mockito.mock(VaultTransitService.class);
        when(vaultMock.encrypt(anyString())).thenAnswer(inv -> "enc:" + inv.getArgument(0));
        when(vaultMock.decrypt(anyString())).thenAnswer(inv -> {
            String c = inv.getArgument(0);
            return c.startsWith("enc:") ? c.substring(4) : c;
        });

        VaultProperties vaultProperties = new VaultProperties();
        ObjectMapper objectMapper = new ObjectMapper();
        
        // Ajout des nouveaux mocks requis par le constructeur
        UserService userServiceMock = Mockito.mock(UserService.class);
        TenantRepository tenantRepositoryMock = Mockito.mock(TenantRepository.class);

        mfaService = new MfaService(vaultMock, vaultProperties, objectMapper, userServiceMock, tenantRepositoryMock);
    }

    @Test
    void setup_genere_un_secret_et_une_qr_url() {
        var result = mfaService.setup("user@example.com");
        assertThat(result).isNotNull();
        assertThat(result.secret()).isNotBlank();
        assertThat(result.qrUrl()).isNotBlank();
    }

    @Test
    void verifyCode_accepte_un_code_valide() {
        var setup = mfaService.setup("user@example.com");
        String secret = setup.secret();
        int codeValide = new GoogleAuthenticator().getTotpPassword(secret);
        boolean ok = mfaService.verifyCode(secret, codeValide);
        assertThat(ok).isTrue();
    }

    @Test
    void verifyCode_refuse_un_code_invalide() {
        var setup = mfaService.setup("user@example.com");
        String secret = setup.secret();
        boolean ok = mfaService.verifyCode(secret, 0);
        assertThat(ok).isFalse();
    }
}
