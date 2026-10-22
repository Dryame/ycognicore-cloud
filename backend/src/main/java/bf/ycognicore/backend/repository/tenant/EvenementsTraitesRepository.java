package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.EvenementsTraites;
import bf.ycognicore.backend.entity.tenant.EvenementsTraitesId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface EvenementsTraitesRepository extends JpaRepository<EvenementsTraites, EvenementsTraitesId> {
    boolean existsByEventIdAndConsommateur(UUID eventId, String consommateur);
}
