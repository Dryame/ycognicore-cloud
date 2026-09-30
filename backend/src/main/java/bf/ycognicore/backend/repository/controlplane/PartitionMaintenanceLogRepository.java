package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.PartitionMaintenanceLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface PartitionMaintenanceLogRepository
        extends JpaRepository<PartitionMaintenanceLog, Long> {

    List<PartitionMaintenanceLog> findByTenantIdOrderByExecuteLeDesc(UUID tenantId);

    List<PartitionMaintenanceLog> findTop50ByOrderByExecuteLeDesc();
}
