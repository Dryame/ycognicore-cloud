package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.SystemMonitoring;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface SystemMonitoringRepository extends JpaRepository<SystemMonitoring, Long> {

    List<SystemMonitoring> findTop100ByMetriqueOrderByTimestampDesc(String metrique);

    List<SystemMonitoring> findTop100ByTenantIdOrderByTimestampDesc(UUID tenantId);
}
