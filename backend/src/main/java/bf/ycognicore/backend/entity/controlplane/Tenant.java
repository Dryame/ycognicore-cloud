package bf.ycognicore.backend.entity.controlplane;

import bf.ycognicore.backend.entity.controlplane.enums.FormuleAbonnement;
import bf.ycognicore.backend.entity.controlplane.enums.StatutTenant;
import jakarta.persistence.*;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Entreprise cliente abonnee a la plateforme (control plane).
 * Ref. : dictionnaire v1.2 G1, NFR-SEC-01, ADR-001
 */
@Entity
@Table(name = "tenants")
public class Tenant {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(name = "id", nullable = false, updatable = false)
    private UUID id;

    @Column(name = "code", nullable = false, unique = true, length = 50)
    private String code;

    @Column(name = "nom", nullable = false, length = 255)
    private String nom;

    @Column(name = "email_contact", nullable = false, unique = true, columnDefinition = "citext")
    private String emailContact;

    @Column(name = "telephone", length = 30)
    private String telephone;

    @Column(name = "adresse", columnDefinition = "TEXT")
    private String adresse;

    @Column(name = "pays", nullable = false, length = 100)
    private String pays = "Burkina Faso";

    @Enumerated(EnumType.STRING)
    @Column(name = "statut", nullable = false, columnDefinition = "statut_tenant")
    private StatutTenant statut = StatutTenant.TRIAL;

    @Enumerated(EnumType.STRING)
    @Column(name = "formule", nullable = false, columnDefinition = "formule_abonnement")
    private FormuleAbonnement formule = FormuleAbonnement.TRIAL;

    @Column(name = "date_fin_essai")
    private LocalDate dateFinEssai;

    @Column(name = "date_creation", nullable = false)
    private OffsetDateTime dateCreation;

    @Column(name = "date_maj", nullable = false)
    private OffsetDateTime dateMaj;

    @Column(name = "date_suppression")
    private OffsetDateTime dateSuppression;

    public Tenant() {}

    public UUID getId() { return id; }
    public void setId(UUID v) { this.id = v; }
    public String getCode() { return code; }
    public void setCode(String v) { this.code = v; }
    public String getNom() { return nom; }
    public void setNom(String v) { this.nom = v; }
    public String getEmailContact() { return emailContact; }
    public void setEmailContact(String v) { this.emailContact = v; }
    public String getTelephone() { return telephone; }
    public void setTelephone(String v) { this.telephone = v; }
    public String getAdresse() { return adresse; }
    public void setAdresse(String v) { this.adresse = v; }
    public String getPays() { return pays; }
    public void setPays(String v) { this.pays = v; }
    public StatutTenant getStatut() { return statut; }
    public void setStatut(StatutTenant v) { this.statut = v; }
    public FormuleAbonnement getFormule() { return formule; }
    public void setFormule(FormuleAbonnement v) { this.formule = v; }
    public LocalDate getDateFinEssai() { return dateFinEssai; }
    public void setDateFinEssai(LocalDate v) { this.dateFinEssai = v; }
    public OffsetDateTime getDateCreation() { return dateCreation; }
    public void setDateCreation(OffsetDateTime v) { this.dateCreation = v; }
    public OffsetDateTime getDateMaj() { return dateMaj; }
    public void setDateMaj(OffsetDateTime v) { this.dateMaj = v; }
    public OffsetDateTime getDateSuppression() { return dateSuppression; }
    public void setDateSuppression(OffsetDateTime v) { this.dateSuppression = v; }
}
