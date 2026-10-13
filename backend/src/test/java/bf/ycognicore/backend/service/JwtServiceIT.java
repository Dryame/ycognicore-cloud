package bf.ycognicore.backend.service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Tests du service JWT : génération, parsing, validation.
 *
 * Ref. : T1.2, M33, M41, exigences 2.2 et 3.2.
 */
class JwtServiceIT {

    // Secret ≥ 512 bits (64 octets) requis pour HS512
    static final String SECRET =
            "test-secret-key-must-be-at-least-64-bytes-long-for-hmac-sha512-signing-xxxxxxxx";

    // Second secret distinct, également ≥ 512 bits
    static final String AUTRE_SECRET =
            "different-secret-key-must-also-be-at-least-64-bytes-long-for-hmac-sha512-yyyyyyy";

    JwtService jwtService;

    @BeforeEach
    void setUp() {
        // Constructeur : JwtService(secret, accessMinutes, refreshDays)
        jwtService = new JwtService(SECRET, 30L, 7L);
    }

    @Test
    void genere_un_access_token_et_le_parse() {
        String userId = "user-001";
        String email = "user@example.com";
        String userType = "INTERNE";
        String tenantCode = "demo001";
        List<String> roles = List.of("ADMIN", "USER");

        String token = jwtService.generateAccessToken(userId, email, userType, tenantCode, roles);

        assertThat(token).isNotBlank();

        Claims claims = jwtService.parseToken(token);
        assertThat(claims).isNotNull();
        assertThat(claims.getSubject()).isEqualTo(userId);
        assertThat(claims.get("email", String.class)).isEqualTo(email);
    }

    @Test
    void genere_un_refresh_token() {
        String token = jwtService.generateRefreshToken("user-002");
        assertThat(token).isNotBlank();
    }

    @Test
    void refuse_un_token_avec_signature_invalide() {
        JwtService autreService = new JwtService(AUTRE_SECRET, 30L, 7L);

        String token = autreService.generateAccessToken(
                "u", "e@e.com", "I", "t", List.of());

        assertThatThrownBy(() -> jwtService.parseToken(token))
                .isInstanceOf(JwtException.class);
    }

    @Test
    void expose_la_duree_de_vie_des_access_tokens() {
        // 30 minutes = 1800 secondes
        assertThat(jwtService.getAccessTtlSeconds()).isEqualTo(1800L);
    }

    @Test
    void refuse_un_token_malforme() {
        assertThatThrownBy(() -> jwtService.parseToken("not-a-valid-token"))
                .isInstanceOf(JwtException.class);
    }
}
