package bf.ycognicore.backend.entity.tenant;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Invitations externes (clients, fournisseurs, partenaires).
 * Ref. : dictionnaire v1.2 T2, NFR-SEC-05
 */
@Entity
@Table(name = "user_invitations")
public class UserInvitation {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "email", nullable = false, columnDefinition = "citext")
    private String email;

    @Column(name = "token_hash", nullable = false, unique = true, columnDefinition = "TEXT")
    private String tokenHash;

    @Column(name = "role_id")
    private UUID roleId;

    @Column(name = "invite_par", nullable = false)
    private UUID invitePar;

    @Column(name = "date_expiration", nullable = false)
    private OffsetDateTime dateExpiration;

    @Column(name = "statut", nullable = false, length = 20)
    private String statut = "EN_ATTENTE";

    @Column(name = "date_creation", nullable = false)
    private OffsetDateTime dateCreation;

    @Column(name = "date_acceptation")
    private OffsetDateTime dateAcceptation;

    public UserInvitation() {}

    public UUID getId() { return id; }
    public void setId(UUID v) { this.id = v; }
    public String getEmail() { return email; }
    public void setEmail(String v) { this.email = v; }
    public String getTokenHash() { return tokenHash; }
    public void setTokenHash(String v) { this.tokenHash = v; }
    public UUID getRoleId() { return roleId; }
    public void setRoleId(UUID v) { this.roleId = v; }
    public UUID getInvitePar() { return invitePar; }
    public void setInvitePar(UUID v) { this.invitePar = v; }
    public OffsetDateTime getDateExpiration() { return dateExpiration; }
    public void setDateExpiration(OffsetDateTime v) { this.dateExpiration = v; }
    public String getStatut() { return statut; }
    public void setStatut(String v) { this.statut = v; }
    public OffsetDateTime getDateCreation() { return dateCreation; }
    public void setDateCreation(OffsetDateTime v) { this.dateCreation = v; }
    public OffsetDateTime getDateAcceptation() { return dateAcceptation; }
    public void setDateAcceptation(OffsetDateTime v) { this.dateAcceptation = v; }
}
