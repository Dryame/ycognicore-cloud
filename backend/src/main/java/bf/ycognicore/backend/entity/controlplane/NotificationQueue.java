package bf.ycognicore.backend.entity.controlplane;

import jakarta.persistence.*;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * File d'attente des notifications multicanales (NFR-UX-07).
 * Ref. : dictionnaire v1.2 G7, ADR-001
 */
@Entity
@Table(name = "notifications_queue")
public class NotificationQueue {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "tenant_id")
    private UUID tenantId;

    @Column(name = "destinataire", nullable = false, length = 255)
    private String destinataire;

    @Column(name = "canal", nullable = false, length = 30)
    private String canal;

    @Column(name = "sujet", length = 255)
    private String sujet;

    @Column(name = "contenu", nullable = false, columnDefinition = "TEXT")
    private String contenu;

    @Column(name = "statut", nullable = false, length = 20)
    private String statut = "EN_ATTENTE";

    @Column(name = "tentatives", nullable = false)
    private Short tentatives = 0;

    @Column(name = "next_retry_at")
    private OffsetDateTime nextRetryAt;

    @Column(name = "date_creation", nullable = false)
    private OffsetDateTime dateCreation;

    @Column(name = "date_envoi")
    private OffsetDateTime dateEnvoi;

    @Column(name = "erreur", columnDefinition = "TEXT")
    private String erreur;

    @Column(name = "metadata", columnDefinition = "jsonb")
    private String metadata;

    public NotificationQueue() {}

    public Long getId() { return id; }
    public void setId(Long v) { this.id = v; }
    public UUID getTenantId() { return tenantId; }
    public void setTenantId(UUID v) { this.tenantId = v; }
    public String getDestinataire() { return destinataire; }
    public void setDestinataire(String v) { this.destinataire = v; }
    public String getCanal() { return canal; }
    public void setCanal(String v) { this.canal = v; }
    public String getSujet() { return sujet; }
    public void setSujet(String v) { this.sujet = v; }
    public String getContenu() { return contenu; }
    public void setContenu(String v) { this.contenu = v; }
    public String getStatut() { return statut; }
    public void setStatut(String v) { this.statut = v; }
    public Short getTentatives() { return tentatives; }
    public void setTentatives(Short v) { this.tentatives = v; }
    public OffsetDateTime getNextRetryAt() { return nextRetryAt; }
    public void setNextRetryAt(OffsetDateTime v) { this.nextRetryAt = v; }
    public OffsetDateTime getDateCreation() { return dateCreation; }
    public void setDateCreation(OffsetDateTime v) { this.dateCreation = v; }
    public OffsetDateTime getDateEnvoi() { return dateEnvoi; }
    public void setDateEnvoi(OffsetDateTime v) { this.dateEnvoi = v; }
    public String getErreur() { return erreur; }
    public void setErreur(String v) { this.erreur = v; }
    public String getMetadata() { return metadata; }
    public void setMetadata(String v) { this.metadata = v; }
}
