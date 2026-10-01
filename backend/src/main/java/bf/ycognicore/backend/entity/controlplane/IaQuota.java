package bf.ycognicore.backend.entity.controlplane;

import bf.ycognicore.backend.entity.controlplane.enums.FormuleAbonnement;
import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Quota mensuel de requetes IA par tenant.
 * Ref. : dictionnaire v1.2 G6, NFR-IA-01, NFR-PERF-12
 */
@Entity
@Table(name = "ia_quotas")
public class IaQuota {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id", nullable = false)
    private UUID tenantId;

    @Enumerated(EnumType.STRING)
    @Column(name = "formule", nullable = false, columnDefinition = "formule_abonnement")
    private FormuleAbonnement formule;

    @Column(name = "periode", nullable = false)
    private LocalDate periode;

    @Column(name = "quota_mensuel", nullable = false)
    private Integer quotaMensuel;

    @Column(name = "consommation", nullable = false)
    private Integer consommation = 0;

    @Column(name = "alerte_envoyee", nullable = false)
    private boolean alerteEnvoyee = false;

    @Column(name = "date_alerte")
    private OffsetDateTime dateAlerte;

    @Column(name = "cout_total", nullable = false, precision = 12, scale = 4)
    private BigDecimal coutTotal = BigDecimal.ZERO;

    @Column(name = "cache_hits", nullable = false)
    private Integer cacheHits = 0;

    @Column(name = "date_maj", nullable = false)
    private OffsetDateTime dateMaj;

    public IaQuota() {}

    public Long getId() { return id; }
    public void setId(Long v) { this.id = v; }
    public UUID getTenantId() { return tenantId; }
    public void setTenantId(UUID v) { this.tenantId = v; }
    public FormuleAbonnement getFormule() { return formule; }
    public void setFormule(FormuleAbonnement v) { this.formule = v; }
    public LocalDate getPeriode() { return periode; }
    public void setPeriode(LocalDate v) { this.periode = v; }
    public Integer getQuotaMensuel() { return quotaMensuel; }
    public void setQuotaMensuel(Integer v) { this.quotaMensuel = v; }
    public Integer getConsommation() { return consommation; }
    public void setConsommation(Integer v) { this.consommation = v; }
    public boolean isAlerteEnvoyee() { return alerteEnvoyee; }
    public void setAlerteEnvoyee(boolean v) { this.alerteEnvoyee = v; }
    public OffsetDateTime getDateAlerte() { return dateAlerte; }
    public void setDateAlerte(OffsetDateTime v) { this.dateAlerte = v; }
    public BigDecimal getCoutTotal() { return coutTotal; }
    public void setCoutTotal(BigDecimal v) { this.coutTotal = v; }
    public Integer getCacheHits() { return cacheHits; }
    public void setCacheHits(Integer v) { this.cacheHits = v; }
    public OffsetDateTime getDateMaj() { return dateMaj; }
    public void setDateMaj(OffsetDateTime v) { this.dateMaj = v; }
}
