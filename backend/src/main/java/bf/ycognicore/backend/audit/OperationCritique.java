package bf.ycognicore.backend.audit;

import java.util.Set;

/**
 * Liste des 7 opérations critiques (catalogue 5.5.1).
 * Fail-closed strict : si l'audit échoue, l'opération est refusée.
 * Exception : CONNEXION et ECHEC_CONNEXION sont fail-soft (N-2).
 * Ref. : D-03, N-2, N-4, P3-6.
 */
public enum OperationCritique {
    CONNEXION,
    ECHEC_CONNEXION,
    CHANGEMENT_MOT_DE_PASSE,
    ACTIVATION_RETRAIT_MFA,
    REVOCATION_SESSION,
    ACTION_APPAREIL,
    MODIFICATION_ROLE_PERMISSION,
    SUPPRESSION_VALIDATION_EXPORT,
    LECTURE_CHAMP_SENSIBLE;

    /** Opérations en fail-soft (audit perdu → l'opération continue). */
    public static final Set<OperationCritique> FAIL_SOFT = Set.of(
        CONNEXION, ECHEC_CONNEXION
    );

    /** Une opération est fail-closed strict si elle n'est pas en fail-soft. */
    public boolean isFailClosedStrict() {
        return !FAIL_SOFT.contains(this);
    }
}
