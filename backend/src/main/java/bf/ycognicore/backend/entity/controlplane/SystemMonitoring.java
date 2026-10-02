package bf.ycognicore.backend.entity.controlplane;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.JsonNode;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Metriques Monitoring APM (NFR-MON-01, NFR-MON-03).
 * Ref. : dictionnaire v1.2 G7
 */
@Entity
@Table(name = "system_monitoring")
public class SystemMonitoring {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id")
    private UUID tenantId;

    @Column(name = "timestamp", nullable = false)
    private OffsetDateTime timestamp;

    @Column(name = "metrique", nullable = false, length = 100)
    private String metrique;

    @Column(name = "valeur", nullable = false, precision = 20, scale = 6)
    private BigDecimal valeur;

    @Column(name = "unite", length = 20)
    private String unite;

    @Column(name = "niveau", length = 20)
    private String niveau;

    @Column(name = "seuil_alerte", precision = 20, scale = 6)
    private BigDecimal seuilAlerte;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "metadata", columnDefinition = "jsonb")
    private JsonNode metadata;

    public SystemMonitoring() {}

    public Long getId() { return id; }
    public void setId(Long v) { this.id = v; }
    public UUID getTenantId() { return tenantId; }
    public void setTenantId(UUID v) { this.tenantId = v; }
    public OffsetDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(OffsetDateTime v) { this.timestamp = v; }
    public String getMetrique() { return metrique; }
    public void setMetrique(String v) { this.metrique = v; }
    public BigDecimal getValeur() { return valeur; }
    public void setValeur(BigDecimal v) { this.valeur = v; }
    public String getUnite() { return unite; }
    public void setUnite(String v) { this.unite = v; }
    public String getNiveau() { return niveau; }
    public void setNiveau(String v) { this.niveau = v; }
    public BigDecimal getSeuilAlerte() { return seuilAlerte; }
    public void setSeuilAlerte(BigDecimal v) { this.seuilAlerte = v; }
    public JsonNode getMetadata() { return metadata; }
    public void setMetadata(JsonNode v) { this.metadata = v; }
}
