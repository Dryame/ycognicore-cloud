package bf.ycognicore.backend.entity.controlplane.enums;

/**
 * Statuts du cycle de vie d'un tenant (ENUM PostgreSQL statut_tenant).
 * Ref. : ADR-001, dictionnaire v1.2 G1
 */
public enum StatutTenant {
    TRIAL,
    ACTIF,
    SUSPENDU,
    RESILIE
}
