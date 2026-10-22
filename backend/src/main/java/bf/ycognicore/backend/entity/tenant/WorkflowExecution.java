package bf.ycognicore.backend.entity.tenant;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Journal d'exécution d'un workflow.
 * Ref : D-P5-6
 */
@Entity
@Table(name = "workflow_executions")
public class WorkflowExecution {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "workflow_id", nullable = false)
    private WorkflowDefinition workflow;

    @Column(name = "event_id", nullable = false)
    private UUID eventId;

    @Column(nullable = false, length = 20)
    private String statut;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private JsonNode journal;

    @Column(name = "date_execution", nullable = false)
    private OffsetDateTime dateExecution;

    public WorkflowExecution() {}

    @PrePersist
    public void prePersist() {
        if (dateExecution == null) dateExecution = OffsetDateTime.now();
    }

    // --- Getters et Setters ---
    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }
    public WorkflowDefinition getWorkflow() { return workflow; }
    public void setWorkflow(WorkflowDefinition workflow) { this.workflow = workflow; }
    public UUID getEventId() { return eventId; }
    public void setEventId(UUID eventId) { this.eventId = eventId; }
    public String getStatut() { return statut; }
    public void setStatut(String statut) { this.statut = statut; }
    public JsonNode getJournal() { return journal; }
    public void setJournal(JsonNode journal) { this.journal = journal; }
    public OffsetDateTime getDateExecution() { return dateExecution; }
    public void setDateExecution(OffsetDateTime dateExecution) { this.dateExecution = dateExecution; }
}
