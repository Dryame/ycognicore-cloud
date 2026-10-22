package bf.ycognicore.backend.entity.tenant;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

public class EvenementsTraitesId implements Serializable {
    private UUID eventId;
    private String consommateur;

    public EvenementsTraitesId() {}
    public EvenementsTraitesId(UUID eventId, String consommateur) {
        this.eventId = eventId;
        this.consommateur = consommateur;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        EvenementsTraitesId that = (EvenementsTraitesId) o;
        return Objects.equals(eventId, that.eventId) && Objects.equals(consommateur, that.consommateur);
    }

    @Override
    public int hashCode() {
        return Objects.hash(eventId, consommateur);
    }
}
