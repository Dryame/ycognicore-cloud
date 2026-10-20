package bf.ycognicore.backend.service;

import bf.ycognicore.backend.entity.controlplane.ClesTenant;
import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Duration;
import java.util.UUID;

/**
 * Cache des cles de chiffrement dechiffrees (D-P4-7).
 * TTL 5 min, max 1000 entrees, isolation tenant par cle.
 * Ref. : P4 L2, D-P4-7, ADR-043.
 */
@Configuration
public class DataKeyCacheConfig {

    public static final int TTL_MINUTES = 5;
    public static final int MAX_ENTRIES = 1000;

    @Bean(name = "dataKeyCache")
    public Cache<CacheKey, byte[]> dataKeyCache() {
        return Caffeine.newBuilder()
            .expireAfterWrite(Duration.ofMinutes(TTL_MINUTES))
            .maximumSize(MAX_ENTRIES)
            .recordStats()
            .build();
    }

    /** Cle de cache : (tenant, type, version) — pas de fuite cross-tenant. */
    public record CacheKey(UUID tenantId, ClesTenant.TypeCle typeCle, int version) {}
}
