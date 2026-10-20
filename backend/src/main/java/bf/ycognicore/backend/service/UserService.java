package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.tenant.User;
import bf.ycognicore.backend.repository.tenant.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

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

    @Transactional
    public User save(User user, UUID tenantId) {
        byte[] hmacKey = encryption.getHmacKey(tenantId);

        if (user.getEmail() != null && !isEncrypted(user.getEmail())) {
            user.setEmailHmac(hmacService.hmac("EMAIL", user.getEmail(), hmacKey));
            user.setEmail(encryption.encrypt(user.getEmail(), tenantId, "email"));
        }
        if (user.getTelephone() != null && !isEncrypted(user.getTelephone())) {
            user.setTelephoneHmac(hmacService.hmac("TELEPHONE", user.getTelephone(), hmacKey));
            user.setTelephone(encryption.encrypt(user.getTelephone(), tenantId, "telephone"));
        } else if (user.getTelephone() == null) {
            user.setTelephoneHmac(null);
        }
        log.debug("User sauvegarde : email chiffre, telephone chiffre");
        return userRepository.save(user);
    }

    public Optional<User> findByEmail(String email, UUID tenantId) {
        byte[] hmacKey = encryption.getHmacKey(tenantId);
        String h = hmacService.hmac("EMAIL", email, hmacKey);
        return userRepository.findByEmailHmac(h);
    }

    /** Déchiffre les champs pour l'affichage (ex: génération de token JWT). */
    public User decryptForDisplay(User user, UUID tenantId) {
        if (user.getEmail() != null) {
            user.setEmail(encryption.decrypt(user.getEmail(), tenantId, "email"));
        }
        if (user.getTelephone() != null) {
            user.setTelephone(encryption.decrypt(user.getTelephone(), tenantId, "telephone"));
        }
        return user;
    }

    private static boolean isEncrypted(String v) {
        return v != null && v.length() > 1 && v.charAt(0) == 'v' && v.contains(":");
    }
}
