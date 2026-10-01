package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.WebhookEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface CpWebhookEventRepository extends JpaRepository<WebhookEvent, UUID> {

    Optional<WebhookEvent> findByAggregateurAndEventIdExterne(String aggregateur, String eventIdExterne);
}
