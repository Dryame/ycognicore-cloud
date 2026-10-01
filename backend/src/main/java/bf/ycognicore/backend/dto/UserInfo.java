package bf.ycognicore.backend.dto;

/**
 * Informations utilisateur renvoyees apres login.
 */
public record UserInfo(
        String userId,
        String email,
        String userType,
        String tenantCode,
        String redirectUrl
) {}
