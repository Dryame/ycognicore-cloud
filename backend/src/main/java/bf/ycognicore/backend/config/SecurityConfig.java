package bf.ycognicore.backend.config;

import bf.ycognicore.backend.security.JwtAuthenticationFilter;
import bf.ycognicore.backend.service.JwtService;
import jakarta.annotation.PostConstruct;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.security.web.util.matcher.RequestMatcher;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private static final Logger logger = LoggerFactory.getLogger(SecurityConfig.class);

    @PostConstruct
    public void init() {
        logger.info("===== SecurityConfig BL-011 + CORS CHARGEE =====");
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of(
                "http://localhost:4200",
                "http://127.0.0.1:4200"
        ));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setExposedHeaders(List.of("Authorization"));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }

    @Bean
    public AuthenticationEntryPoint unauthorizedEntryPoint() {
        return (request, response, authException) -> {
            logger.warn("401 sur {} {} : {}",
                    request.getMethod(), request.getRequestURI(),
                    authException.getMessage());
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Authentification requise");
        };
    }

    @Bean
    public AccessDeniedHandler forbiddenHandler() {
        return (request, response, accessDeniedException) -> {
            logger.warn("403 sur {} {} : {}",
                    request.getMethod(), request.getRequestURI(),
                    accessDeniedException.getMessage());
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Acces refuse");
        };
    }

    private static RequestMatcher exact(String path, String method) {
        return request -> path.equals(request.getRequestURI())
                && method.equalsIgnoreCase(request.getMethod());
    }

    private static RequestMatcher prefix(String pathPrefix) {
        return request -> request.getRequestURI().startsWith(pathPrefix);
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http, JwtService jwtService)
            throws Exception {

        logger.info("Construction SecurityFilterChain BL-011 + CORS");

        JwtAuthenticationFilter jwtFilter = new JwtAuthenticationFilter(jwtService);

        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .csrf(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                .logout(AbstractHttpConfigurer::disable)
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint(unauthorizedEntryPoint())
                        .accessDeniedHandler(forbiddenHandler())
                )
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers(exact("/api/auth/login", "POST")).permitAll()
                        .requestMatchers(exact("/api/auth/refresh", "POST")).permitAll()
                        .requestMatchers(exact("/api/auth/me", "GET")).permitAll()
                        .requestMatchers(prefix("/api/_poc")).permitAll()
                        .requestMatchers(prefix("/api/admin/partitions")).permitAll()
                        .requestMatchers(prefix("/actuator")).permitAll()
                        .requestMatchers(prefix("/error")).permitAll()
                        .anyRequest().authenticated()
                )
                .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}
