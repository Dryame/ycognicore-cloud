package bf.ycognicore.backend.entity.tenant;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Définition d'un workflow déclaratif (JSON).
 * Ref : D-P5-5
 */
@Entity
@Table(name = "workflow_definitions")
public class WorkflowDefinition {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, length = 100)
    private String nom;

    @Column(name = "type_evenement", nullable = false, length = 100)
    private String typeEvenement;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private JsonNode conditions;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb", nullable = false)
    private JsonNode actions;

    @Column(nullable = false)
    private boolean actif = true;

    @Column(name = "date_creation", nullable = false)
    private OffsetDateTime dateCreation;

    @Column(name = "date_maj", nullable = false)
    private OffsetDateTime dateMaj;

    public WorkflowDefinition() {}

    @PrePersist
    public void prePersist() {
        dateCreation = OffsetDateTime.now();
        dateMaj = OffsetDateTime.now();
    }

    @PreUpdate
    public void preUpdate() {
        dateMaj = OffsetDateTime.now();
    }

    // --- Getters et Setters ---
    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }
    public String getNom() { return nom; }
    public void setNom(String nom) { this.nom = nom; }
    public String getTypeEvenement() { return typeEvenement; }
    public void setTypeEvenement(String typeEvenement) { this.typeEvenement = typeEvenement; }
    public JsonNode getConditions() { return conditions; }
    public void setConditions(JsonNode conditions) { this.conditions = conditions; }
    public JsonNode getActions() { return actions; }
    public void setActions(JsonNode actions) { this.actions = actions; }
    public boolean isActif() { return actif; }
    public void setActif(boolean actif) { this.actif = actif; }
    public OffsetDateTime getDateCreation() { return dateCreation; }
    public OffsetDateTime getDateMaj() { return dateMaj; }
}
