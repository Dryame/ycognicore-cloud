package bf.ycognicore.backend.service;

import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/**
 * Gestion des sessions actives : création, index Redis, révocation.
 * Redis = index de validité (F3, D-04).
 * Base = trace persistante (F5, audit).
 * Ref. : D-04, P-01, F3, F4, F5.
 */
@Service
public class SessionService {

    private static final Logger log = LoggerFactory.getLogger(SessionService.class);
    private static final String KEY_PREFIX = "ycc:session:";

    private final MultiTenantConnectionProviderImpl connectionProvider;
    private final SessionPolicyService policyService;
    private final TokenService tokenService;
    private final StringRedisTemplate redis;

    public SessionService(MultiTenantConnectionProviderImpl connectionProvider,
                          SessionPolicyService policyService,
                          TokenService tokenService,
                          StringRedisTemplate redis) {
        this.connectionProvider = connectionProvider;
        this.policyService = policyService;
        this.tokenService = tokenService;
        this.redis = redis;
    }

    /** Crée une nouvelle session, enregistre en base + Redis. */
    public UUID create(String tenantCode, UUID userId, String ip, String userAgent,
                       UUID appareilId, String refreshToken) {
        SessionPolicy policy = policyService.forTenant(tenantCode);
        UUID sessionId = UUID.randomUUID();
        OffsetDateTime now = OffsetDateTime.now();
        OffsetDateTime expiration = now.plusHours(policy.dureeAbsolueHeures());
        String refreshHash = tokenService.hashToken(refreshToken);

        // 1. Enregistrer en base
        try (Connection conn = connectionProvider.getConnection(tenantCode);
             PreparedStatement ps = conn.prepareStatement(
                 "INSERT INTO sessions_actives " +
                 "(id, user_id, token_hash, refresh_token_hash, appareil_id, ip, user_agent, " +
                 " date_ouverture, date_derniere_activite, date_expiration, statut) " +
                 "VALUES (?, ?, ?, ?, ?, ?::inet, ?, ?, ?, ?, 'ACTIVE')")) {
            ps.setObject(1, sessionId);
            ps.setObject(2, userId);
            ps.setString(3, "");                    // token_hash sera mis à jour au login
            ps.setString(4, refreshHash);
            ps.setObject(5, appareilId);
            ps.setString(6, ip);
            ps.setString(7, userAgent);
            ps.setObject(8, now);
            ps.setObject(9, now);
            ps.setObject(10, expiration);
            ps.executeUpdate();
        } catch (Exception e) {
            throw new SessionException("Création session échouée", e);
        }

        // 2. Index Redis
        String key = redisKey(tenantCode, sessionId);
        try {
            redis.opsForValue().set(key, refreshHash,
                Duration.ofDays(policy.refreshTokenJours()));
        } catch (Exception e) {
            // rollback base
            try (Connection conn = connectionProvider.getConnection(tenantCode);
                 PreparedStatement ps = conn.prepareStatement(
                     "UPDATE sessions_actives SET statut='REVOQUEE', date_fermeture=now(), " +
                     "motif_fermeture='EXPIRATION' WHERE id=?")) {
                ps.setObject(1, sessionId);
                ps.executeUpdate();
            } catch (Exception ignored) {}
            throw new SessionException("Redis indisponible — session annulée", e);
        }

        // 3. Appliquer sessions_max (F4) — invalider la plus ancienne si dépassement
        enforceMaxSessions(tenantCode, userId, policy.sessionsMax());

        return sessionId;
    }

    /** Vérifie si une session est active (Redis). Retourne null si absente. */
    public String isActiveAndRefreshHash(String tenantCode, UUID sessionId) {
        try {
            return redis.opsForValue().get(redisKey(tenantCode, sessionId));
        } catch (Exception e) {
            throw new SessionException("Redis indisponible", e);
        }
    }

    /** Touch : met à jour date_derniere_activite si > 60 s depuis dernier touch. */
    public void touch(String tenantCode, UUID sessionId) {
        try (Connection conn = connectionProvider.getConnection(tenantCode);
             PreparedStatement ps = conn.prepareStatement(
                 "UPDATE sessions_actives SET date_derniere_activite = now() " +
                 "WHERE id = ? AND date_derniere_activite < now() - interval '60 seconds'")) {
            ps.setObject(1, sessionId);
            ps.executeUpdate();
        } catch (Exception e) {
            log.debug("touch échoué {} : {}", sessionId, e.getMessage());
        }
    }

