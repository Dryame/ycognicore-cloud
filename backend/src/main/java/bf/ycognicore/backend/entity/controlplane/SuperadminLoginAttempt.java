package bf.ycognicore.backend.entity.controlplane;

import bf.ycognicore.backend.entity.controlplane.ids.SuperadminLoginAttemptId;
import jakarta.persistence.*;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Journal des tentatives de connexion Superadmin (partitionne mensuellement).
 * Ref. : dictionnaire v1.2 G2, ADR-003, NFR-SEC-10
 */
@Entity
@Table(name = "superadmin_login_attempts")
@IdClass(SuperadminLoginAttemptId.class)
public class SuperadminLoginAttempt {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", nullable = false)
    private Long id;

    @Id
    @Column(name = "timestamp", nullable = false)
    private OffsetDateTime timestamp;

    @Column(name = "email", nullable = false, columnDefinition = "citext")
    private String email;

    @Column(name = "superadmin_id")
    private UUID superadminId;

    @Column(name = "succes", nullable = false)
    private boolean succes;

    @Column(name = "ip", nullable = false, columnDefinition = "inet")
    private String ip;

    @Column(name = "user_agent", columnDefinition = "TEXT")
    private String userAgent;

    @Column(name = "raison_echec", length = 50)
    private String raisonEchec;

    public SuperadminLoginAttempt() {}

    public Long getId() { return id; }
    public void setId(Long v) { this.id = v; }
    public OffsetDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(OffsetDateTime v) { this.timestamp = v; }
    public String getEmail() { return email; }
    public void setEmail(String v) { this.email = v; }
    public UUID getSuperadminId() { return superadminId; }
    public void setSuperadminId(UUID v) { this.superadminId = v; }
    public boolean isSucces() { return succes; }
    public void setSucces(boolean v) { this.succes = v; }
    public String getIp() { return ip; }
    public void setIp(String v) { this.ip = v; }
    public String getUserAgent() { return userAgent; }
    public void setUserAgent(String v) { this.userAgent = v; }
    public String getRaisonEchec() { return raisonEchec; }
    public void setRaisonEchec(String v) { this.raisonEchec = v; }
}
