package bf.ycognicore.backend.entity.controlplane.ids;

import java.io.Serializable;
import java.util.Objects;

/**
 * Cle composite de formule_modules (formule_caracteristique_id, module_id).
 */
public class FormuleModuleId implements Serializable {

    private Integer formuleCaracteristiqueId;
    private Integer moduleId;

    public FormuleModuleId() {}

    public FormuleModuleId(Integer f, Integer m) {
        this.formuleCaracteristiqueId = f;
        this.moduleId = m;
    }

    public Integer getFormuleCaracteristiqueId() { return formuleCaracteristiqueId; }
    public void setFormuleCaracteristiqueId(Integer v) { this.formuleCaracteristiqueId = v; }
    public Integer getModuleId() { return moduleId; }
    public void setModuleId(Integer v) { this.moduleId = v; }

    @Override public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof FormuleModuleId that)) return false;
        return Objects.equals(formuleCaracteristiqueId, that.formuleCaracteristiqueId)
            && Objects.equals(moduleId, that.moduleId);
    }
    @Override public int hashCode() {
        return Objects.hash(formuleCaracteristiqueId, moduleId);
    }
}
