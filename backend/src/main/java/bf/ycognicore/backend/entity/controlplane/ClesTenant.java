package bf.ycognicore.backend.entity.controlplane;

import jakarta.persistence.*;
import org.hibernate.annotations.UuidGenerator;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Cle de chiffrement par entreprise (control plane).
 * Une cle ACTIVE par (tenant_id, type_cle). Anciennes versions DEPRECATED.
 * Ref. : P4 L1 (V9), D-P4-1, D-P4-4, ADR-040.
 */
@Entity
@Table(name = "cles_tenant")
public class ClesTenant {

    @Id
    @UuidGenerator
    @Column(name = "id", columnDefinition = "uuid", updatable = false, nullable = false)
    private UUID id;

    @Column(name = "tenant_id", nullable = false, columnDefinition = "uuid")
    private UUID tenantId;

    @Column(name = "version", nullable = false)
    private int version;

    @Column(name = "cle_wrapped", nullable = false, columnDefinition = "text")
    private String cleWrapped;

    @Enumerated(EnumType.STRING)
    @Column(name = "type_cle", nullable = false, length = 10)
    private TypeCle typeCle;

    @Enumerated(EnumType.STRING)
    @Column(name = "statut", nullable = false, length = 20)
    private StatutCle statut = StatutCle.ACTIVE;

    @Column(name = "date_creation", nullable = false)
    private OffsetDateTime dateCreation;

    @Column(name = "date_rotation_prevue")
    private OffsetDateTime dateRotationPrevue;

    @Column(name = "date_rotation_effectuee")
    private OffsetDateTime dateRotationEffectuee;

    @Column(name = "created_by", columnDefinition = "uuid")
    private UUID createdBy;

    @PrePersist
    void onCreate() {
        if (dateCreation == null) dateCreation = OffsetDateTime.now();
    }

    // ----- Getters/Setters -----

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getTenantId() { return tenantId; }
    public void setTenantId(UUID tenantId) { this.tenantId = tenantId; }

    public int getVersion() { return version; }
    public void setVersion(int version) { this.version = version; }

    public String getCleWrapped() { return cleWrapped; }
    public void setCleWrapped(String cleWrapped) { this.cleWrapped = cleWrapped; }

    public TypeCle getTypeCle() { return typeCle; }
    public void setTypeCle(TypeCle typeCle) { this.typeCle = typeCle; }

    public StatutCle getStatut() { return statut; }
    public void setStatut(StatutCle statut) { this.statut = statut; }

    public OffsetDateTime getDateCreation() { return dateCreation; }
    public void setDateCreation(OffsetDateTime dateCreation) { this.dateCreation = dateCreation; }

    public OffsetDateTime getDateRotationPrevue() { return dateRotationPrevue; }
    public void setDateRotationPrevue(OffsetDateTime dateRotationPrevue) { this.dateRotationPrevue = dateRotationPrevue; }

    public OffsetDateTime getDateRotationEffectuee() { return dateRotationEffectuee; }
    public void setDateRotationEffectuee(OffsetDateTime dateRotationEffectuee) { this.dateRotationEffectuee = dateRotationEffectuee; }

    public UUID getCreatedBy() { return createdBy; }
    public void setCreatedBy(UUID createdBy) { this.createdBy = createdBy; }

    public enum TypeCle { DATA, HMAC }
    public enum StatutCle { ACTIVE, DEPRECATED, REVOKED }
}
