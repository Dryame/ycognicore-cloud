package bf.ycognicore.backend.dto;

/**
 * Reponse d'un setup MFA.
 * Le secret ne doit etre affiche qu'UNE SEULE FOIS a l'utilisateur.
 */
public record MfaSetupResponse(
        String secret,
        String qrUrl,
        String message
) {}
