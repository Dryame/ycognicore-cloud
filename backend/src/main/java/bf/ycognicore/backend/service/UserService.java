package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.tenant.User;
import bf.ycognicore.backend.repository.tenant.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

/**
 * Service User : chiffre telephone a la sauvegarde + calcule HMAC.
 * Ref. : P4 L3.1, D-P4-3, D-P4-4, ADR-042.
 */
@Service
public class UserService {

    private static final Logger log = LoggerFactory.getLogger(UserService.class);

    private final UserRepository userRepository;
    private final DataEncryptionService encryption;
    private final HmacService hmacService;

    public UserService(UserRepository userRepository,
                       DataEncryptionService encryption,
                       HmacService hmacService) {
        this.userRepository = userRepository;
        this.encryption = encryption;
        this.hmacService = hmacService;
    }

    /**
     * Sauvegarde un user : chiffre le telephone en clair si necessaire
     * et calcule les HMAC email + telephone.
     * La cle de chiffrement est celle du tenant courant (TenantContext).
     */
    @Transactional
    public User save(User user, UUID tenantId) {
        byte[] hmacKey = encryption.getHmacKey(tenantId);

        if (user.getEmail() != null) {
            user.setEmailHmac(hmacService.hmac("EMAIL", user.getEmail(), hmacKey));
        }
        if (user.getTelephone() != null) {
            user.setTelephoneHmac(
                hmacService.hmac("TELEPHONE", user.getTelephone(), hmacKey));
            user.setTelephone(
                encryption.encrypt(user.getTelephone(), tenantId, "telephone"));
        } else {
            user.setTelephoneHmac(null);
        }

        log.debug("User sauvegarde : email={} telephone chiffre={}",
            user.getEmail(), user.getTelephone() != null);
        return userRepository.save(user);
    }

    /** Recherche par email en clair via HMAC. */
    public Optional<User> findByEmail(String email, UUID tenantId) {
        byte[] hmacKey = encryption.getHmacKey(tenantId);
        String h = hmacService.hmac("EMAIL", email, hmacKey);
        return userRepository.findByEmailHmac(h);
    }

    /** Dechiffre le telephone d'un user pour affichage. */
    public String getTelephone(User user, UUID tenantId) {
        if (user.getTelephone() == null) return null;
        return encryption.decrypt(user.getTelephone(), tenantId, "telephone");
    }
}
