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
 * File de jobs asynchrones (NFR-OPS-04).
 * Ref. : dictionnaire v1.2 G7, ADR-001
 */
@Entity
@Table(name = "jobs_async")
public class JobAsync {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "type_job", nullable = false, length = 100)
    private String typeJob;

    @Column(name = "tenant_id")
    private UUID tenantId;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "payload", nullable = false, columnDefinition = "jsonb")
    private JsonNode payload;

    @Column(name = "statut", nullable = false, length = 20)
    private String statut = "EN_ATTENTE";

    @Column(name = "priorite", nullable = false)
    private Short priorite = 5;

    @Column(name = "tentatives", nullable = false)
    private Short tentatives = 0;

    @Column(name = "max_tentatives", nullable = false)
    private Short maxTentatives = 3;

    @Column(name = "next_retry_at")
    private OffsetDateTime nextRetryAt;

    @Column(name = "date_creation", nullable = false)
    private OffsetDateTime dateCreation;

    @Column(name = "date_debut")
    private OffsetDateTime dateDebut;

    @Column(name = "date_fin")
    private OffsetDateTime dateFin;

    @Column(name = "erreur", columnDefinition = "TEXT")
    private String erreur;

    public JobAsync() {}

    public Long getId() { return id; }
    public void setId(Long v) { this.id = v; }
    public String getTypeJob() { return typeJob; }
    public void setTypeJob(String v) { this.typeJob = v; }
    public UUID getTenantId() { return tenantId; }
    public void setTenantId(UUID v) { this.tenantId = v; }
    public JsonNode getPayload() { return payload; }
    public void setPayload(JsonNode v) { this.payload = v; }
    public String getStatut() { return statut; }
    public void setStatut(String v) { this.statut = v; }
    public Short getPriorite() { return priorite; }
    public void setPriorite(Short v) { this.priorite = v; }
    public Short getTentatives() { return tentatives; }
    public void setTentatives(Short v) { this.tentatives = v; }
    public Short getMaxTentatives() { return maxTentatives; }
    public void setMaxTentatives(Short v) { this.maxTentatives = v; }
    public OffsetDateTime getNextRetryAt() { return nextRetryAt; }
    public void setNextRetryAt(OffsetDateTime v) { this.nextRetryAt = v; }
    public OffsetDateTime getDateCreation() { return dateCreation; }
    public void setDateCreation(OffsetDateTime v) { this.dateCreation = v; }
    public OffsetDateTime getDateDebut() { return dateDebut; }
    public void setDateDebut(OffsetDateTime v) { this.dateDebut = v; }
    public OffsetDateTime getDateFin() { return dateFin; }
    public void setDateFin(OffsetDateTime v) { this.dateFin = v; }
    public String getErreur() { return erreur; }
    public void setErreur(String v) { this.erreur = v; }
}
