package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.WorkflowDefinition;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface WorkflowDefinitionRepository extends JpaRepository<WorkflowDefinition, UUID> {
    List<WorkflowDefinition> findByTypeEvenementAndActifTrue(String typeEvenement);
}
