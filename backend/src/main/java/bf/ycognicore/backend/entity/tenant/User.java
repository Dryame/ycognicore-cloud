package bf.ycognicore.backend.entity.tenant;

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
 * Comptes utilisateurs internes/externes.
 * Ref. : dictionnaire v1.2 T2
 */
@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "email", nullable = false, unique = true, columnDefinition = "citext")
    private String email;

    @Column(name = "mot_de_passe_hash", nullable = false, columnDefinition = "TEXT")
    private String motDePasseHash;

    @Column(name = "nom", nullable = false, length = 100)
    private String nom;

    @Column(name = "prenom", nullable = false, length = 100)
    private String prenom;

    @Column(name = "telephone", length = 30)
    private String telephone;

    @Column(name = "type_utilisateur", nullable = false, length = 30)
    private String typeUtilisateur = "INTERNE";

    @Column(name = "statut", nullable = false, length = 20)
    private String statut = "ACTIF";

    @Column(name = "mfa_enabled", nullable = false)
    private boolean mfaEnabled = false;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "mfa_secret_package", columnDefinition = "jsonb")
    private JsonNode mfaSecretPackage;

    @Column(name = "mot_de_passe_a_changer", nullable = false)
    private boolean motDePasseAChanger = true;

    @Column(name = "date_derniere_connexion")
    private OffsetDateTime dateDerniereConnexion;

    @Column(name = "date_expiration_mot_de_passe")
    private LocalDate dateExpirationMotDePasse;

    @Column(name = "langue_preferee", length = 10)
    private String languePreferee = "fr";

    @Column(name = "fuseau_horaire", length = 50)
    private String fuseauHoraire = "Africa/Ouagadougou";

    @Column(name = "created_by")
    private UUID createdBy;

    @Column(name = "date_verrouillage")
    private OffsetDateTime dateVerrouillage;

    @Column(name = "motif_verrouillage", length = 100)
    private String motifVerrouillage;

    @Column(name = "date_creation", nullable = false)
    private OffsetDateTime dateCreation;

    public User() {}

    public UUID getId() { return id; }
    public void setId(UUID v) { this.id = v; }
    public String getEmail() { return email; }
    public void setEmail(String v) { this.email = v; }
    public String getMotDePasseHash() { return motDePasseHash; }
    public void setMotDePasseHash(String v) { this.motDePasseHash = v; }
    public String getNom() { return nom; }
    public void setNom(String v) { this.nom = v; }
    public String getPrenom() { return prenom; }
    public void setPrenom(String v) { this.prenom = v; }
    public String getTelephone() { return telephone; }
    public void setTelephone(String v) { this.telephone = v; }
    public String getTypeUtilisateur() { return typeUtilisateur; }
    public void setTypeUtilisateur(String v) { this.typeUtilisateur = v; }
    public String getStatut() { return statut; }
    public void setStatut(String v) { this.statut = v; }
    public boolean isMfaEnabled() { return mfaEnabled; }
    public void setMfaEnabled(boolean v) { this.mfaEnabled = v; }
    public JsonNode getMfaSecretPackage() { return mfaSecretPackage; }
    public void setMfaSecretPackage(JsonNode v) { this.mfaSecretPackage = v; }
    public boolean isMotDePasseAChanger() { return motDePasseAChanger; }
    public void setMotDePasseAChanger(boolean v) { this.motDePasseAChanger = v; }
    public OffsetDateTime getDateDerniereConnexion() { return dateDerniereConnexion; }
    public void setDateDerniereConnexion(OffsetDateTime v) { this.dateDerniereConnexion = v; }
    public LocalDate getDateExpirationMotDePasse() { return dateExpirationMotDePasse; }
    public void setDateExpirationMotDePasse(LocalDate v) { this.dateExpirationMotDePasse = v; }
    public String getLanguePreferee() { return languePreferee; }
    public void setLanguePreferee(String v) { this.languePreferee = v; }
    public String getFuseauHoraire() { return fuseauHoraire; }
    public void setFuseauHoraire(String v) { this.fuseauHoraire = v; }
    public UUID getCreatedBy() { return createdBy; }
    public void setCreatedBy(UUID v) { this.createdBy = v; }
    public OffsetDateTime getDateVerrouillage() { return dateVerrouillage; }
    public void setDateVerrouillage(OffsetDateTime v) { this.dateVerrouillage = v; }
    public String getMotifVerrouillage() { return motifVerrouillage; }
    public void setMotifVerrouillage(String v) { this.motifVerrouillage = v; }
    public OffsetDateTime getDateCreation() { return dateCreation; }
    public void setDateCreation(OffsetDateTime v) { this.dateCreation = v; }
}
