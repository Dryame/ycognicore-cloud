package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.tenant.Tiers;
import bf.ycognicore.backend.entity.tenant.User;
import bf.ycognicore.backend.repository.tenant.TiersRepository;
import bf.ycognicore.backend.repository.tenant.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Arrays;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class EncryptionMigrationServiceIT {

    private TiersRepository tiersRepository;
    private UserRepository userRepository;
    private TiersService tiersService;
    private UserService userService;
    private EncryptionMigrationService migration;

    @BeforeEach
    void setUp() {
        tiersRepository = mock(TiersRepository.class);
        userRepository = mock(UserRepository.class);
        tiersService = mock(TiersService.class);
        userService = mock(UserService.class);
        migration = new EncryptionMigrationService(
            tiersRepository, userRepository, tiersService, userService);
    }

    private Tiers plainTiers() {
        Tiers t = new Tiers();
        t.setCode("T001"); t.setRaisonSociale("ACME");
        t.setIfu("123456"); t.setEmail("contact@acme.bf"); t.setTelephone("70123456");
        return t;
    }

    private Tiers encryptedTiers() {
        Tiers t = new Tiers();
        t.setCode("T002"); t.setRaisonSociale("BETA");
        t.setIfu("v1:encrypted"); t.setEmail("v1:encrypted"); t.setTelephone("v1:encrypted");
        return t;
    }

    @Test
    void migrateTiers_chiffre_les_non_chiffres() {
        UUID tenantId = UUID.randomUUID();
        Tiers plain = plainTiers();
        Tiers already = encryptedTiers();
        when(tiersRepository.findAll()).thenReturn(Arrays.asList(plain, already));

        int count = migration.migrateTiers(tenantId);

        assertThat(count).isEqualTo(1);
        verify(tiersService, times(1)).save(eq(plain), eq(tenantId));
        verify(tiersService, never()).save(eq(already), any());
    }

    @Test
    void migrateTiers_idempotent() {
        UUID tenantId = UUID.randomUUID();
        when(tiersRepository.findAll()).thenReturn(List.of(encryptedTiers()));
        assertThat(migration.migrateTiers(tenantId)).isEqualTo(0);
        verify(tiersService, never()).save(any(), any());
    }

    @Test
    void migrateUsers_chiffre_telephone_seulement() {
        UUID tenantId = UUID.randomUUID();
        User u1 = new User(); u1.setEmail("a@b.c"); u1.setTelephone("70123456");
        User u2 = new User(); u2.setEmail("b@c.d"); u2.setTelephone(null);
        User u3 = new User(); u3.setEmail("c@d.e"); u3.setTelephone("v1:encrypted");
        when(userRepository.findAll()).thenReturn(List.of(u1, u2, u3));

        int count = migration.migrateUsers(tenantId);

        assertThat(count).isEqualTo(1);
        verify(userService, times(1)).save(eq(u1), eq(tenantId));
        verify(userService, never()).save(eq(u2), any());
        verify(userService, never()).save(eq(u3), any());
    }

    @Test
    void needsEncryption_detecte_format_chiffre() throws Exception {
        var m = EncryptionMigrationService.class
            .getDeclaredMethod("needsEncryption", String.class);
        m.setAccessible(true);
        assertThat(m.invoke(null, "v1:base64val")).isEqualTo(false);
        assertThat(m.invoke(null, "v42:base64val")).isEqualTo(false);
        assertThat(m.invoke(null, "123456")).isEqualTo(true);
        assertThat(m.invoke(null, "v1")).isEqualTo(true);
        assertThat(m.invoke(null, "v:base64val")).isEqualTo(true);
        assertThat(m.invoke(null, (Object) null)).isEqualTo(false);
    }
}
