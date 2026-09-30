package bf.ycognicore.backend.config;

import org.flywaydb.core.Flyway;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.sql.DataSource;

/**
 * Configuration Flyway explicite.
 *
 * Spring Boot 4 modularise ses auto-configurations et ne fournit plus
 * de starter Flyway dédié. Ce bean garantit l'exécution des migrations
 * au démarrage.
 *
 * Réf. : ADR-008 (Spring Boot 4), ADR-010 (à créer)
 */
@Configuration
public class FlywayConfig {

    private static final Logger logger = LoggerFactory.getLogger(FlywayConfig.class);

    @Value("${spring.flyway.locations:classpath:db/migration/control-plane}")
    private String[] locations;

    @Value("${spring.flyway.baseline-on-migrate:true}")
    private boolean baselineOnMigrate;

    @Value("${spring.flyway.baseline-version:0}")
    private String baselineVersion;

    @Bean(initMethod = "migrate")
    @ConditionalOnMissingBean(Flyway.class)
    public Flyway flyway(DataSource dataSource) {
        logger.info("=== Initialisation Flyway (config explicite) ===");
        logger.info("  Locations : {}", String.join(", ", locations));
        logger.info("  Baseline  : {} (version {})", baselineOnMigrate, baselineVersion);

        Flyway flyway = Flyway.configure()
                .dataSource(dataSource)
                .locations(locations)
                .baselineOnMigrate(baselineOnMigrate)
                .baselineVersion(baselineVersion)
                .validateOnMigrate(true)
                .outOfOrder(false)
                .cleanDisabled(true)
                .load();

        logger.info("=== Flyway prêt — {} migrations détectées ===",
                    flyway.info().all().length);
        return flyway;
    }
}
