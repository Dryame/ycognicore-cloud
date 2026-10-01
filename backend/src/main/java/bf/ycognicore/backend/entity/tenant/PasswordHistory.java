package bf.ycognicore.backend.entity.tenant;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Historique des 5 derniers mots de passe (append-only).
 * Ref. : dictionnaire v1.2 T3, NFR-SEC-09
 */
@Entity
@Table(name = "password_history")
public class PasswordHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "hash", nullable = false, columnDefinition = "TEXT")
    private String hash;

    @Column(name = "date_changement", nullable = false)
    private OffsetDateTime dateChangement;

    @Column(name = "change_par")
    private UUID changePar;

    @Column(name = "motif", length = 50)
    private String motif;

    public PasswordHistory() {}

    public Long getId() { return id; }
    public void setId(Long v) { this.id = v; }
    public UUID getUserId() { return userId; }
    public void setUserId(UUID v) { this.userId = v; }
    public String getHash() { return hash; }
    public void setHash(String v) { this.hash = v; }
    public OffsetDateTime getDateChangement() { return dateChangement; }
    public void setDateChangement(OffsetDateTime v) { this.dateChangement = v; }
    public UUID getChangePar() { return changePar; }
    public void setChangePar(UUID v) { this.changePar = v; }
    public String getMotif() { return motif; }
    public void setMotif(String v) { this.motif = v; }
}
