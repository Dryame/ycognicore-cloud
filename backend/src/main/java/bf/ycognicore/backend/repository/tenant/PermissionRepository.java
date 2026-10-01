package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.Permission;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface PermissionRepository extends JpaRepository<Permission, Integer> {

    Optional<Permission> findByCode(String code);
}
