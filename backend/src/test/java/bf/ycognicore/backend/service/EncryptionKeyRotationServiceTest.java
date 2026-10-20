package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.controlplane.ClesTenant;
import bf.ycognicore.backend.repository.controlplane.ClesTenantRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class EncryptionKeyRotationServiceTest {

    private ClesTenantRepository repo;
    private VaultTransitService vault;
    private DataEncryptionService encryption;
    private EncryptionKeyRotationService service;

    @BeforeEach
    void setUp() {
        repo = mock(ClesTenantRepository.class);
        vault = mock(VaultTransitService.class);
        encryption = mock(DataEncryptionService.class);
        service = new EncryptionKeyRotationService(repo, vault, encryption);
    }

    private ClesTenant mkKey(UUID tenantId, int version, ClesTenant.StatutCle statut) {
        ClesTenant k = new ClesTenant();
        k.setTenantId(tenantId);
        k.setVersion(version);
        k.setCleWrapped("vault:v1:wrapped-" + version);
        k.setTypeCle(ClesTenant.TypeCle.DATA);
        k.setStatut(statut);
        return k;
    }

    @Test
    void rotation_cree_nouvelle_version_et_deprecated_ancienne() {
        UUID tenantId = UUID.randomUUID();
        ClesTenant v1 = mkKey(tenantId, 1, ClesTenant.StatutCle.ACTIVE);
        when(repo.findByTenantIdAndTypeCleOrderByVersionDesc(tenantId, ClesTenant.TypeCle.DATA))
            .thenReturn(List.of(v1));
        when(repo.save(any())).thenAnswer(i -> i.getArgument(0));
        when(vault.generateDataKey())
            .thenReturn(new VaultTransitService.DataKeyResult(new byte[32], "vault:v1:wrapped-2"));

        ClesTenant result = service.rotate(tenantId, ClesTenant.TypeCle.DATA);

        assertThat(result.getVersion()).isEqualTo(2);
        assertThat(result.getStatut()).isEqualTo(ClesTenant.StatutCle.ACTIVE);
        assertThat(v1.getStatut()).isEqualTo(ClesTenant.StatutCle.DEPRECATED);
        verify(encryption, times(1)).invalidateCache(tenantId);
    }

    @Test
    void premiere_rotation_sur_tenant_sans_cle() {
        UUID tenantId = UUID.randomUUID();
        when(repo.findByTenantIdAndTypeCleOrderByVersionDesc(tenantId, ClesTenant.TypeCle.DATA))
            .thenReturn(List.of());
        when(repo.save(any())).thenAnswer(i -> i.getArgument(0));
        when(vault.generateDataKey())
            .thenReturn(new VaultTransitService.DataKeyResult(new byte[32], "vault:v1:wrapped-1"));

        ClesTenant result = service.rotate(tenantId, ClesTenant.TypeCle.DATA);

        assertThat(result.getVersion()).isEqualTo(1);
        assertThat(result.getStatut()).isEqualTo(ClesTenant.StatutCle.ACTIVE);
    }

    @Test
    void rotation_invalide_cache() {
        UUID tenantId = UUID.randomUUID();
        when(repo.findByTenantIdAndTypeCleOrderByVersionDesc(any(), any())).thenReturn(List.of());
        when(repo.save(any())).thenAnswer(i -> i.getArgument(0));
        when(vault.generateDataKey())
            .thenReturn(new VaultTransitService.DataKeyResult(new byte[32], "vault:v1:new"));

        service.rotate(tenantId, ClesTenant.TypeCle.DATA);

        verify(encryption).invalidateCache(tenantId);
    }
}
