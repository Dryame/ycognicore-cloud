package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.PaymentTransaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CpPaymentTransactionRepository extends JpaRepository<PaymentTransaction, UUID> {

    Optional<PaymentTransaction> findByReferenceExterne(String referenceExterne);

    List<PaymentTransaction> findByTenantIdOrderByDateInitiationDesc(UUID tenantId);
}
