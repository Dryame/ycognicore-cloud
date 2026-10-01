package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.WebhookEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface TenantWebhookEventRepository extends JpaRepository<WebhookEvent, UUID> {

    Optional<WebhookEvent> findByAggregateurAndEventIdExterne(String aggregateur, String eventIdExterne);
}
