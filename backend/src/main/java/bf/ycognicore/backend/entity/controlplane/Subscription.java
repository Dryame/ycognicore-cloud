package bf.ycognicore.backend.entity.controlplane;

import bf.ycognicore.backend.entity.controlplane.enums.FormuleAbonnement;
import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Historique des formules d'abonnement d'un tenant.
 * Ref. : dictionnaire v1.2 G4
 */
@Entity
@Table(name = "subscriptions")
public class Subscription {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "tenant_id", nullable = false)
    private UUID tenantId;

    @Enumerated(EnumType.STRING)
    @Column(name = "formule", nullable = false, columnDefinition = "formule_abonnement")
    private FormuleAbonnement formule;

    @Column(name = "montant", nullable = false, precision = 12, scale = 2)
    private BigDecimal montant;

    @Column(name = "devise", nullable = false, length = 3)
    private String devise = "XOF";

    @Column(name = "renouvellement_auto", nullable = false)
    private boolean renouvellementAuto = true;

    @Column(name = "date_debut", nullable = false)
    private LocalDate dateDebut;

    @Column(name = "date_fin")
    private LocalDate dateFin;

    @Column(name = "statut", nullable = false, length = 20)
    private String statut = "ACTIVE";

    @Column(name = "date_resiliation")
    private LocalDate dateResiliation;

    @Column(name = "motif_resiliation", columnDefinition = "TEXT")
    private String motifResiliation;

    @Column(name = "reference_contrat", length = 100)
    private String referenceContrat;

    public Subscription() {}

    public UUID getId() { return id; }
    public void setId(UUID v) { this.id = v; }
    public UUID getTenantId() { return tenantId; }
    public void setTenantId(UUID v) { this.tenantId = v; }
    public FormuleAbonnement getFormule() { return formule; }
    public void setFormule(FormuleAbonnement v) { this.formule = v; }
    public BigDecimal getMontant() { return montant; }
    public void setMontant(BigDecimal v) { this.montant = v; }
    public String getDevise() { return devise; }
    public void setDevise(String v) { this.devise = v; }
    public boolean isRenouvellementAuto() { return renouvellementAuto; }
    public void setRenouvellementAuto(boolean v) { this.renouvellementAuto = v; }
    public LocalDate getDateDebut() { return dateDebut; }
    public void setDateDebut(LocalDate v) { this.dateDebut = v; }
    public LocalDate getDateFin() { return dateFin; }
    public void setDateFin(LocalDate v) { this.dateFin = v; }
    public String getStatut() { return statut; }
    public void setStatut(String v) { this.statut = v; }
    public LocalDate getDateResiliation() { return dateResiliation; }
    public void setDateResiliation(LocalDate v) { this.dateResiliation = v; }
    public String getMotifResiliation() { return motifResiliation; }
    public void setMotifResiliation(String v) { this.motifResiliation = v; }
    public String getReferenceContrat() { return referenceContrat; }
    public void setReferenceContrat(String v) { this.referenceContrat = v; }
}
