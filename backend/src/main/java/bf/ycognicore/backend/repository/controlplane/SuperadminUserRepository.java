package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.SuperadminUser;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface SuperadminUserRepository extends JpaRepository<SuperadminUser, UUID> {

    Optional<SuperadminUser> findByEmail(String email);

    boolean existsByEmail(String email);
}
