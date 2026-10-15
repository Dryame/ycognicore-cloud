package bf.ycognicore.backend.service;

import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;

/**
 * Cycle de vie des appareils (F6).
 * Empreinte = SHA-256(user-agent + accept-language). Pas d'IP (mobile).
 * Ref. : F6, T3.5.
 */
@Service
public class DeviceService {

    private static final Logger log = LoggerFactory.getLogger(DeviceService.class);

    private final MultiTenantConnectionProviderImpl connectionProvider;

    public DeviceService(MultiTenantConnectionProviderImpl connectionProvider) {
        this.connectionProvider = connectionProvider;
    }

    /** Empreinte stable : SHA-256(userAgent + '|' + acceptLanguage). */
    public static String fingerprint(String userAgent, String acceptLanguage) {
        String raw = nz(userAgent) + "|" + nz(acceptLanguage);
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(md.digest(raw.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 indisponible", e);
        }
    }

    /** Retourne l'appareil existant ou le cree. */
    public UUID resolveOrCreate(String tenantCode, UUID userId, String userAgent,
                                String acceptLanguage, String ip) {
        String empreinte = fingerprint(userAgent, acceptLanguage);
        try (Connection conn = connectionProvider.getConnection(tenantCode)) {
            // 1. Chercher
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT id, statut FROM appareils WHERE user_id=? AND empreinte=?")) {
                ps.setObject(1, userId);
                ps.setString(2, empreinte);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        UUID id = (UUID) rs.getObject(1);
                        String statut = rs.getString(2);
                        if ("BLOQUE".equals(statut) || "SUPPRIME".equals(statut)) {
                            throw new DeviceBlockedException("Appareil " + statut.toLowerCase());
                        }
                        try (PreparedStatement upd = conn.prepareStatement(
                                "UPDATE appareils SET derniere_vue=now() WHERE id=?")) {
                            upd.setObject(1, id);
                            upd.executeUpdate();
                        }
                        return id;
                    }
                }
            }
            // 2. Creer
            UUID deviceId = UUID.randomUUID();
            try (PreparedStatement ps = conn.prepareStatement(
                    "INSERT INTO appareils " +
                    "(id, user_id, navigateur, empreinte, statut, premiere_vue, derniere_vue, date_creation, created_by) " +
                    "VALUES (?, ?, ?, ?, 'AUTORISE', now(), now(), now(), ?)")) {
                ps.setObject(1, deviceId);
                ps.setObject(2, userId);
                ps.setString(3, truncate(userAgent, 100));
                ps.setString(4, empreinte);
                ps.setObject(5, userId);
                ps.executeUpdate();
            }
            log.info("Appareil cree user={} device={}", userId, deviceId);
            return deviceId;
        } catch (DeviceBlockedException e) {
            throw e;
        } catch (Exception e) {
            throw new RuntimeException("resolveOrCreate appareil echoue", e);
        }
    }

    /** Bloque un appareil (F6). */
    public void block(String tenantCode, UUID deviceId) {
        try (Connection conn = connectionProvider.getConnection(tenantCode);
             PreparedStatement ps = conn.prepareStatement(
                 "UPDATE appareils SET statut='BLOQUE' WHERE id=? AND statut<>'BLOQUE'")) {
            ps.setObject(1, deviceId);
            if (ps.executeUpdate() == 0) {
                throw new IllegalArgumentException("Appareil introuvable ou deja bloque");
            }
        } catch (Exception e) {
            throw new RuntimeException("Blocage appareil echoue", e);
        }
    }

    /** Retourne l'appareil bloque (pour tests). */
    public Optional<String> findStatut(String tenantCode, UUID deviceId) {
        try (Connection conn = connectionProvider.getConnection(tenantCode);
             PreparedStatement ps = conn.prepareStatement(
                 "SELECT statut FROM appareils WHERE id=?")) {
            ps.setObject(1, deviceId);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? Optional.of(rs.getString(1)) : Optional.empty();
            }
        } catch (Exception e) {
            return Optional.empty();
        }
    }

    private static String nz(String s) { return s == null ? "" : s; }
    private static String truncate(String s, int max) {
        if (s == null) return null;
        return s.length() > max ? s.substring(0, max) : s;
    }

    public static class DeviceBlockedException extends RuntimeException {
        public DeviceBlockedException(String message) { super(message); }
    }
}
