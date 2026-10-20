package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.tenant.Tiers;
import bf.ycognicore.backend.entity.tenant.User;
import bf.ycognicore.backend.repository.tenant.TiersRepository;
import bf.ycognicore.backend.repository.tenant.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
public class EncryptionMigrationService {
    private static final Logger log = LoggerFactory.getLogger(EncryptionMigrationService.class);
    private final TiersRepository tiersRepository;
    private final UserRepository userRepository;
    private final TiersService tiersService;
    private final UserService userService;

    public EncryptionMigrationService(TiersRepository tiersRepository,
                                       UserRepository userRepository,
                                       TiersService tiersService,
                                       UserService userService) {
        this.tiersRepository = tiersRepository;
        this.userRepository = userRepository;
        this.tiersService = tiersService;
        this.userService = userService;
    }

    @Transactional
    public int migrateTiers(UUID tenantId) {
        int count = 0;
        for (Tiers tiers : tiersRepository.findAll()) {
            if (needsEncryption(tiers.getIfu())
                || needsEncryption(tiers.getRccm())
                || needsEncryption(tiers.getTelephone())
                || needsEncryption(tiers.getEmail())
                || needsEncryption(tiers.getConditionsReglement())) {
                tiersService.save(tiers, tenantId);
                count++;
            }
        }
        log.info("Migration tiers : {} lignes migrees (tenant={})", count, tenantId);
        return count;
    }

    @Transactional
    public int migrateUsers(UUID tenantId) {
        int count = 0;
        for (User user : userRepository.findAll()) {
            if (needsEncryption(user.getTelephone())) {
                userService.save(user, tenantId);
                count++;
            }
        }
        log.info("Migration users : {} lignes migrees (tenant={})", count, tenantId);
        return count;
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
