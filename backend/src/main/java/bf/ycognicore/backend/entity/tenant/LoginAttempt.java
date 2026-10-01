package bf.ycognicore.backend.entity.tenant;

import bf.ycognicore.backend.entity.tenant.ids.LoginAttemptId;
import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Tentatives de connexion (verrouillage auto apres 5 echecs).
 * Ref. : dictionnaire v1.2 T3, ADR-003, NFR-SEC-10
 */
@Entity
@Table(name = "login_attempts")
@IdClass(LoginAttemptId.class)
public class LoginAttempt {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", nullable = false)
    private Long id;

    @Id
    @Column(name = "timestamp", nullable = false)
    private OffsetDateTime timestamp;

    @Column(name = "email", nullable = false, columnDefinition = "citext")
    private String email;

    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "succes", nullable = false)
    private boolean succes;

    @Column(name = "ip", nullable = false, columnDefinition = "inet")
    private String ip;

    @Column(name = "user_agent", columnDefinition = "TEXT")
    private String userAgent;

    @Column(name = "raison_echec", length = 50)
    private String raisonEchec;

    @Column(name = "pays", length = 100)
    private String pays;

    public LoginAttempt() {}

    public Long getId() { return id; }
    public void setId(Long v) { this.id = v; }
    public OffsetDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(OffsetDateTime v) { this.timestamp = v; }
    public String getEmail() { return email; }
    public void setEmail(String v) { this.email = v; }
    public UUID getUserId() { return userId; }
    public void setUserId(UUID v) { this.userId = v; }
    public boolean isSucces() { return succes; }
    public void setSucces(boolean v) { this.succes = v; }
    public String getIp() { return ip; }
    public void setIp(String v) { this.ip = v; }
    public String getUserAgent() { return userAgent; }
    public void setUserAgent(String v) { this.userAgent = v; }
    public String getRaisonEchec() { return raisonEchec; }
    public void setRaisonEchec(String v) { this.raisonEchec = v; }
    public String getPays() { return pays; }
    public void setPays(String v) { this.pays = v; }
}
