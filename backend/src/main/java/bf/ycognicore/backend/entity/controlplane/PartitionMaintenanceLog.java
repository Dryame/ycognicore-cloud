package bf.ycognicore.backend.entity.controlplane;

import jakarta.persistence.*;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "partition_maintenance_log")
public class PartitionMaintenanceLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id")
    private UUID tenantId;

    @Column(name = "db_name", nullable = false, length = 100)
    private String dbName;

    @Column(name = "table_cible", nullable = false, length = 50)
    private String tableCible;

    @Column(name = "partition_creee", nullable = false, length = 100)
    private String partitionCreee;

    @Column(name = "mois_cible", nullable = false)
    private LocalDate moisCible;

    @Column(name = "statut", nullable = false, length = 20)
    private String statut;

    @Column(name = "erreur", columnDefinition = "TEXT")
    private String erreur;

    @Column(name = "execute_le", nullable = false)
    private OffsetDateTime executeLe;

    @Column(name = "execute_par", nullable = false, length = 50)
    private String executePar = "SCHEDULER";

    public PartitionMaintenanceLog() {}

    public PartitionMaintenanceLog(UUID tenantId, String dbName, String tableCible,
                                    String partitionCreee, LocalDate moisCible,
                                    String statut, String executePar) {
        this.tenantId = tenantId;
        this.dbName = dbName;
        this.tableCible = tableCible;
        this.partitionCreee = partitionCreee;
        this.moisCible = moisCible;
        this.statut = statut;
        this.executePar = executePar;
        this.executeLe = OffsetDateTime.now();
    }

    public Long getId() { return id; }
    public UUID getTenantId() { return tenantId; }
    public String getDbName() { return dbName; }
    public String getTableCible() { return tableCible; }
    public String getPartitionCreee() { return partitionCreee; }
    public LocalDate getMoisCible() { return moisCible; }
    public String getStatut() { return statut; }
    public String getErreur() { return erreur; }
    public OffsetDateTime getExecuteLe() { return executeLe; }
    public String getExecutePar() { return executePar; }

    public void setErreur(String erreur) { this.erreur = erreur; }
    public void setStatut(String statut) { this.statut = statut; }
}
