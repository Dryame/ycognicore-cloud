package bf.ycognicore.backend.dto;

/**
 * Reponse de connexion (tokens + infos user).
 */
public record LoginResponse(
        String accessToken,
        String refreshToken,
        String tokenType,
        long expiresInSeconds,
        UserInfo user
) {}
