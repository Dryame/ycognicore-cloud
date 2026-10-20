package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.tenant.Tiers;
import bf.ycognicore.backend.entity.tenant.User;
import bf.ycognicore.backend.repository.tenant.TiersRepository;
import bf.ycognicore.backend.repository.tenant.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

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
    private DataEncryptionService encryption;
    private EncryptionMigrationService migration;

    @BeforeEach
    void setup() {
        tiersRepository = mock(TiersRepository.class);
        userRepository = mock(UserRepository.class);
        tiersService = mock(TiersService.class);
        userService = mock(UserService.class);
        encryption = mock(DataEncryptionService.class);
        migration = new EncryptionMigrationService(
                tiersRepository, userRepository, tiersService, userService, encryption);
    }

    private Tiers plainTiers() {
        Tiers t = new Tiers();
        t.setCode("T001");
        t.setRaisonSociale("ACME");
        t.setIfu("123456");
        t.setEmail("contact@acme.bf");
        t.setTelephone("70123456");
        return t;
    }

    private Tiers encryptedTiers() {
        Tiers t = new Tiers();
        t.setCode("T002");
        t.setRaisonSociale("BETA");
        t.setIfu("v1:encrypted");
        t.setEmail("v1:encrypted");
        t.setTelephone("v1:encrypted");
        return t;
    }

    @Test
    void migrateTiersInitial_chiffre_les_non_chiffres() {
        UUID tenantId = UUID.randomUUID();
        Tiers plain = plainTiers();
        Tiers already = encryptedTiers();

        Page<Tiers> page = new PageImpl<>(List.of(plain, already));
        when(tiersRepository.findAll(any(Pageable.class))).thenReturn(page);

        int count = migration.migrateTiersInitial(tenantId);

        assertThat(count).isEqualTo(1);
        verify(tiersService, times(1)).save(eq(plain), eq(tenantId));
        verify(tiersService, never()).save(eq(already), any());
    }

    @Test
    void migrateTiersInitial_idempotent() {
        UUID tenantId = UUID.randomUUID();
        Page<Tiers> page = new PageImpl<>(List.of(encryptedTiers()));
        when(tiersRepository.findAll(any(Pageable.class))).thenReturn(page);

        assertThat(migration.migrateTiersInitial(tenantId)).isEqualTo(0);
        verify(tiersService, never()).save(any(), any());
    }

    @Test
    void migrateUsersInitial_chiffre_si_email_ou_tel_en_clair() {
        UUID tenantId = UUID.randomUUID();
        User u1 = new User(); u1.setEmail("a@b.c"); u1.setTelephone("70123456"); // clair
        User u2 = new User(); u2.setEmail("v1:encrypted"); u2.setTelephone(null); // chiffré
        User u3 = new User(); u3.setEmail("v1:encrypted"); u3.setTelephone("v1:encrypted"); // chiffré

        Page<User> page = new PageImpl<>(List.of(u1, u2, u3));
        when(userRepository.findAll(any(Pageable.class))).thenReturn(page);

        int count = migration.migrateUsersInitial(tenantId);

        assertThat(count).isEqualTo(1);
        verify(userService, times(1)).save(eq(u1), eq(tenantId));
        verify(userService, never()).save(eq(u2), any());
        verify(userService, never()).save(eq(u3), any());
    }

    @Test
    void reencryptTiers_force_le_rechiffrement() {
        UUID tenantId = UUID.randomUUID();
        Tiers t = encryptedTiers();
        Page<Tiers> page = new PageImpl<>(List.of(t));
        when(tiersRepository.findAll(any(Pageable.class))).thenReturn(page);
        when(encryption.decrypt(anyString(), eq(tenantId), anyString())).thenReturn("plain");

        int count = migration.reencryptTiers(tenantId);

        assertThat(count).isEqualTo(1);
        verify(tiersService, times(1)).save(eq(t), eq(tenantId));
        verify(encryption, times(3)).decrypt(anyString(), eq(tenantId), anyString()); // ifu, email, tel
    }
}
