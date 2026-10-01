package bf.ycognicore.backend.entity.controlplane;

import jakarta.persistence.*;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Evenements webhooks (idempotence via UK aggregateur + event_id_externe).
 * Ref. : dictionnaire v1.2 G5, ADR-001, NFR-SEC-26
 */
@Entity
@Table(name = "webhook_events")
public class WebhookEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "aggregateur", nullable = false, length = 30)
    private String aggregateur;

    @Column(name = "event_id_externe", nullable = false, length = 150)
    private String eventIdExterne;

    @Column(name = "signature", length = 500)
    private String signature;

    @Column(name = "payload_brut", nullable = false, columnDefinition = "jsonb")
    private String payloadBrut;

    @Column(name = "statut_traitement", nullable = false, length = 30)
    private String statutTraitement = "RECU";

    @Column(name = "date_reception", nullable = false)
    private OffsetDateTime dateReception;

    @Column(name = "date_traitement")
    private OffsetDateTime dateTraitement;

    @Column(name = "erreur", columnDefinition = "TEXT")
    private String erreur;

    public WebhookEvent() {}

    public UUID getId() { return id; }
    public void setId(UUID v) { this.id = v; }
    public String getAggregateur() { return aggregateur; }
    public void setAggregateur(String v) { this.aggregateur = v; }
    public String getEventIdExterne() { return eventIdExterne; }
    public void setEventIdExterne(String v) { this.eventIdExterne = v; }
    public String getSignature() { return signature; }
    public void setSignature(String v) { this.signature = v; }
    public String getPayloadBrut() { return payloadBrut; }
    public void setPayloadBrut(String v) { this.payloadBrut = v; }
    public String getStatutTraitement() { return statutTraitement; }
    public void setStatutTraitement(String v) { this.statutTraitement = v; }
    public OffsetDateTime getDateReception() { return dateReception; }
    public void setDateReception(OffsetDateTime v) { this.dateReception = v; }
    public OffsetDateTime getDateTraitement() { return dateTraitement; }
    public void setDateTraitement(OffsetDateTime v) { this.dateTraitement = v; }
    public String getErreur() { return erreur; }
    public void setErreur(String v) { this.erreur = v; }
}
