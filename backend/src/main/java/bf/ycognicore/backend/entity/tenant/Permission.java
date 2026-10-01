package bf.ycognicore.backend.entity.tenant;

import jakarta.persistence.*;

/**
 * Les 6 permissions fixes (NFR-SEC-12).
 * Ref. : dictionnaire v1.2 T1
 */
@Entity
@Table(name = "permissions")
public class Permission {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "code", nullable = false, unique = true, length = 20)
    private String code;

    @Column(name = "libelle", nullable = false, length = 50)
    private String libelle;

    public Permission() {}

    public Integer getId() { return id; }
    public void setId(Integer v) { this.id = v; }
    public String getCode() { return code; }
    public void setCode(String v) { this.code = v; }
    public String getLibelle() { return libelle; }
    public void setLibelle(String v) { this.libelle = v; }
}
