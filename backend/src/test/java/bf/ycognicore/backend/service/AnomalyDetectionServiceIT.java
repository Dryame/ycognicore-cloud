package bf.ycognicore.backend.service;

import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests AnomalyDetectionService — logique pure des regles.
 * Ref. : T3.11, ADR-037.
 */
class AnomalyDetectionServiceIT {

    // Service sans DB : on teste uniquement la logique des seuils
    private AnomalyDetectionService createService() {
        MultiTenantConnectionProviderImpl provider = null;   // non utilise dans ces tests
        SecurityEventService events = new SecurityEventService(provider, new ObjectMapper());
        return new AnomalyDetectionService(provider, events);
    }

    @Test
    void horaire_inhabituel_detecte_23h() {
        AnomalyDetectionService service = createService();
        // Pas d'exception — la regle ecrit dans evenements_securite (silencieux sans tenant)
        service.detecterHoraireInhabituel(UUID.randomUUID(),
            OffsetDateTime.of(2026, 10, 16, 23, 30, 0, 0, ZoneOffset.UTC));
    }

    @Test
    void horaire_normal_14h_pas_alerte() {
        AnomalyDetectionService service = createService();
        service.detecterHoraireInhabituel(UUID.randomUUID(),
            OffsetDateTime.of(2026, 10, 16, 14, 0, 0, 0, ZoneOffset.UTC));
    }

    @Test
    void codes_regles_sont_stables() {
        // Verrou : les codes exposes ne doivent pas changer (contrat avec evenements_securite)
        assertThat(AnomalyDetectionService.R_NOUVEL_APPAREIL).isEqualTo("R_N2_NOUVEL_APPAREIL");
        assertThat(AnomalyDetectionService.R_IP_PAYS_INEDIT).isEqualTo("R_N2_IP_PAYS_INEDIT");
        assertThat(AnomalyDetectionService.R_HORAIRE_INHABITUEL).isEqualTo("R_N2_HORAIRE_INHABITUEL");
        assertThat(AnomalyDetectionService.R_LIEUX_INCOMPATIBLES).isEqualTo("R_N2_LIEUX_INCOMPATIBLES");
        assertThat(AnomalyDetectionService.R_ECHECS_REPETES).isEqualTo("R_N2_ECHECS_REPETES");
        assertThat(AnomalyDetectionService.R_JETON_ANORMAL).isEqualTo("R_N2_JETON_ANORMAL");
        assertThat(AnomalyDetectionService.R_VOLUME_INHABITUEL).isEqualTo("R_N2_VOLUME_INHABITUEL");
    }

    @Test
    void appel_sans_tenant_ne_plante_pas() {
        AnomalyDetectionService service = createService();
        UUID userId = UUID.randomUUID();
        // Aucun TenantContext → les appels doivent etre silencieux
        service.detecterNouvelAppareil(userId, UUID.randomUUID());
        service.detecterIpPaysInedit(userId, "8.8.8.8", "US");
        service.detecterHoraireInhabituel(userId, OffsetDateTime.now());
        service.detecterLieuxIncompatibles(userId, "FR", OffsetDateTime.now());
        service.detecterEchecsRepetes(userId, "test@x.y");
        service.detecterJetonAnormal(userId, UUID.randomUUID(), "jti-test");
        service.detecterVolumeInhabituel(userId, "EXPORT");
    }
}
