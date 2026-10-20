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

/**
 * Rotation manuelle des cles de chiffrement (D-P4-5).
 * Double lecture : ancien ciphertext reste dechiffrable (cle DEPRECATED).
 * Ref. : P4 L2, D-P4-5, ADR-041.
 */
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

    /**
     * Genere une nouvelle version de cle pour un tenant.
     * L'ancienne version passe en DEPRECATED (encore dechiffrable).
     */
    @Transactional(transactionManager = "controlPlaneTransactionManager")
    public ClesTenant rotate(UUID tenantId, ClesTenant.TypeCle typeCle) {
        List<ClesTenant> all = clesRepository
            .findByTenantIdAndTypeCleOrderByVersionDesc(tenantId, typeCle);

        int nextVersion = all.isEmpty() ? 1
            : all.get(0).getVersion() + 1;

        // Deprecated l'ancienne ACTIVE
        for (ClesTenant old : all) {
            if (old.getStatut() == ClesTenant.StatutCle.ACTIVE) {
                old.setStatut(ClesTenant.StatutCle.DEPRECATED);
                old.setDateRotationEffectuee(OffsetDateTime.now());
                clesRepository.save(old);
            }
        }

        // Cree la nouvelle
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
}
