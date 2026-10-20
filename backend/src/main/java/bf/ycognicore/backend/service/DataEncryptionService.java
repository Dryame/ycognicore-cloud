package bf.ycognicore.backend.service;

import bf.ycognicore.backend.audit.AuditEvent;
import bf.ycognicore.backend.audit.CentralAuditService;
import bf.ycognicore.backend.audit.OperationCritique;
import bf.ycognicore.backend.entity.controlplane.ClesTenant;
import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.repository.controlplane.ClesTenantRepository;
import com.github.benmanes.caffeine.cache.Cache;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.util.Arrays;
import java.util.Base64;
import java.util.UUID;

/**
 * Chiffrement applicatif en enveloppe (D-10).
 * Cle maitresse (Vault) -> cle de donnees par tenant -> valeur de champ.
 * Format ciphertext : v{N}:base64(iv || ciphertext+tag).
 * Ref. : P4 L2, D-P4-1, D-P4-2, D-P4-7, D-P4-9, D-P4-11, ADR-040, ADR-043.
 */
@Service
public class DataEncryptionService {

    private static final Logger log = LoggerFactory.getLogger(DataEncryptionService.class);
    private static final String AES_GCM = "AES/GCM/NoPadding";
    private static final int GCM_IV_BYTES = 12;
    private static final int GCM_TAG_BITS = 128;
    private static final int AES_KEY_BYTES = 32;

    private final VaultTransitService vault;
    private final ClesTenantRepository clesRepository;
    private final CentralAuditService audit;
    private final Cache<DataKeyCacheConfig.CacheKey, byte[]> cache;
    private final SecureRandom rng = new SecureRandom();

    public DataEncryptionService(
            VaultTransitService vault,
            ClesTenantRepository clesRepository,
            CentralAuditService audit,
            @Qualifier("dataKeyCache") Cache<DataKeyCacheConfig.CacheKey, byte[]> cache) {
        this.vault = vault;
        this.clesRepository = clesRepository;
        this.audit = audit;
        this.cache = cache;
    }

    /**
     * Chiffre un champ. Initialise la cle DATA du tenant si absente.
     * Format : v{N}:base64(iv || ciphertext+tag).
     */
    @Transactional(transactionManager = "controlPlaneTransactionManager")
    public String encrypt(String plaintext, UUID tenantId, String field) {
        if (plaintext == null) return null;

        ClesTenant cle;
        byte[] dataKey;
        try {
            cle = getOrCreateActiveKey(tenantId, ClesTenant.TypeCle.DATA);
            dataKey = getDataKey(cle);
        } catch (EncryptionUnavailableException e) {
            throw e;
        } catch (Exception e) {
            throw new EncryptionUnavailableException(
                "Recuperation cle DATA echouee (tenant=" + tenantId + ")", e);
        }

        try {
            byte[] iv = new byte[GCM_IV_BYTES];
            rng.nextBytes(iv);
            Cipher cipher = Cipher.getInstance(AES_GCM);
            cipher.init(Cipher.ENCRYPT_MODE,
                new SecretKeySpec(dataKey, "AES"),
                new GCMParameterSpec(GCM_TAG_BITS, iv));
            byte[] ct = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));

            byte[] combined = new byte[iv.length + ct.length];
            System.arraycopy(iv, 0, combined, 0, iv.length);
            System.arraycopy(ct, 0, combined, iv.length, ct.length);

