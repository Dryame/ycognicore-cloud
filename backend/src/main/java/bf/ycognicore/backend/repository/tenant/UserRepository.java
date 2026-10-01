package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByEmail(String email);

    List<User> findByStatut(String statut);

    List<User> findByTypeUtilisateur(String typeUtilisateur);

    boolean existsByEmail(String email);
}
