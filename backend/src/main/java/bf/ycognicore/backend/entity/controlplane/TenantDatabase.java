package bf.ycognicore.backend.entity.controlplane;

import jakarta.persistence.*;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Reference technique de la base dediee d'un tenant.
 * Ref. : dictionnaire v1.2 G1, NFR-SCAL-02
 */
@Entity
@Table(name = "tenant_databases")
public class TenantDatabase {

    @Id
    @Column(name = "tenant_id", nullable = false, updatable = false)
    private UUID tenantId;

    @Column(name = "db_name", nullable = false, unique = true, length = 100)
    private String dbName;

    @Column(name = "db_host", nullable = false, length = 255)
    private String dbHost;

    @Column(name = "db_port", nullable = false)
    private Integer dbPort = 5432;

    @Column(name = "db_user", nullable = false, length = 100)
    private String dbUser = "ycc_tenant_app";

    @Column(name = "db_secret_ref", length = 255)
    private String dbSecretRef;

    @Column(name = "version_schema", nullable = false, length = 20)
    private String versionSchema = "V1";

    @Column(name = "db_status", nullable = false, length = 20)
    private String dbStatus = "EN_COURS";

    @Column(name = "date_derniere_migration")
    private OffsetDateTime dateDerniereMigration;

    @Column(name = "date_creation", nullable = false)
    private OffsetDateTime dateCreation;

    @Column(name = "date_maj", nullable = false)
    private OffsetDateTime dateMaj;

    public TenantDatabase() {}

    public UUID getTenantId() { return tenantId; }
    public void setTenantId(UUID v) { this.tenantId = v; }
    public String getDbName() { return dbName; }
    public void setDbName(String v) { this.dbName = v; }
    public String getDbHost() { return dbHost; }
    public void setDbHost(String v) { this.dbHost = v; }
    public Integer getDbPort() { return dbPort; }
    public void setDbPort(Integer v) { this.dbPort = v; }
    public String getDbUser() { return dbUser; }
    public void setDbUser(String v) { this.dbUser = v; }
    public String getDbSecretRef() { return dbSecretRef; }
    public void setDbSecretRef(String v) { this.dbSecretRef = v; }
    public String getVersionSchema() { return versionSchema; }
    public void setVersionSchema(String v) { this.versionSchema = v; }
    public String getDbStatus() { return dbStatus; }
    public void setDbStatus(String v) { this.dbStatus = v; }
    public OffsetDateTime getDateDerniereMigration() { return dateDerniereMigration; }
    public void setDateDerniereMigration(OffsetDateTime v) { this.dateDerniereMigration = v; }
    public OffsetDateTime getDateCreation() { return dateCreation; }
    public void setDateCreation(OffsetDateTime v) { this.dateCreation = v; }
    public OffsetDateTime getDateMaj() { return dateMaj; }
    public void setDateMaj(OffsetDateTime v) { this.dateMaj = v; }
}
