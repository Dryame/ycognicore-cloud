package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.controlplane.ClesTenant;
import bf.ycognicore.backend.repository.controlplane.ClesTenantRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Service
public class EncryptionKeyRotationService {
    private static final Logger log = LoggerFactory.getLogger(EncryptionKeyRotationService.class);

    private final ClesTenantRepository clesRepository;
    private final VaultTransitService vault;
    private final DataEncryptionService encryptionService;

    public EncryptionKeyRotationService(ClesTenantRepository clesRepository,
                                        VaultTransitService vault,
                                        DataEncryptionService encryptionService) {
        this.clesRepository = clesRepository;
        this.vault = vault;
        this.encryptionService = encryptionService;
    }

    @Transactional(transactionManager = "controlPlaneTransactionManager")
    public ClesTenant rotate(UUID tenantId, ClesTenant.TypeCle typeCle) {
        List<ClesTenant> all = clesRepository
                .findByTenantIdAndTypeCleOrderByVersionDesc(tenantId, typeCle);

        int nextVersion = all.isEmpty() ? 1 : all.get(0).getVersion() + 1;

        // Deprecated l'ancienne ACTIVE
        for (ClesTenant old : all) {
            if (old.getStatut() == ClesTenant.StatutCle.ACTIVE) {
                old.setStatut(ClesTenant.StatutCle.DEPRECATED);
                old.setDateRotationEffectuee(OffsetDateTime.now());
                clesRepository.save(old);
            }
        }

        // Crée la nouvelle
        VaultTransitService.DataKeyResult result = vault.generateDataKey();
        ClesTenant cle = new ClesTenant();
        cle.setTenantId(tenantId);
        cle.setVersion(nextVersion);
        cle.setCleWrapped(result.ciphertext());
        cle.setTypeCle(typeCle);
        cle.setStatut(ClesTenant.StatutCle.ACTIVE);
        ClesTenant saved = clesRepository.save(cle);

        // Invalide cache
        encryptionService.invalidateCache(tenantId);

        log.info("Rotation {} v{} -> v{} pour tenant {}", typeCle, nextVersion - 1, nextVersion, tenantId);
        return saved;
    }

    /**
     * Clôture la rotation : passe toutes les clés DEPRECATED en REVOKED.
     * À appeler une fois que 100% des données ont été rechiffrées.
     */
    @Transactional(transactionManager = "controlPlaneTransactionManager")
    public void finalizeRotation(UUID tenantId, ClesTenant.TypeCle typeCle) {
        List<ClesTenant> all = clesRepository
                .findByTenantIdAndTypeCleOrderByVersionDesc(tenantId, typeCle);

        for (ClesTenant cle : all) {
            if (cle.getStatut() == ClesTenant.StatutCle.DEPRECATED) {
                cle.setStatut(ClesTenant.StatutCle.REVOKED);
                clesRepository.save(cle);
            }
        }
        log.info("Clôture de rotation pour tenant {} et type {}", tenantId, typeCle);
    }
}
