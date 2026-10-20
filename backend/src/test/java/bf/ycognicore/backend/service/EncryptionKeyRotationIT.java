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

class EncryptionKeyRotationIT {

    private ClesTenantRepository repo;
    private VaultTransitService vault;
    private DataEncryptionService encryption;
    private EncryptionKeyRotationService service;

    @BeforeEach
    void setup() {
        repo = mock(ClesTenantRepository.class);
        vault = mock(VaultTransitService.class);
        encryption = mock(DataEncryptionService.class);
        service = new EncryptionKeyRotationService(repo, vault, encryption);
    }

    @Test
    void rotation_complete_et_double_lecture() {
        UUID tenantId = UUID.randomUUID();
        
        ClesTenant v1 = new ClesTenant();
        v1.setTenantId(tenantId);
        v1.setVersion(1);
        v1.setStatut(ClesTenant.StatutCle.ACTIVE);
        v1.setTypeCle(ClesTenant.TypeCle.DATA);

        when(repo.findByTenantIdAndTypeCleOrderByVersionDesc(tenantId, ClesTenant.TypeCle.DATA))
                .thenReturn(List.of(v1));
        when(repo.save(any())).thenAnswer(i -> i.getArgument(0));
        when(vault.generateDataKey()).thenReturn(new VaultTransitService.DataKeyResult(new byte[32], "vault:v2:wrapped"));

        ClesTenant v2 = service.rotate(tenantId, ClesTenant.TypeCle.DATA);

        assertThat(v2.getVersion()).isEqualTo(2);
        assertThat(v2.getStatut()).isEqualTo(ClesTenant.StatutCle.ACTIVE);
        assertThat(v1.getStatut()).isEqualTo(ClesTenant.StatutCle.DEPRECATED);
        verify(encryption).invalidateCache(tenantId);
    }

    @Test
    void finalize_rotation_passe_deprecated_en_revoked() {
        UUID tenantId = UUID.randomUUID();
        
        ClesTenant v1 = new ClesTenant();
        v1.setTenantId(tenantId);
        v1.setVersion(1);
        v1.setStatut(ClesTenant.StatutCle.DEPRECATED);

        when(repo.findByTenantIdAndTypeCleOrderByVersionDesc(tenantId, ClesTenant.TypeCle.DATA))
                .thenReturn(List.of(v1));

        service.finalizeRotation(tenantId, ClesTenant.TypeCle.DATA);

        assertThat(v1.getStatut()).isEqualTo(ClesTenant.StatutCle.REVOKED);
    }
}
