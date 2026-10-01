package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.FormuleModule;
import bf.ycognicore.backend.entity.controlplane.ids.FormuleModuleId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface FormuleModuleRepository extends JpaRepository<FormuleModule, FormuleModuleId> {

    List<FormuleModule> findByFormuleCaracteristiqueId(Integer formuleId);
}
