package bf.ycognicore.backend.entity.controlplane;

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
 * Alertes de securite (NFR-MON-02, NFR-SEC-28).
 * Ref. : dictionnaire v1.2 G7, ADR-001
 */
@Entity
@Table(name = "alertes_securite")
public class AlerteSecurite {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id")
    private UUID tenantId;

    @Column(name = "type_alerte", nullable = false, length = 50)
    private String typeAlerte;

    @Column(name = "severite", nullable = false, length = 20)
    private String severite;

    @Column(name = "description", nullable = false, columnDefinition = "TEXT")
    private String description;

    @Column(name = "source", length = 100)
    private String source;

    @Column(name = "ip", columnDefinition = "inet")
    private String ip;

    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "statut", nullable = false, length = 20)
    private String statut = "NOUVELLE";

    @Column(name = "date_creation", nullable = false)
    private OffsetDateTime dateCreation;

    @Column(name = "date_resolution")
    private OffsetDateTime dateResolution;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "details", columnDefinition = "jsonb")
    private JsonNode details;

    public AlerteSecurite() {}

    public Long getId() { return id; }
    public void setId(Long v) { this.id = v; }
    public UUID getTenantId() { return tenantId; }
    public void setTenantId(UUID v) { this.tenantId = v; }
    public String getTypeAlerte() { return typeAlerte; }
    public void setTypeAlerte(String v) { this.typeAlerte = v; }
    public String getSeverite() { return severite; }
    public void setSeverite(String v) { this.severite = v; }
    public String getDescription() { return description; }
    public void setDescription(String v) { this.description = v; }
    public String getSource() { return source; }
    public void setSource(String v) { this.source = v; }
    public String getIp() { return ip; }
    public void setIp(String v) { this.ip = v; }
    public UUID getUserId() { return userId; }
    public void setUserId(UUID v) { this.userId = v; }
    public String getStatut() { return statut; }
    public void setStatut(String v) { this.statut = v; }
    public OffsetDateTime getDateCreation() { return dateCreation; }
    public void setDateCreation(OffsetDateTime v) { this.dateCreation = v; }
    public OffsetDateTime getDateResolution() { return dateResolution; }
    public void setDateResolution(OffsetDateTime v) { this.dateResolution = v; }
    public JsonNode getDetails() { return details; }
    public void setDetails(JsonNode v) { this.details = v; }
}
