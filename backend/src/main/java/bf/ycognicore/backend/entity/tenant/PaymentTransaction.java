package bf.ycognicore.backend.entity.tenant;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Transactions de paiement cote tenant.
 * Ref. : dictionnaire v1.2 T5, NFR-SEC-26
 */
@Entity
@Table(name = "payment_transactions")
public class PaymentTransaction {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "aggregateur", nullable = false, length = 30)
    private String aggregateur;

    @Column(name = "reference_externe", nullable = false, unique = true, length = 150)
    private String referenceExterne;

    @Column(name = "montant", nullable = false, precision = 12, scale = 2)
    private BigDecimal montant;

    @Column(name = "devise", nullable = false, length = 3)
    private String devise = "XOF";

    @Column(name = "mode_paiement", nullable = false, length = 30)
    private String modePaiement;

    @Column(name = "operateur", length = 30)
    private String operateur;

    @Column(name = "facture_source", length = 50)
    private String factureSource;

    @Column(name = "statut", nullable = false, length = 30)
    private String statut = "INITIEE";

    @Column(name = "date_initiation", nullable = false)
    private OffsetDateTime dateInitiation;

    @Column(name = "date_confirmation")
    private OffsetDateTime dateConfirmation;

    @Column(name = "payload_retour", columnDefinition = "jsonb")
    private String payloadRetour;

    public PaymentTransaction() {}

    public UUID getId() { return id; }
    public void setId(UUID v) { this.id = v; }
    public String getAggregateur() { return aggregateur; }
    public void setAggregateur(String v) { this.aggregateur = v; }
    public String getReferenceExterne() { return referenceExterne; }
    public void setReferenceExterne(String v) { this.referenceExterne = v; }
    public BigDecimal getMontant() { return montant; }
    public void setMontant(BigDecimal v) { this.montant = v; }
    public String getDevise() { return devise; }
    public void setDevise(String v) { this.devise = v; }
    public String getModePaiement() { return modePaiement; }
    public void setModePaiement(String v) { this.modePaiement = v; }
    public String getOperateur() { return operateur; }
    public void setOperateur(String v) { this.operateur = v; }
    public String getFactureSource() { return factureSource; }
    public void setFactureSource(String v) { this.factureSource = v; }
    public String getStatut() { return statut; }
    public void setStatut(String v) { this.statut = v; }
    public OffsetDateTime getDateInitiation() { return dateInitiation; }
    public void setDateInitiation(OffsetDateTime v) { this.dateInitiation = v; }
    public OffsetDateTime getDateConfirmation() { return dateConfirmation; }
    public void setDateConfirmation(OffsetDateTime v) { this.dateConfirmation = v; }
    public String getPayloadRetour() { return payloadRetour; }
    public void setPayloadRetour(String v) { this.payloadRetour = v; }
}
