package bf.ycognicore.backend.entity.tenant;

import jakarta.persistence.*;

/**
 * Referentiel des modules fonctionnels (base tenant).
 * Ref. : dictionnaire v1.2 T1
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

    public Module() {}

    public Integer getId() { return id; }
    public void setId(Integer v) { this.id = v; }
    public String getCode() { return code; }
    public void setCode(String v) { this.code = v; }
    public String getLibelle() { return libelle; }
    public void setLibelle(String v) { this.libelle = v; }
    public Short getOrdreAffichage() { return ordreAffichage; }
    public void setOrdreAffichage(Short v) { this.ordreAffichage = v; }
}
