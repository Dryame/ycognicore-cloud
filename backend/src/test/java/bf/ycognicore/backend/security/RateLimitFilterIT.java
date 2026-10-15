package bf.ycognicore.backend.security;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
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

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests RateLimitFilter : seuils, 429, shouldNotFilter.
 * Ref. : F7, T3.6, D-05.
 */
@Testcontainers
class RateLimitFilterIT {

    @Container
    static GenericContainer<?> redisContainer = new GenericContainer<>(
            DockerImageName.parse("redis:7-alpine"))
        .withExposedPorts(6379);

    static LettuceConnectionFactory factory;
    static StringRedisTemplate redis;
    static RateLimitFilter filter;

    @BeforeAll
    static void setUp() {
        factory = new LettuceConnectionFactory(
            redisContainer.getHost(), redisContainer.getFirstMappedPort());
        factory.afterPropertiesSet();
        redis = new StringRedisTemplate(factory);
        redis.afterPropertiesSet();
        filter = new RateLimitFilter(redis);
    }

    @AfterEach
    void flush() {
        redis.getConnectionFactory().getConnection().serverCommands().flushAll();
    }

    @AfterAll
    static void tearDown() {
        if (factory != null) factory.destroy();
    }

    @Test
    void sous_le_seuil_passe() throws Exception {
        MockHttpServletRequest req = new MockHttpServletRequest("POST", "/api/auth/login");
        req.setRemoteAddr("10.0.0.1");
        MockHttpServletResponse res = new MockHttpServletResponse();
        filter.doFilter(req, res, new MockFilterChain());
        assertThat(res.getStatus()).isNotEqualTo(429);
    }

    @Test
    void au_dela_du_seuil_renvoie_429() throws Exception {
        MockHttpServletRequest req;
        MockHttpServletResponse res = new MockHttpServletResponse();
        for (int i = 0; i < 11; i++) {
            req = new MockHttpServletRequest("POST", "/api/auth/login");
            req.setRemoteAddr("10.0.0.2");
            res = new MockHttpServletResponse();
            filter.doFilter(req, res, new MockFilterChain());
        }
        assertThat(res.getStatus()).isEqualTo(429);
        assertThat(res.getHeader("Retry-After")).isEqualTo("60");
    }

    @Test
    void routes_actuator_exclues() {
        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/actuator/health");
        assertThat(filter.shouldNotFilter(req)).isTrue();
    }
}
