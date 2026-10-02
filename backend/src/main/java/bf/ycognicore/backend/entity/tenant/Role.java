package bf.ycognicore.backend.entity.tenant;

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
 * Roles utilisateur (preconfigure ou sur mesure, NFR-SEC-13).
 * Ref. : dictionnaire v1.2 T1
 */
@Entity
@Table(name = "roles")
public class Role {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "nom", nullable = false, unique = true, length = 100)
    private String nom;

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    @Column(name = "est_systeme", nullable = false)
    private boolean estSysteme = false;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "scope", columnDefinition = "jsonb")
    private JsonNode scope;

    @Column(name = "statut", nullable = false, length = 20)
    private String statut = "ACTIF";

    @Column(name = "created_by")
    private UUID createdBy;

    @Column(name = "date_creation", nullable = false)
    private OffsetDateTime dateCreation;

    public Role() {}

    public UUID getId() { return id; }
    public void setId(UUID v) { this.id = v; }
    public String getNom() { return nom; }
    public void setNom(String v) { this.nom = v; }
    public String getDescription() { return description; }
    public void setDescription(String v) { this.description = v; }
    public boolean isEstSysteme() { return estSysteme; }
    public void setEstSysteme(boolean v) { this.estSysteme = v; }
    public JsonNode getScope() { return scope; }
    public void setScope(JsonNode v) { this.scope = v; }
    public String getStatut() { return statut; }
    public void setStatut(String v) { this.statut = v; }
    public UUID getCreatedBy() { return createdBy; }
    public void setCreatedBy(UUID v) { this.createdBy = v; }
    public OffsetDateTime getDateCreation() { return dateCreation; }
    public void setDateCreation(OffsetDateTime v) { this.dateCreation = v; }
}
