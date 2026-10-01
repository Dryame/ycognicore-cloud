package bf.ycognicore.backend.entity.controlplane;

import jakarta.persistence.*;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Historique mots de passe Superadmin (append-only, NFR-SEC-09).
 * Ref. : dictionnaire v1.2 G2, ADR-001
 */
@Entity
@Table(name = "superadmin_password_history")
public class SuperadminPasswordHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "superadmin_id", nullable = false)
    private UUID superadminId;

    @Column(name = "hash", nullable = false, columnDefinition = "TEXT")
    private String hash;

    @Column(name = "date_changement", nullable = false)
    private OffsetDateTime dateChangement;

    @Column(name = "change_par")
    private UUID changePar;

    public SuperadminPasswordHistory() {}

    public Long getId() { return id; }
    public void setId(Long v) { this.id = v; }
    public UUID getSuperadminId() { return superadminId; }
    public void setSuperadminId(UUID v) { this.superadminId = v; }
    public String getHash() { return hash; }
    public void setHash(String v) { this.hash = v; }
    public OffsetDateTime getDateChangement() { return dateChangement; }
    public void setDateChangement(OffsetDateTime v) { this.dateChangement = v; }
    public UUID getChangePar() { return changePar; }
    public void setChangePar(UUID v) { this.changePar = v; }
}
