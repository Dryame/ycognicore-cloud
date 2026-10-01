package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.Module;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CpModuleRepository extends JpaRepository<Module, Integer> {

    Optional<Module> findByCode(String code);

    List<Module> findAllByOrderByOrdreAffichageAsc();
}
