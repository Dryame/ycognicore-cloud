package bf.ycognicore.backend.entity.controlplane;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

/**
 * Referentiel global des modules (miroir de la table tenant).
 * Ref. : dictionnaire v1.2 G3, ADR-001
 */
@Entity
@Table(name = "modules")
public class Module {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "code", nullable = false, unique = true, length = 30)
    private String code;

    @Column(name = "libelle", nullable = false, length = 100)
    private String libelle;

    @Column(name = "ordre_affichage", nullable = false)
    private Short ordreAffichage = 0;

    @Column(name = "date_creation", nullable = false)
    private OffsetDateTime dateCreation;

    public Module() {}

    public Integer getId() { return id; }
    public void setId(Integer v) { this.id = v; }
    public String getCode() { return code; }
    public void setCode(String v) { this.code = v; }
    public String getLibelle() { return libelle; }
    public void setLibelle(String v) { this.libelle = v; }
    public Short getOrdreAffichage() { return ordreAffichage; }
    public void setOrdreAffichage(Short v) { this.ordreAffichage = v; }
    public OffsetDateTime getDateCreation() { return dateCreation; }
    public void setDateCreation(OffsetDateTime v) { this.dateCreation = v; }
}
