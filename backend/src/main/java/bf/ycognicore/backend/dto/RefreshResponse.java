package bf.ycognicore.backend.dto;

public record RefreshResponse(
        String accessToken,
        String tokenType,
        long expiresInSeconds
) {}
