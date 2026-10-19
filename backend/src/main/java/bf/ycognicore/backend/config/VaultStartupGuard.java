package bf.ycognicore.backend.config;

import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

/**
 * Garde-fou : refuse le demarrage si Vault -dev est utilise en prod.
 * Ref. : P4, D-P4-6.
 */
@Component
public class VaultStartupGuard {

    private static final Logger log = LoggerFactory.getLogger(VaultStartupGuard.class);

    private final Environment env;

    @Value("${YCC_VAULT_MODE:${ycc.vault.mode:dev}}")
    private String vaultMode;

    public VaultStartupGuard(Environment env) {
        this.env = env;
    }

    @PostConstruct
    void check() {
        // Lire le profil via Environment (fiable, contrairement a @Value)
        String[] activeProfiles = env.getActiveProfiles();
        if (activeProfiles.length == 0) {
            activeProfiles = env.getDefaultProfiles();
        }
        boolean isProd = false;
        for (String p : activeProfiles) {
            if (p.contains("prod") || p.contains("production")) {
                isProd = true;
                break;
            }
        }

        boolean isDevVault = "dev".equalsIgnoreCase(vaultMode);

        log.info("VaultStartupGuard : profiles={} vaultMode={} isProd={} isDevVault={}",
            String.join(",", activeProfiles), vaultMode, isProd, isDevVault);

        if (isProd && isDevVault) {
            String msg = "SECURITE : Vault en mode '-dev' interdit en production. " +
                "Configurer YCC_VAULT_MODE=prod avec un backend persistant. " +
                "Un restart Vault rendrait TOUTES les donnees chiffrees irrecuperables.";
            log.error(msg);
            throw new IllegalStateException(msg);
        }

        if (isDevVault) {
            log.warn("Vault en mode -dev : les cles seront perdues au restart. " +
                "Executer scripts/init-vault.sh apres chaque restart.");
        }
    }
}
