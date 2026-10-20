package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.tenant.User;
import bf.ycognicore.backend.repository.tenant.UserRepository;
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

class UserServiceTest {

    private UserRepository repo;
    private DataEncryptionService encryption;
    private HmacService hmacService;
    private UserService service;

    private static final byte[] HMAC_KEY = "test-hmac-key-32-bytes-minimum-ok"
        .getBytes(StandardCharsets.UTF_8);

    @BeforeEach
    void setUp() {
        repo = mock(UserRepository.class);
        encryption = mock(DataEncryptionService.class);
        hmacService = new HmacService();
        service = new UserService(repo, encryption, hmacService);
    }

    private User mkUser(String email, String telephone) {
        User u = new User();
        u.setEmail(email);
        u.setTelephone(telephone);
        return u;
    }

    @Test
    void save_chiffre_telephone_et_calcule_hmac() {
        UUID tenantId = UUID.randomUUID();
        User user = mkUser("alice@example.com", "70123456");

        when(encryption.getHmacKey(tenantId)).thenReturn(HMAC_KEY);
        when(encryption.encrypt(eq("70123456"), eq(tenantId), eq("telephone")))
            .thenReturn("v1:encrypted");
        when(repo.save(any())).thenAnswer(i -> i.getArgument(0));

        User saved = service.save(user, tenantId);

        assertThat(saved.getTelephone()).isEqualTo("v1:encrypted");
        assertThat(saved.getTelephoneHmac()).isNotNull().hasSize(64);
        assertThat(saved.getEmailHmac()).isNotNull().hasSize(64);
        verify(encryption, times(1)).encrypt("70123456", tenantId, "telephone");
    }

    @Test
    void save_email_seul_pas_de_chiffrement() {
        UUID tenantId = UUID.randomUUID();
        User user = mkUser("bob@example.com", null);

        when(encryption.getHmacKey(tenantId)).thenReturn(HMAC_KEY);
        when(repo.save(any())).thenAnswer(i -> i.getArgument(0));

        User saved = service.save(user, tenantId);

        assertThat(saved.getEmailHmac()).isNotNull().hasSize(64);
        assertThat(saved.getTelephoneHmac()).isNull();
        assertThat(saved.getTelephone()).isNull();
        verify(encryption, never()).encrypt(any(), any(), any());
    }

    @Test
    void findByEmail_utilise_hmac() {
        UUID tenantId = UUID.randomUUID();
        when(encryption.getHmacKey(tenantId)).thenReturn(HMAC_KEY);
        when(repo.findByEmailHmac(anyString())).thenReturn(Optional.empty());

        Optional<User> result = service.findByEmail("x@y.z", tenantId);

        assertThat(result).isEmpty();
        verify(repo).findByEmailHmac(anyString());
    }

    @Test
    void getTelephone_dechiffre() {
        UUID tenantId = UUID.randomUUID();
        User user = new User();
        user.setTelephone("v1:encrypted");

        when(encryption.decrypt("v1:encrypted", tenantId, "telephone"))
            .thenReturn("70123456");

        String result = service.getTelephone(user, tenantId);

        assertThat(result).isEqualTo("70123456");
    }
}
