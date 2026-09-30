package bf.ycognicore.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Configuration Spring Security — version minimale.
 *
 * NOTE TEMPORAIRE : l'endpoint /api/admin/partitions/** est ouvert
 * sans authentification pour permettre les tests d'intégration du BL-005.
 *
 * À SÉCURISER dans un ADR ultérieur (RBAC Superadmin / clé API).
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                // Endpoints de test ouverts temporairement
                .requestMatchers("/api/admin/partitions/**").permitAll()
                // Actuator (si présent)
                .requestMatchers("/actuator/**").permitAll()
                // Tout le reste nécessite une authentification
                .anyRequest().authenticated()
            );

        return http.build();
    }
}
