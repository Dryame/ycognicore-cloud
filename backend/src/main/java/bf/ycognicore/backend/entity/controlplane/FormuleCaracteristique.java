package bf.ycognicore.backend.entity.controlplane;

import bf.ycognicore.backend.entity.controlplane.enums.FormuleAbonnement;
import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;

/**
 * Caracteristiques pilotables des formules (NFR-IA-04).
 * Ref. : dictionnaire v1.2 G3, ADR-001
 */
@Entity
@Table(name = "formule_caracteristiques")
public class FormuleCaracteristique {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Enumerated(EnumType.STRING)
    @Column(name = "formule", nullable = false, columnDefinition = "formule_abonnement")
    private FormuleAbonnement formule;

    @Column(name = "quota_ia_mensuel", nullable = false)
    private Integer quotaIaMensuel;

    @Column(name = "quota_utilisateurs")
    private Integer quotaUtilisateurs;

    @Column(name = "quota_stockage_go")
    private Integer quotaStockageGo;

    @Column(name = "prix_mensuel", nullable = false, precision = 12, scale = 2)
    private BigDecimal prixMensuel;

    @Column(name = "devise", nullable = false, length = 3)
    private String devise = "XOF";

    @Column(name = "date_effet", nullable = false)
    private LocalDate dateEffet;

    @Column(name = "date_fin")
    private LocalDate dateFin;

    @Column(name = "actif", nullable = false)
    private boolean actif = true;

    @Column(name = "date_creation", nullable = false)
    private OffsetDateTime dateCreation;

    public FormuleCaracteristique() {}

    public Integer getId() { return id; }
    public void setId(Integer v) { this.id = v; }
    public FormuleAbonnement getFormule() { return formule; }
    public void setFormule(FormuleAbonnement v) { this.formule = v; }
    public Integer getQuotaIaMensuel() { return quotaIaMensuel; }
    public void setQuotaIaMensuel(Integer v) { this.quotaIaMensuel = v; }
    public Integer getQuotaUtilisateurs() { return quotaUtilisateurs; }
    public void setQuotaUtilisateurs(Integer v) { this.quotaUtilisateurs = v; }
    public Integer getQuotaStockageGo() { return quotaStockageGo; }
    public void setQuotaStockageGo(Integer v) { this.quotaStockageGo = v; }
    public BigDecimal getPrixMensuel() { return prixMensuel; }
    public void setPrixMensuel(BigDecimal v) { this.prixMensuel = v; }
    public String getDevise() { return devise; }
    public void setDevise(String v) { this.devise = v; }
    public LocalDate getDateEffet() { return dateEffet; }
    public void setDateEffet(LocalDate v) { this.dateEffet = v; }
    public LocalDate getDateFin() { return dateFin; }
    public void setDateFin(LocalDate v) { this.dateFin = v; }
    public boolean isActif() { return actif; }
    public void setActif(boolean v) { this.actif = v; }
    public OffsetDateTime getDateCreation() { return dateCreation; }
    public void setDateCreation(OffsetDateTime v) { this.dateCreation = v; }
}
