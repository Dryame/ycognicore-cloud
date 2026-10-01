package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.SuperadminSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SuperadminSessionRepository extends JpaRepository<SuperadminSession, UUID> {

    Optional<SuperadminSession> findByTokenHash(String tokenHash);

    List<SuperadminSession> findBySuperadminIdAndDateFermetureIsNull(UUID superadminId);
}
