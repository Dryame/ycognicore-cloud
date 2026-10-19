package bf.ycognicore.backend.config;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Tests VaultStartupGuard (logique pure, sans Spring contexte).
 * Ref. : P4 D-P4-6.
 */
class VaultStartupGuardTest {

    @Test
    void prod_et_vault_dev_doit_crasher() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");
        VaultStartupGuard guard = new VaultStartupGuard(env);
        ReflectionTestUtils.setField(guard, "vaultMode", "dev");

        assertThatThrownBy(guard::check)
            .isInstanceOf(IllegalStateException.class)
            .hasMessageContaining("SECURITE")
            .hasMessageContaining("-dev");
    }

    @Test
    void prod_et_vault_prod_ne_crashe_pas() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");
        VaultStartupGuard guard = new VaultStartupGuard(env);
        ReflectionTestUtils.setField(guard, "vaultMode", "prod");

        assertThatCode(guard::check).doesNotThrowAnyException();
    }

    @Test
    void dev_et_vault_dev_ne_crashe_pas() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("dev");
        VaultStartupGuard guard = new VaultStartupGuard(env);
        ReflectionTestUtils.setField(guard, "vaultMode", "dev");

        assertThatCode(guard::check).doesNotThrowAnyException();
    }

    @Test
    void production_et_vault_dev_doit_crasher() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("production");
        VaultStartupGuard guard = new VaultStartupGuard(env);
        ReflectionTestUtils.setField(guard, "vaultMode", "dev");

        assertThatThrownBy(guard::check)
            .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void aucun_profil_actif_ne_crashe_pas() {
        MockEnvironment env = new MockEnvironment();
        VaultStartupGuard guard = new VaultStartupGuard(env);
        ReflectionTestUtils.setField(guard, "vaultMode", "dev");

        assertThatCode(guard::check).doesNotThrowAnyException();
    }
}
