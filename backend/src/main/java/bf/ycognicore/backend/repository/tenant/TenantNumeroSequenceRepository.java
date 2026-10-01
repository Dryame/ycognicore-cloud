package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.NumeroSequence;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface TenantNumeroSequenceRepository extends JpaRepository<NumeroSequence, Integer> {

    Optional<NumeroSequence> findByTypeDocumentAndAnnee(String typeDocument, Integer annee);
}
