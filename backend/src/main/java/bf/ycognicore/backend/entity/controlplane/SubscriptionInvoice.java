package bf.ycognicore.backend.entity.controlplane;

import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Factures d'abonnement SaaS (NFR-CONF-01).
 * Ref. : dictionnaire v1.2 G4
 */
@Entity
@Table(name = "subscription_invoices")
public class SubscriptionInvoice {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "numero_facture", nullable = false, unique = true, length = 50)
    private String numeroFacture;

    @Column(name = "tenant_id", nullable = false)
    private UUID tenantId;

    @Column(name = "subscription_id")
    private UUID subscriptionId;

    @Column(name = "montant_ht", nullable = false, precision = 12, scale = 2)
    private BigDecimal montantHt;

    @Column(name = "montant_tva", nullable = false, precision = 12, scale = 2)
    private BigDecimal montantTva = BigDecimal.ZERO;

    @Column(name = "montant_ttc", nullable = false, precision = 12, scale = 2)
    private BigDecimal montantTtc;

    @Column(name = "statut", nullable = false, length = 20)
    private String statut = "EN_ATTENTE";

    @Column(name = "mode_paiement", length = 30)
    private String modePaiement;

    @Column(name = "pdf_url", columnDefinition = "TEXT")
    private String pdfUrl;

    @Column(name = "pdf_hash", length = 128)
    private String pdfHash;

    @Column(name = "date_emission", nullable = false)
    private LocalDate dateEmission;

    @Column(name = "date_echeance", nullable = false)
    private LocalDate dateEcheance;

    @Column(name = "date_paiement")
    private LocalDate datePaiement;

    @Column(name = "date_annulation")
    private LocalDate dateAnnulation;

    @Column(name = "motif_annulation", columnDefinition = "TEXT")
    private String motifAnnulation;

    @Column(name = "date_creation", nullable = false)
    private OffsetDateTime dateCreation;

    public SubscriptionInvoice() {}

    public UUID getId() { return id; }
    public void setId(UUID v) { this.id = v; }
    public String getNumeroFacture() { return numeroFacture; }
    public void setNumeroFacture(String v) { this.numeroFacture = v; }
    public UUID getTenantId() { return tenantId; }
    public void setTenantId(UUID v) { this.tenantId = v; }
    public UUID getSubscriptionId() { return subscriptionId; }
    public void setSubscriptionId(UUID v) { this.subscriptionId = v; }
    public BigDecimal getMontantHt() { return montantHt; }
    public void setMontantHt(BigDecimal v) { this.montantHt = v; }
    public BigDecimal getMontantTva() { return montantTva; }
    public void setMontantTva(BigDecimal v) { this.montantTva = v; }
    public BigDecimal getMontantTtc() { return montantTtc; }
    public void setMontantTtc(BigDecimal v) { this.montantTtc = v; }
    public String getStatut() { return statut; }
    public void setStatut(String v) { this.statut = v; }
    public String getModePaiement() { return modePaiement; }
    public void setModePaiement(String v) { this.modePaiement = v; }
    public String getPdfUrl() { return pdfUrl; }
    public void setPdfUrl(String v) { this.pdfUrl = v; }
    public String getPdfHash() { return pdfHash; }
    public void setPdfHash(String v) { this.pdfHash = v; }
    public LocalDate getDateEmission() { return dateEmission; }
    public void setDateEmission(LocalDate v) { this.dateEmission = v; }
    public LocalDate getDateEcheance() { return dateEcheance; }
    public void setDateEcheance(LocalDate v) { this.dateEcheance = v; }
    public LocalDate getDatePaiement() { return datePaiement; }
    public void setDatePaiement(LocalDate v) { this.datePaiement = v; }
    public LocalDate getDateAnnulation() { return dateAnnulation; }
    public void setDateAnnulation(LocalDate v) { this.dateAnnulation = v; }
    public String getMotifAnnulation() { return motifAnnulation; }
    public void setMotifAnnulation(String v) { this.motifAnnulation = v; }
    public OffsetDateTime getDateCreation() { return dateCreation; }
    public void setDateCreation(OffsetDateTime v) { this.dateCreation = v; }
}
