package bf.ycognicore.backend.entity.tenant;

import bf.ycognicore.backend.entity.tenant.ids.AuditLogId;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.JsonNode;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Journal d'audit (partitionne, append-only).
 * Ref. : dictionnaire v1.2 T3, NFR-SEC-16, NFR-CONF-04
 */
@Entity
@Table(name = "audit_log")
@IdClass(AuditLogId.class)
public class AuditLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", nullable = false)
    private Long id;

    @Id
    @Column(name = "timestamp", nullable = false)
    private OffsetDateTime timestamp;

    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "session_id")
    private UUID sessionId;

    @Column(name = "module_id")
    private Integer moduleId;

    @Column(name = "action", nullable = false, length = 100)
    private String action;

    @Column(name = "entite", nullable = false, length = 100)
    private String entite;

    @Column(name = "entite_id")
    private UUID entiteId;

    @Column(name = "ip", nullable = false, columnDefinition = "inet")
    private String ip;

    @Column(name = "user_agent", columnDefinition = "TEXT")
    private String userAgent;

    @Column(name = "niveau", nullable = false, length = 20)
    private String niveau = "INFO";

    @Column(name = "succes", nullable = false)
    private boolean succes = true;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "avant", columnDefinition = "jsonb")
    private JsonNode avant;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "apres", columnDefinition = "jsonb")
    private JsonNode apres;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "details", columnDefinition = "jsonb")
    private JsonNode details;

    public AuditLog() {}

    public Long getId() { return id; }
    public void setId(Long v) { this.id = v; }
    public OffsetDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(OffsetDateTime v) { this.timestamp = v; }
    public UUID getUserId() { return userId; }
    public void setUserId(UUID v) { this.userId = v; }
    public UUID getSessionId() { return sessionId; }
    public void setSessionId(UUID v) { this.sessionId = v; }
    public Integer getModuleId() { return moduleId; }
    public void setModuleId(Integer v) { this.moduleId = v; }
    public String getAction() { return action; }
    public void setAction(String v) { this.action = v; }
    public String getEntite() { return entite; }
    public void setEntite(String v) { this.entite = v; }
    public UUID getEntiteId() { return entiteId; }
    public void setEntiteId(UUID v) { this.entiteId = v; }
    public String getIp() { return ip; }
    public void setIp(String v) { this.ip = v; }
    public String getUserAgent() { return userAgent; }
    public void setUserAgent(String v) { this.userAgent = v; }
    public String getNiveau() { return niveau; }
    public void setNiveau(String v) { this.niveau = v; }
    public boolean isSucces() { return succes; }
    public void setSucces(boolean v) { this.succes = v; }
    public JsonNode getAvant() { return avant; }
    public void setAvant(JsonNode v) { this.avant = v; }
    public JsonNode getApres() { return apres; }
    public void setApres(JsonNode v) { this.apres = v; }
    public JsonNode getDetails() { return details; }
    public void setDetails(JsonNode v) { this.details = v; }
}
