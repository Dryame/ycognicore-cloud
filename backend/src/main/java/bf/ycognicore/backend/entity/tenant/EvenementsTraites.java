package bf.ycognicore.backend.entity.tenant;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Registre des événements déjà traités par un consommateur donné.
 * Ref : D-P5-4
 */
@Entity
@Table(name = "evenements_traites")
@IdClass(EvenementsTraitesId.class)
public class EvenementsTraites {

    @Id
    @Column(name = "event_id")
    private UUID eventId;

    @Id
    @Column(length = 100)
    private String consommateur;

    @Column(name = "date_traitement", nullable = false)
    private OffsetDateTime dateTraitement;

    public EvenementsTraites() {}

    public EvenementsTraites(UUID eventId, String consommateur) {
        this.eventId = eventId;
        this.consommateur = consommateur;
        this.dateTraitement = OffsetDateTime.now();
    }

    public UUID getEventId() { return eventId; }
    public void setEventId(UUID eventId) { this.eventId = eventId; }
    public String getConsommateur() { return consommateur; }
    public void setConsommateur(String consommateur) { this.consommateur = consommateur; }
    public OffsetDateTime getDateTraitement() { return dateTraitement; }
    public void setDateTraitement(OffsetDateTime dateTraitement) { this.dateTraitement = dateTraitement; }
}