            return "v" + cle.getVersion() + ":" + Base64.getEncoder().encodeToString(combined);
        } catch (Exception e) {
            throw new EncryptionUnavailableException("Chiffrement echoue field=" + field, e);
        }
    }

    /**
     * Dechiffre un champ. Journalise la lecture (fail-closed strict D-P4-11).
     * Le format "v{N}:..." identifie la version de cle utilisee.
     */
    public String decrypt(String ciphertext, UUID tenantId, String field) {
        if (ciphertext == null) return null;

        int colon = ciphertext.indexOf(':');
        if (colon < 2 || ciphertext.charAt(0) != 'v') {
            throw new IllegalArgumentException("Format ciphertext invalide");
        }
        int version;
        try {
            version = Integer.parseInt(ciphertext.substring(1, colon));
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("Version invalide dans le ciphertext", e);
        }
        byte[] combined;
        try {
            combined = Base64.getDecoder().decode(ciphertext.substring(colon + 1));
        } catch (Exception e) {
            throw new IllegalArgumentException("Base64 invalide", e);
        }
        if (combined.length < GCM_IV_BYTES + 16) {
            throw new IllegalArgumentException("Ciphertext trop court");
        }

        ClesTenant cle;
        byte[] dataKey;
        try {
            cle = clesRepository
                .findFirstByTenantIdAndTypeCleAndStatut(
                    tenantId, ClesTenant.TypeCle.DATA, ClesTenant.StatutCle.ACTIVE)
                .filter(c -> c.getVersion() >= version)
                .orElseGet(() -> clesRepository
                    .findByTenantIdAndTypeCleOrderByVersionDesc(tenantId, ClesTenant.TypeCle.DATA)
                    .stream()
                    .filter(c -> c.getVersion() == version)
                    .findFirst()
                    .orElseThrow(() -> new IllegalStateException(
                        "Cle DATA v" + version + " introuvable pour tenant " + tenantId)));
            dataKey = getDataKey(cle);
        } catch (EncryptionUnavailableException e) {
            throw e;
        } catch (Exception e) {
            throw new EncryptionUnavailableException(
                "Recuperation cle DATA v" + version + " echouee (tenant=" + tenantId + ")", e);
        }

        try {
            byte[] iv = Arrays.copyOfRange(combined, 0, GCM_IV_BYTES);
            byte[] ct = Arrays.copyOfRange(combined, GCM_IV_BYTES, combined.length);
            Cipher cipher = Cipher.getInstance(AES_GCM);
            cipher.init(Cipher.DECRYPT_MODE,
                new SecretKeySpec(dataKey, "AES"),
                new GCMParameterSpec(GCM_TAG_BITS, iv));
            byte[] plaintextBytes = cipher.doFinal(ct);
            String plaintext = new String(plaintextBytes, StandardCharsets.UTF_8);

            auditRead(field);
            return plaintext;
        } catch (EncryptionUnavailableException e) {
            throw e;
        } catch (Exception e) {
            throw new EncryptionUnavailableException("Dechiffrement echoue field=" + field, e);
        }
    }

    /**
     * Retourne la cle HMAC du tenant (32 octets), dechiffree depuis Vault.
     * Cree la cle si absente. Cache Caffeine (D-P4-7).
     * Ref. : D-P4-4, ADR-042.
     */
    @Transactional(transactionManager = "controlPlaneTransactionManager")
    public byte[] getHmacKey(UUID tenantId) {
        ClesTenant cle = getOrCreateActiveKey(tenantId, ClesTenant.TypeCle.HMAC);
        return getDataKey(cle);
    }

    /** Invalide le cache pour un tenant (apres rotation). */
    public void invalidateCache(UUID tenantId) {
        cache.asMap().keySet().removeIf(k -> k.tenantId().equals(tenantId));
        log.info("Cache cles invalide pour tenant {}", tenantId);
    }

    // ----- Interne -----

    private ClesTenant getOrCreateActiveKey(UUID tenantId, ClesTenant.TypeCle typeCle) {
        return clesRepository
            .findFirstByTenantIdAndTypeCleAndStatut(
                tenantId, typeCle, ClesTenant.StatutCle.ACTIVE)
            .orElseGet(() -> createKey(tenantId, typeCle, 1));
    }

    @Transactional(transactionManager = "controlPlaneTransactionManager")
    protected ClesTenant createKey(UUID tenantId, ClesTenant.TypeCle typeCle, int version) {
        VaultTransitService.DataKeyResult result = vault.generateDataKey();
        ClesTenant cle = new ClesTenant();
        cle.setTenantId(tenantId);
        cle.setVersion(version);
        cle.setCleWrapped(result.ciphertext());
        cle.setTypeCle(typeCle);
        cle.setStatut(ClesTenant.StatutCle.ACTIVE);
        ClesTenant saved = clesRepository.save(cle);
        log.info("Cle {} v{} creee pour tenant {} (wrapped={}...)",
            typeCle, version, tenantId, result.ciphertext().substring(0, 20));
        return saved;
    }

    private byte[] getDataKey(ClesTenant cle) {
        DataKeyCacheConfig.CacheKey cacheKey = new DataKeyCacheConfig.CacheKey(
            cle.getTenantId(), cle.getTypeCle(), cle.getVersion());

        byte[] cached = cache.getIfPresent(cacheKey);
        if (cached != null) return cached;

        byte[] plaintext = vault.decryptWrapped(cle.getCleWrapped());
        if (plaintext.length != AES_KEY_BYTES) {
            throw new EncryptionUnavailableException(
                "Cle DATA de taille invalide : " + plaintext.length + " octets");
        }
        cache.put(cacheKey, plaintext);
        return plaintext;
    }

    private void auditRead(String field) {
        String tenantCode = TenantContext.getTenantId();
        if (tenantCode == null) {
            // Pas de contexte tenant (test ou demarrage) — audit non applicable
            return;
        }
        try {
            AuditEvent event = new AuditEvent(
                null, tenantCode, "LECTURE_" + field, "field", null,
                "encryption", "SECURITE", true,
                null, null, null, OffsetDateTime.now());
            audit.persist(event, OperationCritique.LECTURE_CHAMP_SENSIBLE);
        } catch (Exception e) {
            // Fail-closed strict (D-P4-11)
            throw new EncryptionUnavailableException(
                "Audit LECTURE_CHAMP_SENSIBLE echoue (fail-closed)", e);
        }
    }

    /** Exception de chiffrement (fail-closed). */
    public static class EncryptionUnavailableException extends RuntimeException {
        public EncryptionUnavailableException(String message) { super(message); }
        public EncryptionUnavailableException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
