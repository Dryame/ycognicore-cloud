package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.Module;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface TenantModuleRepository extends JpaRepository<Module, Integer> {

    Optional<Module> findByCode(String code);

    List<Module> findAllByOrderByOrdreAffichageAsc();
}
