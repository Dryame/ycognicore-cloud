package bf.ycognicore.backend.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * Requete de verification MFA.
 * Le secret est celui retourne par /setup (non encore stocke en base).
 */
public record MfaVerifyRequest(
        @NotBlank String secret,
        @NotNull @Min(0) @Max(999999) Integer code
) {}
