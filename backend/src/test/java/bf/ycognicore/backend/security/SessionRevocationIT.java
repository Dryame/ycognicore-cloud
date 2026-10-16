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
 * Test T3.15 : revocation effective a la requete suivante.
 * Ref. : F3, F5, D-04, L7.1c.
 */
@Testcontainers
class SessionRevocationIT {

    private static final String SECRET =
        "test-secret-key-must-be-64-bytes-minimum-for-hs512-signing-xxxxxxxxxxxxxxxxxxxx";
    private static final String TENANT = "demo001";
    private static final String KEY_PREFIX = "ycc:session:";

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
    void revocation_effective_a_la_requete_suivante() throws Exception {
        String tenant = TENANT;
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();

        String token = tokenService.generateAccessToken(
            userId, "test@x.y", "INTERNE", tenant, List.of("INTERNE"), sessionId);

        // 1. Session active dans Redis -> filtre passe (200)
        redis.opsForValue().set(KEY_PREFIX + tenant + ":" + sessionId,
            "hash", Duration.ofHours(1));

        MockHttpServletRequest req1 = new MockHttpServletRequest("GET", "/api/clients");
        req1.addHeader("Authorization", "Bearer " + token);
        MockHttpServletResponse res1 = new MockHttpServletResponse();
        filter.doFilter(req1, res1, new MockFilterChain());

        assertThat(res1.getStatus()).as("Session active -> passe").isEqualTo(200);

        // 2. Revoquer (delete Redis)
        redis.delete(KEY_PREFIX + tenant + ":" + sessionId);

        // 3. Requete suivante -> 401
        MockHttpServletRequest req2 = new MockHttpServletRequest("GET", "/api/clients");
        req2.addHeader("Authorization", "Bearer " + token);
        MockHttpServletResponse res2 = new MockHttpServletResponse();
        filter.doFilter(req2, res2, new MockFilterChain());

        assertThat(res2.getStatus())
            .as("Session revoquee -> 401 a la requete suivante")
            .isEqualTo(401);
        assertThat(res2.getContentAsString()).contains("Session");
    }

    @Test
    void expiration_redis_rend_session_invalide() throws Exception {
        String tenant = TENANT;
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();

        String token = tokenService.generateAccessToken(
            userId, "test@x.y", "INTERNE", tenant, List.of("INTERNE"), sessionId);

        // Session avec TTL 1 seconde
        redis.opsForValue().set(KEY_PREFIX + tenant + ":" + sessionId,
            "hash", Duration.ofSeconds(1));

        // Attendre expiration
        Thread.sleep(2000);

        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/api/clients");
        req.addHeader("Authorization", "Bearer " + token);
        MockHttpServletResponse res = new MockHttpServletResponse();
        filter.doFilter(req, res, new MockFilterChain());

        assertThat(res.getStatus()).as("Session expiree -> 401").isEqualTo(401);
    }
}
