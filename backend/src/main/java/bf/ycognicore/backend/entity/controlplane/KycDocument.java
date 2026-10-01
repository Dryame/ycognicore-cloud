package bf.ycognicore.backend.entity.controlplane;

import jakarta.persistence.*;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Pieces justificatives KYC (registre commerce, identifiant fiscal).
 * Ref. : dictionnaire v1.2 G1, NFR-SEC-31
 */
@Entity
@Table(name = "kyc_documents")
public class KycDocument {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "tenant_id", nullable = false)
    private UUID tenantId;

    @Column(name = "type_document", nullable = false, length = 50)
    private String typeDocument;

    @Column(name = "url", nullable = false, columnDefinition = "TEXT")
    private String url;

    @Column(name = "hash_document", length = 128)
    private String hashDocument;

    @Column(name = "date_expiration")
    private LocalDate dateExpiration;

    @Column(name = "statut_verification", nullable = false, length = 20)
    private String statutVerification = "EN_ATTENTE";

    @Column(name = "motif_rejet", columnDefinition = "TEXT")
    private String motifRejet;

    @Column(name = "valide_par")
    private UUID validePar;

    @Column(name = "date_soumission", nullable = false)
    private OffsetDateTime dateSoumission;

    @Column(name = "date_verification")
    private OffsetDateTime dateVerification;

    public KycDocument() {}

    public UUID getId() { return id; }
    public void setId(UUID v) { this.id = v; }
    public UUID getTenantId() { return tenantId; }
    public void setTenantId(UUID v) { this.tenantId = v; }
    public String getTypeDocument() { return typeDocument; }
    public void setTypeDocument(String v) { this.typeDocument = v; }
    public String getUrl() { return url; }
    public void setUrl(String v) { this.url = v; }
    public String getHashDocument() { return hashDocument; }
    public void setHashDocument(String v) { this.hashDocument = v; }
    public LocalDate getDateExpiration() { return dateExpiration; }
    public void setDateExpiration(LocalDate v) { this.dateExpiration = v; }
    public String getStatutVerification() { return statutVerification; }
    public void setStatutVerification(String v) { this.statutVerification = v; }
    public String getMotifRejet() { return motifRejet; }
    public void setMotifRejet(String v) { this.motifRejet = v; }
    public UUID getValidePar() { return validePar; }
    public void setValidePar(UUID v) { this.validePar = v; }
    public OffsetDateTime getDateSoumission() { return dateSoumission; }
    public void setDateSoumission(OffsetDateTime v) { this.dateSoumission = v; }
    public OffsetDateTime getDateVerification() { return dateVerification; }
    public void setDateVerification(OffsetDateTime v) { this.dateVerification = v; }
}
