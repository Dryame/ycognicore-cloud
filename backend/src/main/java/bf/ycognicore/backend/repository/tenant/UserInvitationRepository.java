package bf.ycognicore.backend.repository.tenant;

import bf.ycognicore.backend.entity.tenant.UserInvitation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserInvitationRepository extends JpaRepository<UserInvitation, UUID> {

    Optional<UserInvitation> findByTokenHash(String tokenHash);

    List<UserInvitation> findByEmailAndStatut(String email, String statut);
}
