package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.UserRole;
import bf.ycognicore.backend.entity.tenant.ids.UserRoleId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface UserRoleRepository extends JpaRepository<UserRole, UserRoleId> {

    List<UserRole> findByUserIdAndStatut(UUID userId, String statut);

    List<UserRole> findByRoleId(UUID roleId);
}
