package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.ClesTenant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Acces aux cles de chiffrement (control plane).
 * Ref. : P4 L2, D-P4-1, D-P4-4.
 */
@Repository
public interface ClesTenantRepository extends JpaRepository<ClesTenant, UUID> {

    /**
     * Cle active pour un tenant et un type donne.
     * L'index uq_cles_tenant_active garantit qu'il y en a 0 ou 1.
     */
    Optional<ClesTenant> findFirstByTenantIdAndTypeCleAndStatut(
        UUID tenantId,
        ClesTenant.TypeCle typeCle,
        ClesTenant.StatutCle statut
    );

    /** Toutes les cles d'un tenant, triees par version decroissante. */
    List<ClesTenant> findByTenantIdOrderByVersionDesc(UUID tenantId);

    /** Toutes les cles d'un tenant pour un type donne. */
    List<ClesTenant> findByTenantIdAndTypeCleOrderByVersionDesc(
        UUID tenantId,
        ClesTenant.TypeCle typeCle
    );

    /** Nombre de cles actives pour un tenant et un type (max 1 par index). */
    long countByTenantIdAndTypeCleAndStatut(
        UUID tenantId,
        ClesTenant.TypeCle typeCle,
        ClesTenant.StatutCle statut
    );
    java.util.Optional<ClesTenant> findByTenantIdAndTypeCleAndVersion(java.util.UUID tenantId, ClesTenant.TypeCle typeCle, int version);
}
