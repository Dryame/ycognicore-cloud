package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.AuditLog;
import bf.ycognicore.backend.entity.tenant.ids.AuditLogId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface AuditLogRepository extends JpaRepository<AuditLog, AuditLogId> {

    List<AuditLog> findTop100ByUserIdOrderByTimestampDesc(UUID userId);

    List<AuditLog> findTop100ByNiveauOrderByTimestampDesc(String niveau);

    List<AuditLog> findTop100ByModuleIdOrderByTimestampDesc(Integer moduleId);

    /** Dernier hash de la chaîne (non null) — pour AuditChainService. */
    @Query("SELECT a.hashEntree FROM AuditLog a WHERE a.hashEntree IS NOT NULL " +
           "ORDER BY a.id DESC")
    List<String> findLastHashes(org.springframework.data.domain.Pageable pageable);

    /** Entrées chaînées triées par id — pour vérification complète. */
    @Query("SELECT a FROM AuditLog a WHERE a.hashEntree IS NOT NULL ORDER BY a.id ASC")
    List<AuditLog> findAllChained();
}
