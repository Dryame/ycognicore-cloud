package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.Tenant;
import bf.ycognicore.backend.entity.controlplane.enums.StatutTenant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TenantRepository extends JpaRepository<Tenant, UUID> {

    Optional<Tenant> findByCode(String code);

    Optional<Tenant> findByEmailContact(String emailContact);

    List<Tenant> findByStatut(StatutTenant statut);

    boolean existsByCode(String code);
}
