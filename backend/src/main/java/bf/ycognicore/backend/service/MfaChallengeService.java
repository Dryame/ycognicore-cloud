package bf.ycognicore.backend.service;

import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.UUID;

/**
 * Challenge MFA ephemeral : userId + tenantCode stocke en Redis (TTL 5 min).
 * Usage unique (GETDEL atomique). Ref. : F1, T3.2.
 */
@Service
public class MfaChallengeService {

    private static final String KEY_PREFIX = "ycc:mfa:challenge:";
    private static final Duration TTL = Duration.ofMinutes(5);

    private final StringRedisTemplate redis;

    public MfaChallengeService(StringRedisTemplate redis) {
        this.redis = redis;
    }

    /** Cree un challenge et retourne son token opaque. */
    public String create(UUID userId, String tenantCode) {
        String token = UUID.randomUUID().toString();
        redis.opsForValue().set(KEY_PREFIX + token,
            userId + ":" + tenantCode, TTL);
        return token;
    }

    /** Consomme (GETDEL) le challenge. Retourne null si absent/expire. */
    public Challenge consume(String token) {
        if (token == null || token.isBlank()) return null;
        String value = redis.opsForValue().getAndDelete(KEY_PREFIX + token);
        if (value == null) return null;
        int idx = value.indexOf(':');
        if (idx < 0) return null;
        try {
            return new Challenge(UUID.fromString(value.substring(0, idx)),
                value.substring(idx + 1));
        } catch (Exception e) {
            return null;
        }
    }

    public record Challenge(UUID userId, String tenantCode) {}
}
