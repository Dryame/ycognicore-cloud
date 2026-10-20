package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.tenant.Tiers;
import bf.ycognicore.backend.entity.tenant.User;
import bf.ycognicore.backend.repository.tenant.TiersRepository;
import bf.ycognicore.backend.repository.tenant.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
public class EncryptionMigrationService {
    private static final Logger log = LoggerFactory.getLogger(EncryptionMigrationService.class);
    private static final int BATCH_SIZE = 1000;

    private final TiersRepository tiersRepository;
    private final UserRepository userRepository;
    private final TiersService tiersService;
    private final UserService userService;
    private final DataEncryptionService encryption;

    public EncryptionMigrationService(TiersRepository tiersRepository,
                                      UserRepository userRepository,
                                      TiersService tiersService,
                                      UserService userService,
                                      DataEncryptionService encryption) {
        this.tiersRepository = tiersRepository;
        this.userRepository = userRepository;
        this.tiersService = tiersService;
        this.userService = userService;
        this.encryption = encryption;
    }

    /**
     * Migration initiale (chiffrement des données en clair).
     * Parcourt la base par lots pour éviter les OutOfMemory.
     */
    @Transactional
    public int migrateTiersInitial(UUID tenantId) {
        int total = 0;
        int page = 0;
        Page<Tiers> chunk;
        do {
            chunk = tiersRepository.findAll(PageRequest.of(page, BATCH_SIZE, Sort.by("id")));
            for (Tiers tiers : chunk.getContent()) {
                if (needsEncryption(tiers.getIfu()) || needsEncryption(tiers.getRccm())
                        || needsEncryption(tiers.getTelephone()) || needsEncryption(tiers.getEmail())
                        || needsEncryption(tiers.getConditionsReglement())) {
                    tiersService.save(tiers, tenantId);
                    total++;
                }
            }
            page++;
        } while (chunk.hasNext());

        log.info("Migration initiale tiers terminée : {} lignes migrées (tenant={})", total, tenantId);
        return total;
    }

    @Transactional
    public int migrateUsersInitial(UUID tenantId) {
        int total = 0;
        int page = 0;
        Page<User> chunk;
        do {
            chunk = userRepository.findAll(PageRequest.of(page, BATCH_SIZE, Sort.by("id")));
            for (User user : chunk.getContent()) {
                if (needsEncryption(user.getEmail()) || needsEncryption(user.getTelephone())) {
                    userService.save(user, tenantId);
                    total++;
                }
            }
            page++;
        } while (chunk.hasNext());

        log.info("Migration initiale users terminée : {} lignes migrées (tenant={})", total, tenantId);
        return total;
    }

    /**
     * Rechiffrement forcé pour la rotation de clé (D-P4-5).
     * Déchiffre avec l'ancienne clé (Vault le fait automatiquement) et force l'écriture
     * avec la nouvelle clé ACTIVE.
     */
    @Transactional
    public int reencryptTiers(UUID tenantId) {
        int total = 0;
        int page = 0;
        Page<Tiers> chunk;
        do {
            chunk = tiersRepository.findAll(PageRequest.of(page, BATCH_SIZE, Sort.by("id")));
            for (Tiers tiers : chunk.getContent()) {
                // On force le déchiffrement (peu importe la version) et le rechiffrement
                if (tiers.getIfu() != null) tiers.setIfu(encryption.decrypt(tiers.getIfu(), tenantId, "ifu"));
                if (tiers.getRccm() != null) tiers.setRccm(encryption.decrypt(tiers.getRccm(), tenantId, "rccm"));
                if (tiers.getTelephone() != null) tiers.setTelephone(encryption.decrypt(tiers.getTelephone(), tenantId, "telephone"));
                if (tiers.getEmail() != null) tiers.setEmail(encryption.decrypt(tiers.getEmail(), tenantId, "email"));
                if (tiers.getConditionsReglement() != null) tiers.setConditionsReglement(encryption.decrypt(tiers.getConditionsReglement(), tenantId, "conditions_reglement"));
                
                tiersService.save(tiers, tenantId);
                total++;
            }
            page++;
        } while (chunk.hasNext());
        log.info("Rechiffrement tiers (rotation) terminé : {} lignes traitées", total);
        return total;
    }

    @Transactional
    public int reencryptUsers(UUID tenantId) {
        int total = 0;
        int page = 0;
        Page<User> chunk;
        do {
            chunk = userRepository.findAll(PageRequest.of(page, BATCH_SIZE, Sort.by("id")));
            for (User user : chunk.getContent()) {
                if (user.getEmail() != null) user.setEmail(encryption.decrypt(user.getEmail(), tenantId, "email"));
                if (user.getTelephone() != null) user.setTelephone(encryption.decrypt(user.getTelephone(), tenantId, "telephone"));
                
                userService.save(user, tenantId);
                total++;
            }
            page++;
        } while (chunk.hasNext());
        log.info("Rechiffrement users (rotation) terminé : {} lignes traitées", total);
        return total;
    }

    private static boolean needsEncryption(String v) {
        if (v == null || v.isBlank()) return false;
        if (v.charAt(0) != 'v') return true;
        int colon = v.indexOf(':');
        if (colon < 2) return true;
        for (int i = 1; i < colon; i++) {
            if (!Character.isDigit(v.charAt(i))) return true;
        }
        return false;
    }
}