    /** Révocation individuelle (F3). */
    public void revoke(String tenantCode, UUID sessionId, String motif) {
        try (Connection conn = connectionProvider.getConnection(tenantCode);
             PreparedStatement ps = conn.prepareStatement(
                 "UPDATE sessions_actives SET statut='REVOQUEE', date_fermeture=now(), " +
                 "motif_fermeture=? WHERE id=? AND statut='ACTIVE'")) {
            ps.setString(1, motif);
            ps.setObject(2, sessionId);
            ps.executeUpdate();
        } catch (Exception e) {
            throw new SessionException("Révocation échouée", e);
        }
        redis.delete(redisKey(tenantCode, sessionId));
    }

    /** Révocation globale d'un utilisateur (F3), sauf session courante si gardée. */
    public void revokeAll(String tenantCode, UUID userId, String motif, UUID exceptSessionId) {
        List<UUID> ids;
        try (Connection conn = connectionProvider.getConnection(tenantCode);
             PreparedStatement ps = conn.prepareStatement(
                 "UPDATE sessions_actives SET statut='REVOQUEE', date_fermeture=now(), " +
                 "motif_fermeture=? WHERE user_id=? AND statut='ACTIVE' " +
                 "AND (?::uuid IS NULL OR id <> ?::uuid) RETURNING id")) {
            ps.setString(1, motif);
            ps.setObject(2, userId);
            ps.setObject(3, exceptSessionId);
            ps.setObject(4, exceptSessionId);
            var rs = ps.executeQuery();
            ids = new java.util.ArrayList<>();
            while (rs.next()) ids.add((UUID) rs.getObject(1));
        } catch (Exception e) {
            throw new SessionException("Révocation globale échouée", e);
        }
        for (UUID id : ids) {
            try { redis.delete(redisKey(tenantCode, id)); } catch (Exception ignored) {}
        }
    }

    /** Rotation du refresh : vérifie l'ancien hash, en écrit un nouveau. */
    public void rotateRefresh(String tenantCode, UUID sessionId, String newRefreshToken) {
        String newHash = tokenService.hashToken(newRefreshToken);
        try (Connection conn = connectionProvider.getConnection(tenantCode);
             PreparedStatement ps = conn.prepareStatement(
                 "UPDATE sessions_actives SET refresh_token_hash=? " +
                 "WHERE id=? AND statut='ACTIVE'")) {
            ps.setString(1, newHash);
            ps.setObject(2, sessionId);
            if (ps.executeUpdate() != 1) {
                throw new SessionException("Rotation : session introuvable ou inactive");
            }
        } catch (Exception e) {
            throw new SessionException("Rotation refresh échouée", e);
        }
        SessionPolicy policy = policyService.forTenant(tenantCode);
        redis.opsForValue().set(redisKey(tenantCode, sessionId), newHash,
            Duration.ofDays(policy.refreshTokenJours()));
    }

    /** Invalide les sessions les plus anciennes si sessions_max dépassé. */
    private void enforceMaxSessions(String tenantCode, UUID userId, int max) {
        try (Connection conn = connectionProvider.getConnection(tenantCode);
             PreparedStatement ps = conn.prepareStatement(
                 "UPDATE sessions_actives SET statut='REVOQUEE', date_fermeture=now(), " +
                 "motif_fermeture='REVOCATION_ADMIN' " +
                 "WHERE id IN (" +
                 "  SELECT id FROM sessions_actives WHERE user_id=? AND statut='ACTIVE' " +
                 "  ORDER BY date_ouverture DESC OFFSET ?) RETURNING id")) {
            ps.setObject(1, userId);
            ps.setInt(2, max);
            var rs = ps.executeQuery();
            while (rs.next()) {
                try { redis.delete(redisKey(tenantCode, (UUID) rs.getObject(1))); }
                catch (Exception ignored) {}
            }
        } catch (Exception e) {
            log.warn("enforceMaxSessions échoué : {}", e.getMessage());
        }
    }

    private static String redisKey(String tenantCode, UUID sessionId) {
        return KEY_PREFIX + tenantCode + ":" + sessionId;
    }

    public static class SessionException extends RuntimeException {
        public SessionException(String m) { super(m); }
        public SessionException(String m, Throwable c) { super(m, c); }
    }
}
