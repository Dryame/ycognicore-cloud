package bf.ycognicore.backend.controller;

import bf.ycognicore.backend.entity.controlplane.ClesTenant;
import bf.ycognicore.backend.repository.controlplane.ClesTenantRepository;
import bf.ycognicore.backend.service.EncryptionKeyRotationService;
import bf.ycognicore.backend.service.EncryptionMigrationService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * API d'administration pour la gestion du chiffrement (Phase 4).
 * Réservé aux Superadmins.
 */
@RestController
@RequestMapping("/api/admin/encryption")
@PreAuthorize("hasRole('SUPERADMIN')")
public class EncryptionController {

    private static final Logger log = LoggerFactory.getLogger(EncryptionController.class);

    private final EncryptionKeyRotationService rotationService;
    private final EncryptionMigrationService migrationService;
    private final ClesTenantRepository clesRepository;

    public EncryptionController(EncryptionKeyRotationService rotationService,
                                EncryptionMigrationService migrationService,
                                ClesTenantRepository clesRepository) {
        this.rotationService = rotationService;
        this.migrationService = migrationService;
        this.clesRepository = clesRepository;
    }

    /**
     * Déclenche la rotation manuelle d'une clé (DATA ou HMAC) pour un tenant.
     * L'ancienne clé passe en DEPRECATED (double lecture active).
     */
    @PostMapping("/rotate/{tenantId}")
    public ResponseEntity<Map<String, Object>> rotate(
            @PathVariable UUID tenantId,
            @RequestParam(defaultValue = "DATA") String typeCle) {
        
        ClesTenant.TypeCle type = ClesTenant.TypeCle.valueOf(typeCle.toUpperCase());
        log.info("Demande de rotation manuelle pour tenant={} type={}", tenantId, type);
        
        ClesTenant newKey = rotationService.rotate(tenantId, type);
        
        return ResponseEntity.ok(Map.of(
                "status", "ROTATED",
                "tenantId", tenantId,
                "typeCle", type,
                "newVersion", newKey.getVersion(),
                "message", "Rotation effectuée. L'ancienne clé est DEPRECATED. Lancez /reencrypt pour finaliser."
        ));
    }

    /**
     * Rechiffre toutes les données avec la nouvelle clé ACTIVE (batch progressif par lots de 1000).
     */
    @PostMapping("/reencrypt/{tenantId}")
    public ResponseEntity<Map<String, Object>> reencrypt(@PathVariable UUID tenantId) {
        log.info("Démarrage du batch de rechiffrement pour tenant={}", tenantId);
        
        int countTiers = migrationService.reencryptTiers(tenantId);
        int countUsers = migrationService.reencryptUsers(tenantId);
        
        return ResponseEntity.ok(Map.of(
                "status", "REENCRYPTED",
                "tenantId", tenantId,
                "tiersProcessed", countTiers,
                "usersProcessed", countUsers
        ));
    }

    /**
     * Finalise la rotation : passe les anciennes clés de DEPRECATED à REVOKED.
     * À appeler UNIQUEMENT après la fin du /reencrypt.
     */
    @PostMapping("/finalize/{tenantId}")
    public ResponseEntity<Map<String, Object>> finalizeRotation(
            @PathVariable UUID tenantId,
            @RequestParam(defaultValue = "DATA") String typeCle) {
        
        ClesTenant.TypeCle type = ClesTenant.TypeCle.valueOf(typeCle.toUpperCase());
        log.info("Clôture de rotation pour tenant={} type={}", tenantId, type);
        
        rotationService.finalizeRotation(tenantId, type);
        
        return ResponseEntity.ok(Map.of(
                "status", "FINALIZED",
                "tenantId", tenantId,
                "typeCle", type,
                "message", "Les anciennes clés sont désormais REVOKED."
        ));
    }

    /**
     * Affiche l'état des clés pour un tenant.
     */
    @GetMapping("/status/{tenantId}")
    public ResponseEntity<List<ClesTenant>> status(@PathVariable UUID tenantId) {
        List<ClesTenant> cles = clesRepository.findByTenantIdOrderByVersionDesc(tenantId);
        // On masque les clés chiffrées pour la sécurité de l'API
        cles.forEach(c -> c.setCleWrapped("[MASQUE]"));
        return ResponseEntity.ok(cles);
    }
}
