package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.RolePermission;
import bf.ycognicore.backend.entity.tenant.ids.RolePermissionId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface RolePermissionRepository extends JpaRepository<RolePermission, RolePermissionId> {

    List<RolePermission> findByRoleId(UUID roleId);

    boolean existsByRoleIdAndPermissionIdAndModuleId(UUID roleId, Integer permissionId, Integer moduleId);
}
