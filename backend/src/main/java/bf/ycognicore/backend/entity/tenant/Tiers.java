package bf.ycognicore.backend.entity.tenant;

import jakarta.persistence.*;
import org.hibernate.annotations.UuidGenerator;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Entite Tiers minimale (P4) : seules les colonnes sensibles a chiffrer + HMAC.
 * Extension complete prevue en P7 (tranche verticale commerciale).
 * Ref. : P4 L3.2, D-P4-3, D-P4-4, ADR-042.
 */
@Entity
@Table(name = "tiers")
public class Tiers {

    @Id
    @UuidGenerator
    @Column(name = "id", columnDefinition = "uuid", updatable = false, nullable = false)
    private UUID id;

    @Column(name = "code", nullable = false, length = 20)
    private String code;

    @Column(name = "raison_sociale", nullable = false, length = 255)
    private String raisonSociale;

    // Champs chiffres — format v<N>:base64(iv||ct||tag)
    @Column(name = "ifu", length = 200)
    private String ifu;

    @Column(name = "rccm", length = 200)
    private String rccm;

    @Column(name = "telephone", length = 200)
    private String telephone;

    @Column(name = "conditions_reglement", columnDefinition = "text")
    private String conditionsReglement;

    @Column(name = "email", columnDefinition = "citext")
    private String email;

    // HMAC pour recherche exacte
    @Column(name = "ifu_hmac", length = 64)
    private String ifuHmac;

    @Column(name = "rccm_hmac", length = 64)
    private String rccmHmac;

    @Column(name = "telephone_hmac", length = 64)
    private String telephoneHmac;

    @Column(name = "email_hmac", length = 64)
    private String emailHmac;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = OffsetDateTime.now();
    }

    // Getters/Setters

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getCode() { return code; }
    public void setCode(String code) { this.code = code; }

    public String getRaisonSociale() { return raisonSociale; }
    public void setRaisonSociale(String raisonSociale) { this.raisonSociale = raisonSociale; }

    public String getIfu() { return ifu; }
    public void setIfu(String ifu) { this.ifu = ifu; }

    public String getRccm() { return rccm; }
    public void setRccm(String rccm) { this.rccm = rccm; }

    public String getTelephone() { return telephone; }
    public void setTelephone(String telephone) { this.telephone = telephone; }

    public String getConditionsReglement() { return conditionsReglement; }
    public void setConditionsReglement(String conditionsReglement) {
        this.conditionsReglement = conditionsReglement;
    }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getIfuHmac() { return ifuHmac; }
    public void setIfuHmac(String ifuHmac) { this.ifuHmac = ifuHmac; }

    public String getRccmHmac() { return rccmHmac; }
    public void setRccmHmac(String rccmHmac) { this.rccmHmac = rccmHmac; }

    public String getTelephoneHmac() { return telephoneHmac; }
    public void setTelephoneHmac(String telephoneHmac) { this.telephoneHmac = telephoneHmac; }

    public String getEmailHmac() { return emailHmac; }
    public void setEmailHmac(String emailHmac) { this.emailHmac = emailHmac; }

    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }
}
