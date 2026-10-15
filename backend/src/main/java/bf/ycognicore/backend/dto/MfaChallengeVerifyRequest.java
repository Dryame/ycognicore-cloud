package bf.ycognicore.backend.dto;

import jakarta.validation.constraints.NotBlank;

/** Requete de verification MFA par challenge (F1, L3.4). */
public record MfaChallengeVerifyRequest(
    @NotBlank String challengeToken,
    @NotBlank String code
) {}
