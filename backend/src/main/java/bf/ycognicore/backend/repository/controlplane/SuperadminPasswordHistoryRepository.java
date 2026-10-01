package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.SuperadminPasswordHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface SuperadminPasswordHistoryRepository extends JpaRepository<SuperadminPasswordHistory, Long> {

    List<SuperadminPasswordHistory> findTop5BySuperadminIdOrderByDateChangementDesc(UUID superadminId);
}
