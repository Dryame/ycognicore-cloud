package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.SessionHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SessionHistoryRepository extends JpaRepository<SessionHistory, UUID> {

    Optional<SessionHistory> findByTokenHash(String tokenHash);

    List<SessionHistory> findByUserIdAndDateFermetureIsNull(UUID userId);
}
