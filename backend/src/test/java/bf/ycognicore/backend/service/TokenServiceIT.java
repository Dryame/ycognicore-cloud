package bf.ycognicore.backend.service;

import io.jsonwebtoken.Claims;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests TokenService : jti, rotation, hash.
 * Pas de Spring : instanciation directe, pas de Testcontainers.
 * Ref. : D-13, F2, F3.
 */
class TokenServiceIT {

    private static final String SECRET =
        "test-secret-key-must-be-64-bytes-minimum-for-hs512-signing-xxxxxxxxxxxxxxxxxxxx";

    private JwtService jwtService;
    private TokenService tokenService;

    @BeforeEach
    void setUp() {
        jwtService = new JwtService(SECRET, 30L, 7L);
        tokenService = new TokenService(jwtService);
    }

    @Test
    void access_token_contient_jti_sessionId() {
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();

        String token = tokenService.generateAccessToken(
            userId, "a@b.c", "INTERNE", "demo001",
            List.of("ADMIN"), sessionId);

        assertThat(token).isNotBlank();
        String jti = tokenService.extractJti(token);
        assertThat(jti).isEqualTo(sessionId.toString());
    }

    @Test
    void access_token_sans_sessionId_n_a_pas_de_jti() {
        String token = tokenService.generateAccessToken(
            UUID.randomUUID(), "a@b.c", "INTERNE", "demo001",
            List.of("ADMIN"), null);

        assertThat(tokenService.extractJti(token)).isNull();
    }

    @Test
    void refresh_token_contient_sessionId_et_nonce() {
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();

        String refresh = tokenService.generateRefreshToken(userId, sessionId);
        String jti = tokenService.extractJti(refresh);

        assertThat(jti).startsWith(sessionId.toString() + ":");
        assertThat(tokenService.extractSessionId(jti)).isEqualTo(sessionId);
    }

    @Test
    void deux_refresh_tokens_du_meme_utilisateur_ont_des_jti_differents() {
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();

        String t1 = tokenService.generateRefreshToken(userId, sessionId);
        String t2 = tokenService.generateRefreshToken(userId, sessionId);

        assertThat(tokenService.extractJti(t1))
            .isNotEqualTo(tokenService.extractJti(t2));
    }

    @Test
    void hash_token_est_deterministe_et_different_par_token() {
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();

        String t1 = tokenService.generateRefreshToken(userId, sessionId);
        String t2 = tokenService.generateRefreshToken(userId, sessionId);

        assertThat(tokenService.hashToken(t1)).isEqualTo(tokenService.hashToken(t1));
        assertThat(tokenService.hashToken(t1)).isNotEqualTo(tokenService.hashToken(t2));
        assertThat(tokenService.hashToken(t1)).hasSize(64);
    }

    @Test
    void compatibilite_avec_les_methodes_actuelles_de_jwtService() {
        String legacy = jwtService.generateAccessToken(
            UUID.randomUUID().toString(), "a@b.c", "INTERNE", "demo001", List.of("ADMIN"));
        Claims c = jwtService.parseToken(legacy);
        assertThat(c.get("tenantCode")).isEqualTo("demo001");
        assertThat(c.getId()).isNull();  // pas de jti
    }
}
