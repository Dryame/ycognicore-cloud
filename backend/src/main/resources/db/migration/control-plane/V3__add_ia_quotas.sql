-- =====================================================================
-- V3__add_ia_quotas.sql
-- Base : ycc_control_plane
-- Objet : Encadrement des quotas IA par tenant (NFR-IA-01, NFR-IA-04)
-- Réf. rapport 04-78 : section 3.10.1
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table : ia_quotas
-- Une ligne par tenant ET par mois (periode) : conserve l'historique de
-- consommation mois par mois plutôt qu'un compteur unique écrasé chaque
-- mois — nécessaire pour le rapport mensuel par tenant (NFR-MON-05).
-- ---------------------------------------------------------------------
CREATE TABLE ia_quotas (
    id                  BIGSERIAL PRIMARY KEY,
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    formule             formule_abonnement NOT NULL,
    periode             DATE NOT NULL,
    quota_mensuel       INTEGER NOT NULL CHECK (quota_mensuel >= 0),
    consommation        INTEGER NOT NULL DEFAULT 0 CHECK (consommation >= 0),
    date_maj            TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_ia_quotas_tenant_periode UNIQUE (tenant_id, periode),
    CONSTRAINT chk_periode_premier_jour CHECK (periode = date_trunc('month', periode)::DATE)
);

CREATE INDEX idx_ia_quotas_formule ON ia_quotas (formule);
CREATE INDEX idx_ia_quotas_tenant_periode ON ia_quotas (tenant_id, periode);

COMMENT ON TABLE ia_quotas IS 'Quota mensuel de requêtes IA par tenant, historisé mois par mois (une ligne par période).';
COMMENT ON COLUMN ia_quotas.periode IS 'Premier jour du mois concerné (ex. 2026-09-01) — contrainte CHECK garantit la normalisation.';

-- Fonction utilitaire : incrémente la consommation du mois en cours,
-- de façon atomique (évite les race conditions lors d'appels IA concurrents)
CREATE OR REPLACE FUNCTION incrementer_consommation_ia(p_tenant_id UUID, p_delta INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE ia_quotas
    SET consommation = consommation + p_delta,
        date_maj = now()
    WHERE tenant_id = p_tenant_id
      AND periode = date_trunc('month', now())::DATE;
END;
$$ LANGUAGE plpgsql;

GRANT SELECT, INSERT, UPDATE ON ia_quotas TO ycc_control_plane_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ycc_control_plane_app;
GRANT EXECUTE ON FUNCTION incrementer_consommation_ia(UUID, INTEGER) TO ycc_control_plane_app;
