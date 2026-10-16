package bf.ycognicore.backend.controller;

import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.security.RequireDroitSpecial;
import bf.ycognicore.backend.service.DeviceService;
import bf.ycognicore.backend.service.SessionService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Console de securite du tenant (F9, exigence 3.3).
 * Protege par @RequireDroitSpecial(CONSOLE_SECURITE).
 * Ref. : T3.12, T3.13, D-11, ADR-038.
 */
@RestController
@RequestMapping("/api/console-securite")
@RequireDroitSpecial("CONSOLE_SECURITE")
public class ConsoleSecuriteController {

    private final SessionService sessionService;
    private final DeviceService deviceService;
    private final MultiTenantConnectionProviderImpl connectionProvider;

    public ConsoleSecuriteController(SessionService sessionService,
                                     DeviceService deviceService,
                                     MultiTenantConnectionProviderImpl connectionProvider) {
        this.sessionService = sessionService;
        this.deviceService = deviceService;
        this.connectionProvider = connectionProvider;
    }

    /** Ping protege — valide la protection par droit special. */
    @GetMapping("/ping")
    public ResponseEntity<Map<String, Object>> ping() {
        return ResponseEntity.ok(Map.of(
            "status", "ok",
            "message", "Acces console autorise",
            "tenant", String.valueOf(TenantContext.getTenantId())
        ));
    }

    // ----- Sessions -----

    @GetMapping("/sessions")
    public List<SessionService.SessionRow> listSessions(
            @RequestParam(required = false) UUID userId) {
        String tenant = TenantContext.getTenantId();
        return userId != null
            ? sessionService.listForUser(tenant, userId)
            : sessionService.listByTenant(tenant);
    }

    @PostMapping("/sessions/{id}/revoke")
    public ResponseEntity<Map<String, Object>> revokeSession(@PathVariable UUID id) {
        String tenant = TenantContext.getTenantId();
        sessionService.revoke(tenant, id, "REVOCATION_ADMIN");
        return ResponseEntity.ok(Map.of("success", true, "sessionId", id));
    }

    // ----- Appareils -----

    @GetMapping("/appareils")
    public List<DeviceService.DeviceRow> listDevices(
            @RequestParam(required = false) UUID userId) {
        String tenant = TenantContext.getTenantId();
        return userId != null
            ? deviceService.listForUser(tenant, userId)
            : deviceService.listByTenant(tenant);
    }

    @PostMapping("/appareils/{id}/block")
    public ResponseEntity<Map<String, Object>> blockDevice(@PathVariable UUID id) {
        String tenant = TenantContext.getTenantId();
        deviceService.block(tenant, id);
        return ResponseEntity.ok(Map.of("success", true, "deviceId", id, "statut", "BLOQUE"));
    }

    @PostMapping("/appareils/{id}/unblock")
    public ResponseEntity<Map<String, Object>> unblockDevice(@PathVariable UUID id) {
        String tenant = TenantContext.getTenantId();
        deviceService.unblock(tenant, id);
        return ResponseEntity.ok(Map.of("success", true, "deviceId", id, "statut", "AUTORISE"));
    }

    // ----- Evenements de securite -----

    @GetMapping("/evenements")
    public List<EventRow> listEvents(
            @RequestParam(required = false) String gravite,
            @RequestParam(required = false) String statut) {
        String tenant = TenantContext.getTenantId();
        StringBuilder sql = new StringBuilder("""
            SELECT id, type, gravite, user_id, session_id, appareil_id,
                   ip::text, pays, ville, statut_traitement, date_creation
              FROM evenements_securite
             WHERE 1=1
            """);
        List<Object> params = new ArrayList<>();
        if (gravite != null && !gravite.isBlank()) {
            sql.append(" AND gravite = ?");
            params.add(gravite);
        }
        if (statut != null && !statut.isBlank()) {
            sql.append(" AND statut_traitement = ?");
            params.add(statut);
        }
        sql.append(" ORDER BY date_creation DESC LIMIT 500");

        List<EventRow> rows = new ArrayList<>();
        try (Connection conn = connectionProvider.getConnection(tenant);
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    rows.add(new EventRow(
                        (UUID) rs.getObject("id"),
                        rs.getString("type"),
                        rs.getString("gravite"),
                        (UUID) rs.getObject("user_id"),
                        (UUID) rs.getObject("session_id"),
                        (UUID) rs.getObject("appareil_id"),
                        rs.getString("ip"),
                        rs.getString("pays"),
                        rs.getString("ville"),
                        rs.getString("statut_traitement"),
                        rs.getObject("date_creation", OffsetDateTime.class)
                    ));
                }
            }
        } catch (Exception e) {
            throw new RuntimeException("Lecture evenements echouee", e);
        }
        return rows;
    }

    public record EventRow(
        UUID id, String type, String gravite,
        UUID userId, UUID sessionId, UUID appareilId,
        String ip, String pays, String ville,
        String statutTraitement, OffsetDateTime dateCreation
    ) {}
}
