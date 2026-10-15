package bf.ycognicore.backend.dto;

/**
 * Reponse de connexion (tokens + infos user).
 * Si mfaRequired=true, accessToken/refreshToken sont null.
 * Ref. : F1, F2, T3.2.
 */
public record LoginResponse(
    String accessToken,
    String refreshToken,
    String tokenType,
    long expiresInSeconds,
    UserInfo user,
    Boolean mfaRequired,
    String challengeToken
) {
    /** Constructeur de compatibilite (sans MFA). */
    public LoginResponse(String accessToken, String refreshToken, String tokenType,
                         long expiresInSeconds, UserInfo user) {
        this(accessToken, refreshToken, tokenType, expiresInSeconds, user, false, null);
    }

    /** Reponse MFA requise (pas de tokens). */
    public static LoginResponse mfaRequired(String challengeToken, UserInfo user) {
        return new LoginResponse(null, null, null, 0, user, true, challengeToken);
    }
}
