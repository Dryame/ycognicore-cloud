package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.tenant.OutboxEvent;
import bf.ycognicore.backend.repository.tenant.OutboxEventRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;
import java.util.UUID;

/**
 * Service utilisé par les modules métier pour publier un événement.
 * Ref : D-P5-2 (Transactional Outbox)
 */
@Service
public class EventPublisherService {

    private final OutboxEventRepository outboxRepository;
    private final ObjectMapper objectMapper;

    public EventPublisherService(OutboxEventRepository outboxRepository, ObjectMapper objectMapper) {
        this.outboxRepository = outboxRepository;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public void publish(String type, String aggregatType, UUID aggregatId, Map<String, Object> payload) {
        try {
            OutboxEvent event = new OutboxEvent();
            event.setType(type);
            event.setAggregatType(aggregatType);
            event.setAggregatId(aggregatId);
            event.setPayload(objectMapper.writeValueAsString(payload));
            event.setStatut("PENDING");
            
            outboxRepository.save(event);
        } catch (Exception e) {
            throw new RuntimeException("Erreur lors de la sérialisation de l'événement", e);
        }
    }
}
