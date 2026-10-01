package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.SubscriptionInvoice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface SubscriptionInvoiceRepository extends JpaRepository<SubscriptionInvoice, UUID> {

    Optional<SubscriptionInvoice> findByNumeroFacture(String numeroFacture);

    List<SubscriptionInvoice> findByTenantIdOrderByDateEmissionDesc(UUID tenantId);

    List<SubscriptionInvoice> findByStatut(String statut);
}
