package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.NumeroSequence;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface CpNumeroSequenceRepository extends JpaRepository<NumeroSequence, Integer> {

    Optional<NumeroSequence> findByTypeDocumentAndAnnee(String typeDocument, Integer annee);
}
