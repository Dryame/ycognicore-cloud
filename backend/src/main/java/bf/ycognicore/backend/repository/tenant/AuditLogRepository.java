package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.AuditLog;
import bf.ycognicore.backend.entity.tenant.ids.AuditLogId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface AuditLogRepository extends JpaRepository<AuditLog, AuditLogId> {

    List<AuditLog> findTop100ByUserIdOrderByTimestampDesc(UUID userId);

    List<AuditLog> findTop100ByNiveauOrderByTimestampDesc(String niveau);

    List<AuditLog> findTop100ByModuleIdOrderByTimestampDesc(Integer moduleId);
}
