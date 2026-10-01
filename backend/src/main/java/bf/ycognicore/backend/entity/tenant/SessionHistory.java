package bf.ycognicore.backend.entity.tenant;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Journal des sessions (audit).
 * Ref. : dictionnaire v1.2 T3, NFR-SEC-11, NFR-SEC-19
 */
@Entity
@Table(name = "sessions_history")
public class SessionHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "token_hash", nullable = false, columnDefinition = "TEXT")
    private String tokenHash;

    @Column(name = "refresh_token_hash", columnDefinition = "TEXT")
    private String refreshTokenHash;

    @Column(name = "mfa_verifie", nullable = false)
    private boolean mfaVerifie = false;

    @Column(name = "ip", nullable = false, columnDefinition = "inet")
    private String ip;

    @Column(name = "user_agent", columnDefinition = "TEXT")
    private String userAgent;

    @Column(name = "device_id", length = 255)
    private String deviceId;

    @Column(name = "device_name", length = 100)
    private String deviceName;

    @Column(name = "date_ouverture", nullable = false)
    private OffsetDateTime dateOuverture;

    @Column(name = "date_fermeture")
    private OffsetDateTime dateFermeture;

    @Column(name = "motif_fermeture", length = 30)
    private String motifFermeture;

    public SessionHistory() {}

    public UUID getId() { return id; }
    public void setId(UUID v) { this.id = v; }
    public UUID getUserId() { return userId; }
    public void setUserId(UUID v) { this.userId = v; }
    public String getTokenHash() { return tokenHash; }
    public void setTokenHash(String v) { this.tokenHash = v; }
    public String getRefreshTokenHash() { return refreshTokenHash; }
    public void setRefreshTokenHash(String v) { this.refreshTokenHash = v; }
    public boolean isMfaVerifie() { return mfaVerifie; }
    public void setMfaVerifie(boolean v) { this.mfaVerifie = v; }
    public String getIp() { return ip; }
    public void setIp(String v) { this.ip = v; }
    public String getUserAgent() { return userAgent; }
    public void setUserAgent(String v) { this.userAgent = v; }
    public String getDeviceId() { return deviceId; }
    public void setDeviceId(String v) { this.deviceId = v; }
    public String getDeviceName() { return deviceName; }
    public void setDeviceName(String v) { this.deviceName = v; }
    public OffsetDateTime getDateOuverture() { return dateOuverture; }
    public void setDateOuverture(OffsetDateTime v) { this.dateOuverture = v; }
    public OffsetDateTime getDateFermeture() { return dateFermeture; }
    public void setDateFermeture(OffsetDateTime v) { this.dateFermeture = v; }
    public String getMotifFermeture() { return motifFermeture; }
    public void setMotifFermeture(String v) { this.motifFermeture = v; }
}
