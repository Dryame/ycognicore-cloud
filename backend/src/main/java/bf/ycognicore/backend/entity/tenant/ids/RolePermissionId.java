package bf.ycognicore.backend.entity.tenant.ids;
import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;
public class RolePermissionId implements Serializable {
    private UUID roleId;
    private Integer permissionId;
    private Integer moduleId;
    public RolePermissionId() {}
    public UUID getRoleId() { return roleId; }
    public void setRoleId(UUID v) { this.roleId = v; }
    public Integer getPermissionId() { return permissionId; }
    public void setPermissionId(Integer v) { this.permissionId = v; }
    public Integer getModuleId() { return moduleId; }
    public void setModuleId(Integer v) { this.moduleId = v; }
    @Override public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof RolePermissionId that)) return false;
        return Objects.equals(roleId, that.roleId) && Objects.equals(permissionId, that.permissionId) && Objects.equals(moduleId, that.moduleId);
    }
    @Override public int hashCode() { return Objects.hash(roleId, permissionId, moduleId); }
}
