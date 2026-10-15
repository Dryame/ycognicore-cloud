package bf.ycognicore.backend.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

/** Requete de verification MFA (ancien flux — secret en clair, BL-012). */
public record MfaVerifyRequest(
    @NotBlank String secret,
    @Min(100000) @Max(999999) int code
) {}
