package bf.ycognicore.backend.service;

import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
import bf.ycognicore.backend.multitenant.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;

/**
 * Detection d'anomalies par regles explicables (ADR-037).
 * 7 regles R-N2-1 a R-N2-7.
 * Chaque detection ecrit dans evenements_securite.
 * Ref. : T3.11, D-06, exigence 2.4.
 */
@Service
public class AnomalyDetectionService {

    private static final Logger log = LoggerFactory.getLogger(AnomalyDetectionService.class);

    /** Code d'alerte par regle. */
    public static final String R_NOUVEL_APPAREIL       = "R_N2_NOUVEL_APPAREIL";
    public static final String R_IP_PAYS_INEDIT        = "R_N2_IP_PAYS_INEDIT";
    public static final String R_HORAIRE_INHABITUEL    = "R_N2_HORAIRE_INHABITUEL";
    public static final String R_LIEUX_INCOMPATIBLES   = "R_N2_LIEUX_INCOMPATIBLES";
    public static final String R_ECHECS_REPETES        = "R_N2_ECHECS_REPETES";
    public static final String R_JETON_ANORMAL         = "R_N2_JETON_ANORMAL";
    public static final String R_VOLUME_INHABITUEL     = "R_N2_VOLUME_INHABITUEL";

    /** Seuils parametrables. */
    private static final int SEUIL_ECHECS_REPETES     = 3;
    private static final int SEUIL_VOLUME_EXPORTS     = 20;
    private static final int SEUIL_VOLUME_SUPPRESSIONS = 5;
    private static final Duration FENETRE_VOLUME      = Duration.ofHours(1);
    private static final Duration FENETRE_LIEUX       = Duration.ofHours(1);

    private final MultiTenantConnectionProviderImpl connectionProvider;
    private final SecurityEventService securityEventService;

    public AnomalyDetectionService(MultiTenantConnectionProviderImpl connectionProvider,
                                   SecurityEventService securityEventService) {
        this.connectionProvider = connectionProvider;
        this.securityEventService = securityEventService;
    }

    // =============================================================
    // R-N2-1 : nouvel appareil
    // =============================================================
    public void detecterNouvelAppareil(UUID userId, UUID appareilId) {
        securityEventService.enregistrer(
            R_NOUVEL_APPAREIL, "WARN", userId, null, appareilId,
            null, null, null,
            securityEventService.details("appareilId", appareilId));
    }

    // =============================================================
    // R-N2-2 : IP ou pays inedit
    // =============================================================
    public void detecterIpPaysInedit(UUID userId, String ip, String pays) {
        if (ip == null || userId == null) return;
        if (dejaVuIp(userId, ip)) return;

        securityEventService.enregistrer(
            R_IP_PAYS_INEDIT, "WARN", userId, null, null,
            ip, pays, null,
            securityEventService.details("ip", ip, "pays", pays));
    }

