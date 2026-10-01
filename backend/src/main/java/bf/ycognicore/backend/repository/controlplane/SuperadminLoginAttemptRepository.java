package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.SuperadminLoginAttempt;
import bf.ycognicore.backend.entity.controlplane.ids.SuperadminLoginAttemptId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface SuperadminLoginAttemptRepository
        extends JpaRepository<SuperadminLoginAttempt, SuperadminLoginAttemptId> {

    List<SuperadminLoginAttempt> findTop5BySuperadminIdOrderByTimestampDesc(UUID superadminId);

    List<SuperadminLoginAttempt> findTop5ByEmailOrderByTimestampDesc(String email);
}
