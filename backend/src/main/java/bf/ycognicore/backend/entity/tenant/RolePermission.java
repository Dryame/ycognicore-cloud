package bf.ycognicore.backend.entity.tenant;

import bf.ycognicore.backend.entity.tenant.ids.RolePermissionId;
import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Liaison role <-> permission <-> module.
 * Ref. : dictionnaire v1.2 T1
 */
@Entity
@Table(name = "role_permissions")
@IdClass(RolePermissionId.class)
public class RolePermission {

    @Id
    @Column(name = "role_id", nullable = false)
    private UUID roleId;

    @Id
    @Column(name = "permission_id", nullable = false)
    private Integer permissionId;

    @Id
    @Column(name = "module_id", nullable = false)
    private Integer moduleId;

    @Column(name = "accordee_par")
    private UUID accordeePar;

    @Column(name = "date_attribution", nullable = false)
    private OffsetDateTime dateAttribution;

    public RolePermission() {}

    public UUID getRoleId() { return roleId; }
    public void setRoleId(UUID v) { this.roleId = v; }
    public Integer getPermissionId() { return permissionId; }
    public void setPermissionId(Integer v) { this.permissionId = v; }
    public Integer getModuleId() { return moduleId; }
    public void setModuleId(Integer v) { this.moduleId = v; }
    public UUID getAccordeePar() { return accordeePar; }
    public void setAccordeePar(UUID v) { this.accordeePar = v; }
    public OffsetDateTime getDateAttribution() { return dateAttribution; }
    public void setDateAttribution(OffsetDateTime v) { this.dateAttribution = v; }
}
