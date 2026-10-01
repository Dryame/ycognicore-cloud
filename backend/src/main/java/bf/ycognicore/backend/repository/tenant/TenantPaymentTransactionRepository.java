package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.PaymentTransaction;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface TenantPaymentTransactionRepository extends JpaRepository<PaymentTransaction, UUID> {

    Optional<PaymentTransaction> findByReferenceExterne(String referenceExterne);
}
