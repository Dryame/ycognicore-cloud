package bf.ycognicore.backend.service;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests MfaChallengeService (Redis usage unique, TTL 5 min).
 * Ref. : F1, T3.2.
 */
@Testcontainers
class MfaChallengeServiceIT {

    @Container
    static GenericContainer<?> redisContainer = new GenericContainer<>(
            DockerImageName.parse("redis:7-alpine"))
        .withExposedPorts(6379);

    static LettuceConnectionFactory factory;
    static MfaChallengeService service;

    @BeforeAll
    static void setUp() {
        factory = new LettuceConnectionFactory(
            redisContainer.getHost(), redisContainer.getFirstMappedPort());
        factory.afterPropertiesSet();
        StringRedisTemplate redis = new StringRedisTemplate(factory);
        redis.afterPropertiesSet();
        service = new MfaChallengeService(redis);
    }

    @AfterAll
    static void tearDown() {
        if (factory != null) factory.destroy();
    }

    @Test
    void create_consume_ok() {
        UUID userId = UUID.randomUUID();
        String token = service.create(userId, "demo001");

        assertThat(token).isNotBlank();

        MfaChallengeService.Challenge c = service.consume(token);
        assertThat(c).isNotNull();
        assertThat(c.userId()).isEqualTo(userId);
        assertThat(c.tenantCode()).isEqualTo("demo001");
    }

    @Test
    void usage_unique_double_consume_echoue() {
        String token = service.create(UUID.randomUUID(), "demo001");
        service.consume(token);
        assertThat(service.consume(token)).isNull();
    }

    @Test
    void token_inconnu_retourne_null() {
        assertThat(service.consume("token-inconnu")).isNull();
    }

    @Test
    void token_null_retourne_null() {
        assertThat(service.consume(null)).isNull();
        assertThat(service.consume("")).isNull();
    }
}
