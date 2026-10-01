package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.KycDocument;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface KycDocumentRepository extends JpaRepository<KycDocument, UUID> {

    List<KycDocument> findByTenantId(UUID tenantId);

    List<KycDocument> findByStatutVerification(String statutVerification);
}
