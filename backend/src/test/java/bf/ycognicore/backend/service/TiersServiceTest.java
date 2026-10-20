package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.tenant.Tiers;
import bf.ycognicore.backend.repository.tenant.TiersRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class TiersServiceTest {

    private TiersRepository repo;
    private DataEncryptionService encryption;
    private HmacService hmacService;
    private TiersService service;

    private static final byte[] HMAC_KEY = "test-hmac-key-32-bytes-minimum-ok"
        .getBytes(StandardCharsets.UTF_8);

    @BeforeEach
    void setUp() {
        repo = mock(TiersRepository.class);
        encryption = mock(DataEncryptionService.class);
        hmacService = new HmacService();
        service = new TiersService(repo, encryption, hmacService);
    }

    private Tiers mkTiers(String ifu, String email, String telephone) {
        Tiers t = new Tiers();
        t.setCode("T001");
        t.setRaisonSociale("ACME SARL");
        t.setIfu(ifu);
        t.setEmail(email);
        t.setTelephone(telephone);
        return t;
    }

    @Test
    void save_chiffre_ifu_telephone_email_et_calcule_hmac() {
        UUID tenantId = UUID.randomUUID();
        Tiers tiers = mkTiers("123456", "contact@acme.bf", "70123456");

        when(encryption.getHmacKey(tenantId)).thenReturn(HMAC_KEY);
        when(encryption.encrypt(eq("123456"), eq(tenantId), eq("ifu"))).thenReturn("v1:enc-ifu");
        when(encryption.encrypt(eq("contact@acme.bf"), eq(tenantId), eq("email"))).thenReturn("v1:enc-email");
        when(encryption.encrypt(eq("70123456"), eq(tenantId), eq("telephone"))).thenReturn("v1:enc-tel");
        when(repo.save(any())).thenAnswer(i -> i.getArgument(0));

        Tiers saved = service.save(tiers, tenantId);

        assertThat(saved.getIfu()).isEqualTo("v1:enc-ifu");
        assertThat(saved.getEmail()).isEqualTo("v1:enc-email");
        assertThat(saved.getTelephone()).isEqualTo("v1:enc-tel");
        assertThat(saved.getIfuHmac()).isNotNull().hasSize(64);
        assertThat(saved.getEmailHmac()).isNotNull().hasSize(64);
        assertThat(saved.getTelephoneHmac()).isNotNull().hasSize(64);
    }

    @Test
    void save_idempotent_champs_deja_chiffres() {
        UUID tenantId = UUID.randomUUID();
        Tiers tiers = mkTiers("v1:already-encrypted", null, null);

        when(encryption.getHmacKey(tenantId)).thenReturn(HMAC_KEY);
        when(repo.save(any())).thenAnswer(i -> i.getArgument(0));

        Tiers saved = service.save(tiers, tenantId);

        assertThat(saved.getIfu()).isEqualTo("v1:already-encrypted");
        verify(encryption, never()).encrypt(eq("v1:already-encrypted"), any(), any());
    }

    @Test
    void findByEmail_utilise_hmac() {
        UUID tenantId = UUID.randomUUID();
        when(encryption.getHmacKey(tenantId)).thenReturn(HMAC_KEY);
        when(repo.findByEmailHmac(anyString())).thenReturn(Optional.empty());

        Optional<Tiers> result = service.findByEmail("x@y.z", tenantId);

        assertThat(result).isEmpty();
        verify(repo).findByEmailHmac(anyString());
    }

    @Test
    void decryptForDisplay_retourne_valeurs_en_clair() {
        UUID tenantId = UUID.randomUUID();
        Tiers tiers = mkTiers("v1:enc-ifu", "v1:enc-email", "v1:enc-tel");

        when(encryption.decrypt("v1:enc-ifu", tenantId, "ifu")).thenReturn("123456");
        when(encryption.decrypt("v1:enc-email", tenantId, "email")).thenReturn("contact@acme.bf");
        when(encryption.decrypt("v1:enc-tel", tenantId, "telephone")).thenReturn("70123456");

        service.decryptForDisplay(tiers, tenantId);

        assertThat(tiers.getIfu()).isEqualTo("123456");
        assertThat(tiers.getEmail()).isEqualTo("contact@acme.bf");
        assertThat(tiers.getTelephone()).isEqualTo("70123456");
    }
}
