package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.Tiers;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Repository Tiers — recherche par HMAC des champs chiffres.
 * Ref. : P4 L3.2, D-P4-3, D-P4-4, ADR-042.
 */
@Repository
public interface TiersRepository extends JpaRepository<Tiers, UUID> {

    Optional<Tiers> findByIfuHmac(String ifuHmac);

    Optional<Tiers> findByRccmHmac(String rccmHmac);

    List<Tiers> findByTelephoneHmac(String telephoneHmac);

    Optional<Tiers> findByEmailHmac(String emailHmac);

    Optional<Tiers> findByCode(String code);
}
