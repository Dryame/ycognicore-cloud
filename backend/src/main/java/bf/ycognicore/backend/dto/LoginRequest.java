package bf.ycognicore.backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

/**
 * Requete de connexion (Auth Dispatcher).
 * tenantCode : null pour Superadmin, renseigne pour tenant.
 * Ref. : NFR-SEC-06
 */
public record LoginRequest(
        @Email @NotBlank String email,
        @NotBlank String password,
        String tenantCode
) {}
