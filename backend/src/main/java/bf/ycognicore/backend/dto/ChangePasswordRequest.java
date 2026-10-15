package bf.ycognicore.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Requete de changement de mot de passe (F4). */
public record ChangePasswordRequest(
    @NotBlank String ancienMotDePasse,
    @NotBlank @Size(min = 12, max = 128) String nouveauMotDePasse
) {}
