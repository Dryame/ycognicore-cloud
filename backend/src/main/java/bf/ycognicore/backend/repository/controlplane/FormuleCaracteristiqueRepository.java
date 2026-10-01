package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.FormuleCaracteristique;
import bf.ycognicore.backend.entity.controlplane.enums.FormuleAbonnement;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface FormuleCaracteristiqueRepository extends JpaRepository<FormuleCaracteristique, Integer> {

    List<FormuleCaracteristique> findByFormuleAndActifTrue(FormuleAbonnement formule);

    List<FormuleCaracteristique> findByActifTrue();
}
