package bf.ycognicore.backend.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Vue plateforme Superadmin (T3.14).
 * Aucune donnee metier — uniquement evenements agreges.
 * Ref. : T3.14, exigence 3.3, ADR-038.
 */
@RestController
@RequestMapping("/api/platform")
@PreAuthorize("hasAuthority('SUPERADMIN')")
public class PlatformController {

    private final DataSource controlPlaneDataSource;

    public PlatformController(
            @org.springframework.beans.factory.annotation.Qualifier("controlPlaneDataSource")
            DataSource controlPlaneDataSource) {
        this.controlPlaneDataSource = controlPlaneDataSource;
    }

    /** Ping protege Superadmin. */
    @GetMapping("/ping")
    public ResponseEntity<Map<String, Object>> ping() {
        return ResponseEntity.ok(Map.of(
            "status", "ok",
            "message", "Acces plateforme autorise"
        ));
    }

    /** Evenements agreges toutes entreprises confondues. */
    @GetMapping("/evenements")
    public List<AggregatedEvent> listAggregatedEvents(
            @RequestParam(required = false) String gravite,
            @RequestParam(required = false) String tenant) {
        StringBuilder sql = new StringBuilder("""
            SELECT id, tenant_id, tenant_db_name, type, gravite,
                   date_evenement, traite, date_creation
              FROM evenements_securite_agreges
             WHERE 1=1
            """);
        List<Object> params = new ArrayList<>();
        if (gravite != null && !gravite.isBlank()) {
            sql.append(" AND gravite = ?");
            params.add(gravite);
        }
        if (tenant != null && !tenant.isBlank()) {
            sql.append(" AND tenant_db_name = ?");
            params.add(tenant);
        }
        sql.append(" ORDER BY date_evenement DESC LIMIT 1000");

        List<AggregatedEvent> rows = new ArrayList<>();
        try (Connection conn = controlPlaneDataSource.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                ps.setObject(i + 1, params.get(i));
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    rows.add(new AggregatedEvent(
                        (UUID) rs.getObject("id"),
                        (UUID) rs.getObject("tenant_id"),
                        rs.getString("tenant_db_name"),
                        rs.getString("type"),
                        rs.getString("gravite"),
                        rs.getObject("date_evenement", OffsetDateTime.class),
                        rs.getBoolean("traite"),
                        rs.getObject("date_creation", OffsetDateTime.class)
                    ));
                }
            }
        } catch (Exception e) {
            throw new RuntimeException("Lecture evenements agreges echouee", e);
        }
        return rows;
    }

    public record AggregatedEvent(
        UUID id, UUID tenantId, String tenantDbName,
        String type, String gravite,
        OffsetDateTime dateEvenement, boolean traite,
        OffsetDateTime dateCreation
    ) {}
}
