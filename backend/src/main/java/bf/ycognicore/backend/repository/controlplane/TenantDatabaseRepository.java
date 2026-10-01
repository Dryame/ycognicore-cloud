package bf.ycognicore.backend.repository.controlplane;

import bf.ycognicore.backend.entity.controlplane.TenantDatabase;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TenantDatabaseRepository extends JpaRepository<TenantDatabase, UUID> {

    Optional<TenantDatabase> findByDbName(String dbName);

    List<TenantDatabase> findByDbStatus(String dbStatus);

    boolean existsByDbName(String dbName);
}
