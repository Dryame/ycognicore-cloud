package bf.ycognicore.backend.entity.tenant;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Représente un événement métier à publier sur RabbitMQ (Pattern Transactional Outbox).
 * Ref : D-P5-2
 */
@Entity
@Table(name = "outbox_events")
public class OutboxEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, length = 100)
    private String type;

    @Column(name = "aggregat_type", nullable = false, length = 100)
    private String aggregatType;

    @Column(name = "aggregat_id", nullable = false)
    private UUID aggregatId;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb", nullable = false)
    private String payload;

    @Column(nullable = false, length = 20)
    private String statut = "PENDING";

    @Column(nullable = false)
    private int tentatives = 0;

    @Column(name = "date_creation", nullable = false)
    private OffsetDateTime dateCreation;

    @Column(name = "date_publication")
    private OffsetDateTime datePublication;

    public OutboxEvent() {}

    @PrePersist
    public void prePersist() {
        if (dateCreation == null) dateCreation = OffsetDateTime.now();
        if (statut == null) statut = "PENDING";
    }

    // --- Getters et Setters ---
    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }
    public String getType() { return type; }
    public void setType(String type) { this.type = type; }
    public String getAggregatType() { return aggregatType; }
    public void setAggregatType(String aggregatType) { this.aggregatType = aggregatType; }
    public UUID getAggregatId() { return aggregatId; }
    public void setAggregatId(UUID aggregatId) { this.aggregatId = aggregatId; }
    public String getPayload() { return payload; }
    public void setPayload(String payload) { this.payload = payload; }
    public String getStatut() { return statut; }
    public void setStatut(String statut) { this.statut = statut; }
    public int getTentatives() { return tentatives; }
    public void setTentatives(int tentatives) { this.tentatives = tentatives; }
    public OffsetDateTime getDateCreation() { return dateCreation; }
    public void setDateCreation(OffsetDateTime dateCreation) { this.dateCreation = dateCreation; }
    public OffsetDateTime getDatePublication() { return datePublication; }
    public void setDatePublication(OffsetDateTime datePublication) { this.datePublication = datePublication; }
}
