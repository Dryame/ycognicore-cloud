package bf.ycognicore.backend.entity.tenant.ids;
import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;
public class UserRoleId implements Serializable {
    private UUID userId;
    private UUID roleId;
    public UserRoleId() {}
    public UUID getUserId() { return userId; }
    public void setUserId(UUID v) { this.userId = v; }
    public UUID getRoleId() { return roleId; }
    public void setRoleId(UUID v) { this.roleId = v; }
    @Override public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof UserRoleId that)) return false;
        return Objects.equals(userId, that.userId) && Objects.equals(roleId, that.roleId);
    }
    @Override public int hashCode() { return Objects.hash(userId, roleId); }
}
