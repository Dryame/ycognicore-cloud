-- =====================================================================
-- V7__add_partition_maintenance.sql
-- Base : ycc_control_plane
-- Objet : Table de traçabilité des maintenances de partitions
-- Réf.  : BL-005, NFR-CONF-04, NFR-OPS-04
-- =====================================================================

CREATE TABLE IF NOT EXISTS partition_maintenance_log (
    id                BIGSERIAL PRIMARY KEY,
    tenant_id         UUID REFERENCES tenants(id) ON DELETE CASCADE,
    db_name           VARCHAR(100) NOT NULL,
    table_cible       VARCHAR(50) NOT NULL,
    partition_creee   VARCHAR(100) NOT NULL,
    mois_cible        DATE NOT NULL,
    statut            VARCHAR(20) NOT NULL DEFAULT 'SUCCES'
                      CHECK (statut IN ('SUCCES','ECHEC')),
    erreur            TEXT,
    execute_le        TIMESTAMPTZ NOT NULL DEFAULT now(),
    execute_par       VARCHAR(50) NOT NULL DEFAULT 'SCHEDULER',
    CONSTRAINT chk_mois_premier_jour CHECK (mois_cible = date_trunc('month', mois_cible)::DATE)
);

CREATE INDEX IF NOT EXISTS idx_partition_log_tenant
    ON partition_maintenance_log (tenant_id, execute_le DESC);

CREATE INDEX IF NOT EXISTS idx_partition_log_statut
    ON partition_maintenance_log (statut, execute_le DESC);

COMMENT ON TABLE partition_maintenance_log IS
  'Journal des exécutions de création de partitions mensuelles (BL-005).';

GRANT SELECT, INSERT ON partition_maintenance_log TO ycc_control_plane_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ycc_control_plane_app;
