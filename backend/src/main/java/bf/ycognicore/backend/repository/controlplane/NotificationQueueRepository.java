package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.NotificationQueue;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;

@Repository
public interface NotificationQueueRepository extends JpaRepository<NotificationQueue, Long> {

    List<NotificationQueue> findByStatut(String statut);

    List<NotificationQueue> findByStatutAndNextRetryAtBefore(String statut, OffsetDateTime at);
}