    private boolean dejaVuIp(UUID userId, String ip) {
        String tenantCode = TenantContext.getTenantId();
        if (tenantCode == null) return true;
        String sql = """
            SELECT 1 FROM audit_log
             WHERE user_id = ? AND ip = ?::inet
             LIMIT 1
            """;
        try (Connection conn = connectionProvider.getConnection(tenantCode);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setObject(1, userId);
            ps.setString(2, ip);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();
            }
        } catch (Exception e) {
            log.debug("Verification IP deja vue echouee : {}", e.getMessage());
            return true;   // fail-soft : ne pas alerter si erreur
        }
    }

    // =============================================================
    // R-N2-3 : horaire inhabituel (23h - 05h UTC)
    // =============================================================
    public void detecterHoraireInhabituel(UUID userId, OffsetDateTime moment) {
        if (moment == null) moment = OffsetDateTime.now(ZoneOffset.UTC);
        int heure = moment.withOffsetSameInstant(ZoneOffset.UTC).getHour();
        if (heure >= 23 || heure < 5) {
            securityEventService.enregistrer(
                R_HORAIRE_INHABITUEL, "INFO", userId, null, null,
                null, null, null,
                securityEventService.details("heureUtc", heure));
        }
    }

    // =============================================================
    // R-N2-4 : lieux incompatibles (2 pays differents < 1h)
    // =============================================================
    public void detecterLieuxIncompatibles(UUID userId, String paysActuel,
                                            OffsetDateTime moment) {
        if (userId == null || paysActuel == null) return;

        String tenantCode = TenantContext.getTenantId();
        if (tenantCode == null) return;

        String sql = """
            SELECT pays, date_creation
              FROM evenements_securite
             WHERE user_id = ?
               AND pays IS NOT NULL
               AND pays <> ?
               AND date_creation > ?
             ORDER BY date_creation DESC
             LIMIT 1
            """;

        try (Connection conn = connectionProvider.getConnection(tenantCode);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setObject(1, userId);
            ps.setString(2, paysActuel);
            ps.setObject(3, moment.minus(FENETRE_LIEUX));
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    String paysPrecedent = rs.getString(1);
                    securityEventService.enregistrer(
                        R_LIEUX_INCOMPATIBLES, "CRITIQUE", userId, null, null,
                        null, paysActuel, null,
                        securityEventService.details(
                            "paysPrecedent", paysPrecedent,
                            "paysActuel", paysActuel,
                            "fenetre", "1h"));
                }
            }
        } catch (Exception e) {
            log.debug("Verification lieux incompatibles echouee : {}", e.getMessage());
        }
    }

    // =============================================================
    // R-N2-5 : echecs repetes
    // =============================================================
    public void detecterEchecsRepetes(UUID userId, String email) {
        String tenantCode = TenantContext.getTenantId();
        if (tenantCode == null || email == null) return;

        String sql = """
            SELECT COUNT(*) FROM login_attempts
             WHERE email = ? AND succes = FALSE
               AND timestamp > now() - interval '15 minutes'
            """;

        try (Connection conn = connectionProvider.getConnection(tenantCode);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, email);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next() && rs.getInt(1) >= SEUIL_ECHECS_REPETES) {
                    securityEventService.enregistrer(
                        R_ECHECS_REPETES, "CRITIQUE", userId, null, null,
                        null, null, null,
                        securityEventService.details(
                            "email", email, "nbEchecs", rs.getInt(1)));
                }
            }
        } catch (Exception e) {
            log.debug("Verification echecs repetes echouee : {}", e.getMessage());
        }
    }

    // =============================================================
    // R-N2-6 : usage anormal de jeton (replay)
    // =============================================================
    public void detecterJetonAnormal(UUID userId, UUID sessionId, String jti) {
        securityEventService.enregistrer(
            R_JETON_ANORMAL, "ERROR", userId, sessionId, null,
            null, null, null,
            securityEventService.details("jti", jti));
    }

    // =============================================================
    // R-N2-7 : volume inhabituel d'exports / suppressions
    // =============================================================
    public void detecterVolumeInhabituel(UUID userId, String typeAction) {
        String tenantCode = TenantContext.getTenantId();
        if (tenantCode == null || typeAction == null) return;

        int seuil = switch (typeAction) {
            case "SUPPRESSION" -> SEUIL_VOLUME_SUPPRESSIONS;
            case "EXPORT"      -> SEUIL_VOLUME_EXPORTS;
            default            -> Integer.MAX_VALUE;
        };
        if (seuil == Integer.MAX_VALUE) return;

        String sql = """
            SELECT COUNT(*) FROM audit_log
             WHERE user_id = ?
               AND action LIKE ?
               AND timestamp > ?
            """;

        try (Connection conn = connectionProvider.getConnection(tenantCode);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setObject(1, userId);
            ps.setString(2, typeAction + "%");
            ps.setObject(3, OffsetDateTime.now().minus(FENETRE_VOLUME));
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next() && rs.getInt(1) >= seuil) {
                    securityEventService.enregistrer(
                        R_VOLUME_INHABITUEL, "WARN", userId, null, null,
                        null, null, null,
                        securityEventService.details(
                            "typeAction", typeAction,
                            "nbActions", rs.getInt(1),
                            "fenetreMinutes", FENETRE_VOLUME.toMinutes()));
                }
            }
        } catch (Exception e) {
            log.debug("Verification volume inhabituel echouee : {}", e.getMessage());
        }
    }
}
