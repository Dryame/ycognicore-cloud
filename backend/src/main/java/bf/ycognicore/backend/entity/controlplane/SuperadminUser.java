package bf.ycognicore.backend.entity.controlplane;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.JsonNode;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Comptes du Super Administrateur SaaS.
 * Ref. : dictionnaire v1.2 G2, ADR-002, ADR-005
 */
@Entity
@Table(name = "superadmin_users")
public class SuperadminUser {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "email", nullable = false, unique = true, columnDefinition = "citext")
    private String email;

    @Column(name = "nom_complet", nullable = false, length = 255)
    private String nomComplet;

    @Column(name = "mot_de_passe_hash", nullable = false, columnDefinition = "TEXT")
    private String motDePasseHash;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "mfa_secret_package", columnDefinition = "jsonb")
    private JsonNode mfaSecretPackage;

    @Column(name = "mfa_enabled", nullable = false)
    private boolean mfaEnabled = false;

    @Column(name = "statut", nullable = false, length = 20)
    private String statut = "ACTIF";

    @Column(name = "date_derniere_connexion")
    private OffsetDateTime dateDerniereConnexion;

    @Column(name = "date_expiration_mot_de_passe")
    private LocalDate dateExpirationMotDePasse;

    @Column(name = "date_creation", nullable = false)
    private OffsetDateTime dateCreation;

    @Column(name = "date_maj", nullable = false)
    private OffsetDateTime dateMaj;

    public SuperadminUser() {}

    public UUID getId() { return id; }
    public void setId(UUID v) { this.id = v; }
    public String getEmail() { return email; }
    public void setEmail(String v) { this.email = v; }
    public String getNomComplet() { return nomComplet; }
    public void setNomComplet(String v) { this.nomComplet = v; }
    public String getMotDePasseHash() { return motDePasseHash; }
    public void setMotDePasseHash(String v) { this.motDePasseHash = v; }
    public JsonNode getMfaSecretPackage() { return mfaSecretPackage; }
    public void setMfaSecretPackage(JsonNode v) { this.mfaSecretPackage = v; }
    public boolean isMfaEnabled() { return mfaEnabled; }
    public void setMfaEnabled(boolean v) { this.mfaEnabled = v; }
    public String getStatut() { return statut; }
    public void setStatut(String v) { this.statut = v; }
    public OffsetDateTime getDateDerniereConnexion() { return dateDerniereConnexion; }
    public void setDateDerniereConnexion(OffsetDateTime v) { this.dateDerniereConnexion = v; }
    public LocalDate getDateExpirationMotDePasse() { return dateExpirationMotDePasse; }
    public void setDateExpirationMotDePasse(LocalDate v) { this.dateExpirationMotDePasse = v; }
    public OffsetDateTime getDateCreation() { return dateCreation; }
    public void setDateCreation(OffsetDateTime v) { this.dateCreation = v; }
    public OffsetDateTime getDateMaj() { return dateMaj; }
    public void setDateMaj(OffsetDateTime v) { this.dateMaj = v; }
}
