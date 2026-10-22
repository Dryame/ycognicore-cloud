package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.OutboxEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface OutboxEventRepository extends JpaRepository<OutboxEvent, UUID> {

    /**
     * Récupère les événements en attente, triés par date de création.
     * Limité par une pagination pour éviter de surcharger la mémoire.
     */
    List<OutboxEvent> findByStatutOrderByDateCreationAsc(String statut, org.springframework.data.domain.Pageable pageable);
}
