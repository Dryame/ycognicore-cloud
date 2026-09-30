package bf.ycognicore.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Point d'entrée principal de yCogniCore Cloud.
 *
 * @EnableScheduling active les tâches planifiées (maintenance partitions,
 * purge logs, rapports périodiques, etc.).
 *
 * Réf. : BL-005 (partitions automatiques)
 */
@SpringBootApplication
@EnableScheduling
public class BackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(BackendApplication.class, args);
    }
}
