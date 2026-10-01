package bf.ycognicore.backend.entity.controlplane;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

/**
 * Compteurs de numerotation legale (factures SaaS).
 * Ref. : dictionnaire v1.2 G4, ADR-001, NFR-CONF-01
 */
@Entity
@Table(name = "numero_sequences")
public class NumeroSequence {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "type_document", nullable = false, length = 50)
    private String typeDocument;

    @Column(name = "prefixe", nullable = false, length = 20)
    private String prefixe;

    @Column(name = "annee", nullable = false)
    private Integer annee;

    @Column(name = "dernier_numero", nullable = false)
    private Integer dernierNumero = 0;

    @Column(name = "format", nullable = false, length = 100)
    private String format = "{PREFIXE}-{ANNEE}-{NUMERO:06d}";

    @Column(name = "date_maj", nullable = false)
    private OffsetDateTime dateMaj;

    public NumeroSequence() {}

    public Integer getId() { return id; }
    public void setId(Integer v) { this.id = v; }
    public String getTypeDocument() { return typeDocument; }
    public void setTypeDocument(String v) { this.typeDocument = v; }
    public String getPrefixe() { return prefixe; }
    public void setPrefixe(String v) { this.prefixe = v; }
    public Integer getAnnee() { return annee; }
    public void setAnnee(Integer v) { this.annee = v; }
    public Integer getDernierNumero() { return dernierNumero; }
    public void setDernierNumero(Integer v) { this.dernierNumero = v; }
    public String getFormat() { return format; }
    public void setFormat(String v) { this.format = v; }
    public OffsetDateTime getDateMaj() { return dateMaj; }
    public void setDateMaj(OffsetDateTime v) { this.dateMaj = v; }
}
