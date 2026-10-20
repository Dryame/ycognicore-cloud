package bf.ycognicore.backend.config;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class VaultStartupGuardTest {

    @Test
    void refuse_prod_avec_vault_dev() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");
        VaultStartupGuard guard = new VaultStartupGuard(env);
        // Injection manuelle du mode via réflexion ou setter si pas de setter
        // Ici on utilise la réflexion pour forcer le mode "dev"
        org.springframework.test.util.ReflectionTestUtils.setField(guard, "vaultMode", "dev");

        assertThatThrownBy(guard::check)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Vault en mode '-dev' interdit en production");
    }

    @Test
    void accepte_dev_avec_vault_dev() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("dev");
        VaultStartupGuard guard = new VaultStartupGuard(env);
        org.springframework.test.util.ReflectionTestUtils.setField(guard, "vaultMode", "dev");

        assertThatCode(guard::check).doesNotThrowAnyException();
    }
}
