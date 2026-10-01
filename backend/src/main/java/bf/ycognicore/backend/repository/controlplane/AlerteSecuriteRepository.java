package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.AlerteSecurite;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface AlerteSecuriteRepository extends JpaRepository<AlerteSecurite, Long> {

    List<AlerteSecurite> findByTenantIdOrderByDateCreationDesc(UUID tenantId);

    List<AlerteSecurite> findBySeveriteAndStatutOrderByDateCreationDesc(String severite, String statut);
}
