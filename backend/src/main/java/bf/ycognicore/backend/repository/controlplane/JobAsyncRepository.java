package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.JobAsync;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;

@Repository
public interface JobAsyncRepository extends JpaRepository<JobAsync, Long> {

    List<JobAsync> findByStatutOrderByPrioriteAscDateCreationAsc(String statut);

    List<JobAsync> findByStatutAndNextRetryAtBefore(String statut, OffsetDateTime at);
}
