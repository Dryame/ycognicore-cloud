package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.LoginAttempt;
import bf.ycognicore.backend.entity.tenant.ids.LoginAttemptId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface LoginAttemptRepository extends JpaRepository<LoginAttempt, LoginAttemptId> {

    List<LoginAttempt> findTop5ByUserIdOrderByTimestampDesc(UUID userId);

    List<LoginAttempt> findTop5ByEmailOrderByTimestampDesc(String email);
}
