package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface RoleRepository extends JpaRepository<Role, UUID> {

    Optional<Role> findByNom(String nom);

    List<Role> findByEstSystemeTrue();

    List<Role> findByStatut(String statut);
}
