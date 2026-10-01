package bf.ycognicore.backend.entity.controlplane;

import bf.ycognicore.backend.entity.controlplane.ids.FormuleModuleId;
import jakarta.persistence.*;

/**
 * Liaison formule <-> modules inclus (N-N).
 * Ref. : dictionnaire v1.2 G3, ADR-001
 */
@Entity
@Table(name = "formule_modules")
@IdClass(FormuleModuleId.class)
public class FormuleModule {

    @Id
    @Column(name = "formule_caracteristique_id", nullable = false)
    private Integer formuleCaracteristiqueId;

    @Id
    @Column(name = "module_id", nullable = false)
    private Integer moduleId;

    public FormuleModule() {}

    public Integer getFormuleCaracteristiqueId() { return formuleCaracteristiqueId; }
    public void setFormuleCaracteristiqueId(Integer v) { this.formuleCaracteristiqueId = v; }
    public Integer getModuleId() { return moduleId; }
    public void setModuleId(Integer v) { this.moduleId = v; }
}
