package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.tenant.Tiers;
import bf.ycognicore.backend.repository.tenant.TiersRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

/**
 * Service Tiers : chiffre les champs sensibles a la sauvegarde + calcule HMAC.
 * Ref. : P4 L3.2, D-P4-3, D-P4-4, ADR-042.
 */
@Service
public class TiersService {

    private static final Logger log = LoggerFactory.getLogger(TiersService.class);

    private final TiersRepository tiersRepository;
    private final DataEncryptionService encryption;
    private final HmacService hmacService;

    public TiersService(TiersRepository tiersRepository,
                        DataEncryptionService encryption,
                        HmacService hmacService) {
        this.tiersRepository = tiersRepository;
        this.encryption = encryption;
        this.hmacService = hmacService;
    }

    /**
     * Sauvegarde un tiers : chiffre siu/rccm/telephone/email/conditions_reglement,
     * calcule les HMAC correspondants.
     */
    @Transactional
    public Tiers save(Tiers tiers, UUID tenantId) {
        byte[] hmacKey = encryption.getHmacKey(tenantId);

        if (tiers.getIfu() != null && !isEncrypted(tiers.getIfu())) {
            tiers.setIfuHmac(hmacService.hmac("IFU", tiers.getIfu(), hmacKey));
            tiers.setIfu(encryption.encrypt(tiers.getIfu(), tenantId, "ifu"));
        }
        if (tiers.getRccm() != null && !isEncrypted(tiers.getRccm())) {
            tiers.setRccmHmac(hmacService.hmac("RCCM", tiers.getRccm(), hmacKey));
            tiers.setRccm(encryption.encrypt(tiers.getRccm(), tenantId, "rccm"));
        }
        if (tiers.getTelephone() != null && !isEncrypted(tiers.getTelephone())) {
            tiers.setTelephoneHmac(hmacService.hmac("TELEPHONE", tiers.getTelephone(), hmacKey));
            tiers.setTelephone(encryption.encrypt(tiers.getTelephone(), tenantId, "telephone"));
        }
        if (tiers.getEmail() != null && !isEncrypted(tiers.getEmail())) {
            tiers.setEmailHmac(hmacService.hmac("EMAIL", tiers.getEmail(), hmacKey));
            tiers.setEmail(encryption.encrypt(tiers.getEmail(), tenantId, "email"));
        }
        if (tiers.getConditionsReglement() != null && !isEncrypted(tiers.getConditionsReglement())) {
            tiers.setConditionsReglement(
                encryption.encrypt(tiers.getConditionsReglement(), tenantId, "conditions_reglement"));
        }

        log.debug("Tiers sauvegarde : code={} (champs chiffres)", tiers.getCode());
        return tiersRepository.save(tiers);
    }

    /** Recherche par email en clair (via HMAC). */
    public Optional<Tiers> findByEmail(String email, UUID tenantId) {
        byte[] hmacKey = encryption.getHmacKey(tenantId);
        return tiersRepository.findByEmailHmac(hmacService.hmac("EMAIL", email, hmacKey));
    }

    /** Recherche par IFU en clair (via HMAC). */
    public Optional<Tiers> findByIfu(String ifu, UUID tenantId) {
        byte[] hmacKey = encryption.getHmacKey(tenantId);
        return tiersRepository.findByIfuHmac(hmacService.hmac("IFU", ifu, hmacKey));
    }

    /** Retourne le tiers avec champs dechiffres pour affichage. */
    public Tiers decryptForDisplay(Tiers tiers, UUID tenantId) {
        if (tiers.getIfu() != null)
            tiers.setIfu(encryption.decrypt(tiers.getIfu(), tenantId, "ifu"));
        if (tiers.getRccm() != null)
            tiers.setRccm(encryption.decrypt(tiers.getRccm(), tenantId, "rccm"));
        if (tiers.getTelephone() != null)
            tiers.setTelephone(encryption.decrypt(tiers.getTelephone(), tenantId, "telephone"));
        if (tiers.getEmail() != null)
            tiers.setEmail(encryption.decrypt(tiers.getEmail(), tenantId, "email"));
        if (tiers.getConditionsReglement() != null)
            tiers.setConditionsReglement(
                encryption.decrypt(tiers.getConditionsReglement(), tenantId, "conditions_reglement"));
        return tiers;
    }

    private static boolean isEncrypted(String v) {
        return v != null && v.length() > 1 && v.charAt(0) == 'v' && v.contains(":");
    }
}
