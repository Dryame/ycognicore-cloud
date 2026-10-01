package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.PasswordHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface PasswordHistoryRepository extends JpaRepository<PasswordHistory, Long> {

    List<PasswordHistory> findTop5ByUserIdOrderByDateChangementDesc(UUID userId);
}
