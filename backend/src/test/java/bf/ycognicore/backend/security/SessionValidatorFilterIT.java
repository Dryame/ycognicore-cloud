package bf.ycognicore.backend.security;

import bf.ycognicore.backend.service.JwtService;
import bf.ycognicore.backend.service.TokenService;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import java.time.Duration;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests SessionValidatorFilter : 5 scenarios (public, valide, revoque, fail-closed, fail-open).
 * Ref. : D-04, D-13, F3, F5, R-a.
 */
@Testcontainers
class SessionValidatorFilterIT {

    private static final String SECRET =
        "test-secret-key-must-be-64-bytes-minimum-for-hs512-signing-xxxxxxxxxxxxxxxxxxxx";

    @Container
    static GenericContainer<?> redisContainer = new GenericContainer<>(
            DockerImageName.parse("redis:7-alpine"))
        .withExposedPorts(6379);

    static LettuceConnectionFactory factory;
    static StringRedisTemplate redis;
    static TokenService tokenService;
    static SessionValidatorFilter filter;

    @BeforeAll
    static void setUp() {
        JwtService jwtService = new JwtService(SECRET, 30L, 7L);
        tokenService = new TokenService(jwtService);

        factory = new LettuceConnectionFactory(
            redisContainer.getHost(), redisContainer.getFirstMappedPort());
        factory.afterPropertiesSet();
        redis = new StringRedisTemplate(factory);
        redis.afterPropertiesSet();

        filter = new SessionValidatorFilter(tokenService, redis);
    }

    @AfterAll
    static void tearDown() {
        if (factory != null) factory.destroy();
    }

    @Test
    void sans_token_passe() throws Exception {
        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/api/clients");
        MockHttpServletResponse res = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(req, res, chain);

        assertThat(res.getStatus()).isEqualTo(200);
        assertThat(chain.getRequest()).isNotNull();
    }

    @Test
    void session_valide_passe() throws Exception {
        String tenant = "demo001";
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();

        String token = tokenService.generateAccessToken(
            userId, "a@b.c", "INTERNE", tenant, List.of("ADMIN"), sessionId);

        redis.opsForValue().set("ycc:session:" + tenant + ":" + sessionId,
            "hash", Duration.ofHours(1));

        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/api/clients");
        req.addHeader("Authorization", "Bearer " + token);
        MockHttpServletResponse res = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(req, res, chain);

        assertThat(res.getStatus()).isEqualTo(200);
        assertThat(chain.getRequest()).isNotNull();
    }

    @Test
    void session_absente_redis_renvoie_401() throws Exception {
        String tenant = "demo001";
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();

        String token = tokenService.generateAccessToken(
            userId, "a@b.c", "INTERNE", tenant, List.of("ADMIN"), sessionId);
        // pas de clé Redis

        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/api/clients");
        req.addHeader("Authorization", "Bearer " + token);
        MockHttpServletResponse res = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(req, res, chain);

        assertThat(res.getStatus()).isEqualTo(401);
        assertThat(res.getContentAsString()).contains("Session");
    }

    @Test
    void token_sans_jti_passe_pour_compatibilite() throws Exception {
        String tenant = "demo001";
        // Token généré sans jti (ancienne API)
        String token = tokenService.generateAccessToken(
            UUID.randomUUID(), "a@b.c", "INTERNE", tenant, List.of("ADMIN"), null);

        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/api/clients");
        req.addHeader("Authorization", "Bearer " + token);
        MockHttpServletResponse res = new MockHttpServletResponse();
        MockFilterChain chain = new MockFilterChain();

        filter.doFilter(req, res, chain);

        assertThat(res.getStatus()).isEqualTo(200);
    }

    @Test
    void shouldNotFilter_exclut_login_et_actuator() {
        MockHttpServletRequest login = new MockHttpServletRequest("POST", "/api/auth/login");
        MockHttpServletRequest actuator = new MockHttpServletRequest("GET", "/actuator/health");
        MockHttpServletRequest normal = new MockHttpServletRequest("GET", "/api/clients");

        assertThat(filter.shouldNotFilter(login)).isTrue();
        assertThat(filter.shouldNotFilter(actuator)).isTrue();
        assertThat(filter.shouldNotFilter(normal)).isFalse();
    }
}
