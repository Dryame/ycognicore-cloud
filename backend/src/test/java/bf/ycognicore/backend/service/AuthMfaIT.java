package bf.ycognicore.backend.service;

import bf.ycognicore.backend.dto.LoginResponse;
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
 * Tests MfaChallengeService + LoginResponse.mfaRequired (integration).
 * Ref. : F1, T3.2.
 */
@Testcontainers
class AuthMfaIT {

    @Container
    static GenericContainer<?> redisContainer = new GenericContainer<>(
            DockerImageName.parse("redis:7-alpine"))
        .withExposedPorts(6379);

    static LettuceConnectionFactory factory;
    static MfaChallengeService challengeService;

    @BeforeAll
    static void setUp() {
        factory = new LettuceConnectionFactory(
            redisContainer.getHost(), redisContainer.getFirstMappedPort());
        factory.afterPropertiesSet();
        StringRedisTemplate redis = new StringRedisTemplate(factory);
        redis.afterPropertiesSet();
        challengeService = new MfaChallengeService(redis);
    }

    @AfterAll
    static void tearDown() {
        if (factory != null) factory.destroy();
    }

    @Test
    void loginResponse_mfaRequired_factory() {
        LoginResponse r = LoginResponse.mfaRequired("challenge-xyz", null);
        assertThat(r.mfaRequired()).isTrue();
        assertThat(r.challengeToken()).isEqualTo("challenge-xyz");
        assertThat(r.accessToken()).isNull();
        assertThat(r.refreshToken()).isNull();
    }

    @Test
    void loginResponse_compat_5_args_reste_valide() {
        LoginResponse r = new LoginResponse("a", "r", "Bearer", 3600, null);
        assertThat(r.mfaRequired()).isFalse();
        assertThat(r.challengeToken()).isNull();
        assertThat(r.accessToken()).isEqualTo("a");
    }

    @Test
    void challenge_lie_au_user_et_tenant() {
        UUID userId = UUID.randomUUID();
        String token = challengeService.create(userId, "demo001");
        MfaChallengeService.Challenge c = challengeService.consume(token);
        assertThat(c.userId()).isEqualTo(userId);
        assertThat(c.tenantCode()).isEqualTo("demo001");
    }
}
