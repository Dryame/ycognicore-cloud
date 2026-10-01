package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.SuperadminAuditLog;
import bf.ycognicore.backend.entity.controlplane.ids.SuperadminAuditLogId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface SuperadminAuditLogRepository
        extends JpaRepository<SuperadminAuditLog, SuperadminAuditLogId> {

    List<SuperadminAuditLog> findTop100BySuperadminIdOrderByTimestampDesc(UUID superadminId);

    List<SuperadminAuditLog> findTop100ByNiveauOrderByTimestampDesc(String niveau);
}
