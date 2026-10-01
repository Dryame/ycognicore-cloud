package bf.ycognicore.backend.entity.tenant;

import bf.ycognicore.backend.entity.tenant.ids.UserRoleId;
import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Liaison user <-> role (statut, fin de validite).
 * Ref. : dictionnaire v1.2 T2, ADR-001
 */
@Entity
@Table(name = "user_roles")
@IdClass(UserRoleId.class)
public class UserRole {

    @Id
    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Id
    @Column(name = "role_id", nullable = false)
    private UUID roleId;

    @Column(name = "date_attribution", nullable = false)
    private OffsetDateTime dateAttribution;

    @Column(name = "date_fin")
    private OffsetDateTime dateFin;

    @Column(name = "statut", nullable = false, length = 20)
    private String statut = "ACTIF";

    @Column(name = "motif", columnDefinition = "TEXT")
    private String motif;

    @Column(name = "attribue_par")
    private UUID attribuePar;

    public UserRole() {}

    public UUID getUserId() { return userId; }
    public void setUserId(UUID v) { this.userId = v; }
    public UUID getRoleId() { return roleId; }
    public void setRoleId(UUID v) { this.roleId = v; }
    public OffsetDateTime getDateAttribution() { return dateAttribution; }
    public void setDateAttribution(OffsetDateTime v) { this.dateAttribution = v; }
    public OffsetDateTime getDateFin() { return dateFin; }
    public void setDateFin(OffsetDateTime v) { this.dateFin = v; }
    public String getStatut() { return statut; }
    public void setStatut(String v) { this.statut = v; }
    public String getMotif() { return motif; }
    public void setMotif(String v) { this.motif = v; }
    public UUID getAttribuePar() { return attribuePar; }
    public void setAttribuePar(UUID v) { this.attribuePar = v; }
}
