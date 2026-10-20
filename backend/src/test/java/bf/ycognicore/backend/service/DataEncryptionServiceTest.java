package bf.ycognicore.backend.service;

import bf.ycognicore.backend.audit.CentralAuditService;
import bf.ycognicore.backend.entity.controlplane.ClesTenant;
import bf.ycognicore.backend.repository.controlplane.ClesTenantRepository;
import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class DataEncryptionServiceTest {

    private VaultTransitService vault;
    private ClesTenantRepository repo;
    private CentralAuditService audit;
    private Cache<DataKeyCacheConfig.CacheKey, byte[]> cache;
    private DataEncryptionService service;

    private static final byte[] DATA_KEY = new byte[32];

    @BeforeEach
    void setUp() {
        vault = mock(VaultTransitService.class);
        repo = mock(ClesTenantRepository.class);
        audit = mock(CentralAuditService.class);
        cache = Caffeine.newBuilder()
            .expireAfterWrite(Duration.ofMinutes(5))
            .maximumSize(100)
            .build();
        service = new DataEncryptionService(vault, repo, audit, cache);
        for (int i = 0; i < DATA_KEY.length; i++) DATA_KEY[i] = (byte) i;
    }

    private ClesTenant mkKey(UUID tenantId, int version) {
        ClesTenant k = new ClesTenant();
        k.setTenantId(tenantId);
        k.setVersion(version);
        k.setCleWrapped("vault:v1:wrapped-" + version);
        k.setTypeCle(ClesTenant.TypeCle.DATA);
        k.setStatut(ClesTenant.StatutCle.ACTIVE);
        return k;
    }

    @Test
    void encrypt_puis_decrypt_round_trip() {
        UUID tenantId = UUID.randomUUID();
        ClesTenant key = mkKey(tenantId, 1);
        when(repo.findFirstByTenantIdAndTypeCleAndStatut(
                eq(tenantId), eq(ClesTenant.TypeCle.DATA), eq(ClesTenant.StatutCle.ACTIVE)))
            .thenReturn(Optional.of(key));
        when(vault.decryptWrapped("vault:v1:wrapped-1")).thenReturn(DATA_KEY);

        String ct = service.encrypt("hello world", tenantId, "ifu");
        assertThat(ct).startsWith("v1:").contains(":");

        String pt = service.decrypt(ct, tenantId, "ifu");
        assertThat(pt).isEqualTo("hello world");
    }

    @Test
    void ciphertext_different_pour_meme_plaintext() {
        UUID tenantId = UUID.randomUUID();
        ClesTenant key = mkKey(tenantId, 1);
        when(repo.findFirstByTenantIdAndTypeCleAndStatut(any(), any(), any()))
            .thenReturn(Optional.of(key));
        when(vault.decryptWrapped(any())).thenReturn(DATA_KEY);

        String c1 = service.encrypt("meme valeur", tenantId, "ifu");
        String c2 = service.encrypt("meme valeur", tenantId, "ifu");
        assertThat(c1).isNotEqualTo(c2);
    }

    @Test
    void decrypt_tampered_throws() {
        UUID tenantId = UUID.randomUUID();
        ClesTenant key = mkKey(tenantId, 1);
        when(repo.findFirstByTenantIdAndTypeCleAndStatut(any(), any(), any()))
            .thenReturn(Optional.of(key));
        when(vault.decryptWrapped(any())).thenReturn(DATA_KEY);

        String ct = service.encrypt("secret", tenantId, "rccm");
        String tampered = ct.substring(0, ct.length() - 4) + "AAAA";

        assertThatThrownBy(() -> service.decrypt(tampered, tenantId, "rccm"))
            .isInstanceOf(DataEncryptionService.EncryptionUnavailableException.class);
    }

    @Test
    void cache_hit_evite_appel_vault() {
        UUID tenantId = UUID.randomUUID();
        ClesTenant key = mkKey(tenantId, 1);
        when(repo.findFirstByTenantIdAndTypeCleAndStatut(any(), any(), any()))
            .thenReturn(Optional.of(key));
        when(vault.decryptWrapped(any())).thenReturn(DATA_KEY);

        String c1 = service.encrypt("a", tenantId, "ifu");
        String c2 = service.encrypt("b", tenantId, "ifu");
        service.decrypt(c1, tenantId, "ifu");
        service.decrypt(c2, tenantId, "ifu");

        verify(vault, times(1)).decryptWrapped(any());
    }

    @Test
    void vault_ko_throws_fail_closed() {
        UUID tenantId = UUID.randomUUID();
        ClesTenant key = mkKey(tenantId, 1);
        when(repo.findFirstByTenantIdAndTypeCleAndStatut(any(), any(), any()))
            .thenReturn(Optional.of(key));
        when(vault.decryptWrapped(any()))
            .thenThrow(new RuntimeException("Vault down"));

        assertThatThrownBy(() -> service.encrypt("x", tenantId, "ifu"))
            .isInstanceOf(DataEncryptionService.EncryptionUnavailableException.class);
    }

    @Test
    void invalidate_cache_force_decrypt_vault() {
        UUID tenantId = UUID.randomUUID();
        ClesTenant key = mkKey(tenantId, 1);
        when(repo.findFirstByTenantIdAndTypeCleAndStatut(any(), any(), any()))
            .thenReturn(Optional.of(key));
        when(vault.decryptWrapped(any())).thenReturn(DATA_KEY);

        service.encrypt("x", tenantId, "ifu");
        service.invalidateCache(tenantId);
        service.encrypt("y", tenantId, "ifu");

        verify(vault, times(2)).decryptWrapped(any());
    }

    @Test
    void null_retourne_null() {
        assertThat(service.encrypt(null, UUID.randomUUID(), "ifu")).isNull();
        assertThat(service.decrypt(null, UUID.randomUUID(), "ifu")).isNull();
    }

    @Test
    void format_invalide_throws() {
        assertThatThrownBy(() -> service.decrypt("not-a-ciphertext", UUID.randomUUID(), "ifu"))
            .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> service.decrypt("v1", UUID.randomUUID(), "ifu"))
            .isInstanceOf(IllegalArgumentException.class);
    }
}
