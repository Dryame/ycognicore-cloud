package bf.ycognicore.backend.dto;

/**
 * Reponse de refresh : nouvel access + nouveau refresh (rotation D-13).
 * Le champ refreshToken peut etre null (compat ascendante).
 */
public record RefreshResponse(
    String accessToken,
    String tokenType,
    long expiresInSeconds,
    String refreshToken
) {
    /** Constructeur compat (sans rotation). */
    public RefreshResponse(String accessToken, String tokenType, long expiresInSeconds) {
        this(accessToken, tokenType, expiresInSeconds, null);
    }
}
