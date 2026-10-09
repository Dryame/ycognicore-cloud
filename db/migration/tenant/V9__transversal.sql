-- ============================================================================
-- V9__transversal.sql
-- Base : ycc_tenant_<id>
-- Objet : Bloc transversal — Fichiers + IA + KPI
-- Réf.  : Design Bible Phase 2 — Bloc V9
-- ============================================================================

SET search_path TO public;

-- SECTION 1 — TABLE fichiers
CREATE TABLE fichiers (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nom_original        VARCHAR(255) NOT NULL,
    nom_stockage        VARCHAR(255) NOT NULL,
    bucket              VARCHAR(50) NOT NULL,
    chemin              VARCHAR(500) NOT NULL,
    taille_octets       BIGINT NOT NULL,
    type_mime           VARCHAR(100) NOT NULL,
    extension           VARCHAR(20),
    hash_sha256         VARCHAR(64) NOT NULL,
    statut_scan_virus   VARCHAR(20) NOT NULL DEFAULT 'EN_ATTENTE',
    date_scan           TIMESTAMPTZ,
    moteur_scan         VARCHAR(50),
    details_scan        TEXT,
    metadonnees         JSONB,
    uploaded_by         UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by          UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at          TIMESTAMPTZ,
    version             INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_fichiers_bucket
        CHECK (bucket IN ('ycc-documents','ycc-kyc','ycc-pdf','ycc-imports')),
    CONSTRAINT chk_fichiers_statut_scan
        CHECK (statut_scan_virus IN ('EN_ATTENTE','EN_COURS','PROPRE','INFECTE','ERREUR')),
    CONSTRAINT chk_fichiers_taille
        CHECK (taille_octets > 0),
    CONSTRAINT chk_fichiers_sha256
        CHECK (hash_sha256 ~ '^[a-f0-9]{64}$'),
    CONSTRAINT uq_fichiers_nom_stockage
        UNIQUE (nom_stockage)
);

CREATE INDEX idx_fichiers_bucket ON fichiers (bucket) WHERE deleted_at IS NULL;
CREATE INDEX idx_fichiers_sha256 ON fichiers (hash_sha256) WHERE deleted_at IS NULL;
CREATE INDEX idx_fichiers_scan ON fichiers (statut_scan_virus) WHERE deleted_at IS NULL AND statut_scan_virus IN ('EN_ATTENTE','EN_COURS');
CREATE INDEX idx_fichiers_uploaded_by ON fichiers (uploaded_by) WHERE deleted_at IS NULL;

COMMENT ON TABLE fichiers IS 'Métadonnées des fichiers MinIO — Design Bible V9';

-- SECTION 2 — TABLE ia_suggestions
CREATE TABLE ia_suggestions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_id           INTEGER NOT NULL REFERENCES modules(id) ON DELETE RESTRICT,
    type_suggestion     VARCHAR(50) NOT NULL,
    entite_cible        VARCHAR(50) NOT NULL,
    entite_id           UUID,
    contexte            JSONB NOT NULL,
    suggestion          JSONB NOT NULL,
    confiance           SMALLINT NOT NULL DEFAULT 0,
    modele              VARCHAR(100) NOT NULL,
    tokens_consommes    INTEGER NOT NULL DEFAULT 0,
    statut              VARCHAR(20) NOT NULL DEFAULT 'EN_ATTENTE',
    decision_humaine    VARCHAR(20),
    decidee_par         UUID REFERENCES users(id) ON DELETE SET NULL,
    date_decision       TIMESTAMPTZ,
    commentaire_decision TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by          UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at          TIMESTAMPTZ,
    version             INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_ia_suggestions_confiance CHECK (confiance BETWEEN 0 AND 100),
    CONSTRAINT chk_ia_suggestions_statut CHECK (statut IN ('EN_ATTENTE','ACCEPTEE','REJETEE','EXPIREE')),
    CONSTRAINT chk_ia_suggestions_decision CHECK (decision_humaine IS NULL OR decision_humaine IN ('ACCEPTEE','REJETEE')),
    CONSTRAINT chk_ia_suggestions_tokens CHECK (tokens_consommes >= 0)
);

CREATE INDEX idx_ia_suggestions_module ON ia_suggestions (module_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_ia_suggestions_entite ON ia_suggestions (entite_cible, entite_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_ia_suggestions_statut ON ia_suggestions (statut) WHERE deleted_at IS NULL;
CREATE INDEX idx_ia_suggestions_date ON ia_suggestions (created_at DESC);

COMMENT ON TABLE ia_suggestions IS 'Propositions IA tracées avec décision humaine obligatoire — Design Bible V9';

-- SECTION 3 — TABLE kpi_snapshots
CREATE TABLE kpi_snapshots (
    id                  BIGSERIAL PRIMARY KEY,
    code_kpi            VARCHAR(100) NOT NULL,
    module_id           INTEGER REFERENCES modules(id) ON DELETE RESTRICT,
    date_snapshot       DATE NOT NULL,
    granularite         VARCHAR(20) NOT NULL DEFAULT 'JOUR',
    valeur              NUMERIC(20,6) NOT NULL,
    dimensions          JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_kpi_granularite CHECK (granularite IN ('HEURE','JOUR','SEMAINE','MOIS','TRIMESTRE','ANNEE')),
    CONSTRAINT uq_kpi_snapshot UNIQUE (code_kpi, date_snapshot, granularite, dimensions)
);

CREATE INDEX idx_kpi_snapshots_code_date ON kpi_snapshots (code_kpi, date_snapshot DESC);
CREATE INDEX idx_kpi_snapshots_module ON kpi_snapshots (module_id) WHERE module_id IS NOT NULL;
CREATE INDEX idx_kpi_snapshots_date ON kpi_snapshots (date_snapshot DESC);
CREATE INDEX idx_kpi_snapshots_dimensions ON kpi_snapshots USING GIN (dimensions);

COMMENT ON TABLE kpi_snapshots IS 'KPI pré-calculés par date et dimensions — Design Bible V9';

-- SECTION 4 — TRIGGERS STANDARD
SELECT attacher_triggers_standard('fichiers');
SELECT attacher_triggers_standard('ia_suggestions');

-- SECTION 5 — FONCTION SECURITY DEFINER
CREATE OR REPLACE FUNCTION rechercher_fichier_par_hash(p_hash VARCHAR)
RETURNS TABLE (
    id UUID, nom_original VARCHAR, bucket VARCHAR, chemin VARCHAR,
    taille_octets BIGINT, type_mime VARCHAR, statut_scan_virus VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT f.id, f.nom_original, f.bucket, f.chemin,
           f.taille_octets, f.type_mime, f.statut_scan_virus
    FROM fichiers f
    WHERE f.hash_sha256 = p_hash AND f.deleted_at IS NULL
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION rechercher_fichier_par_hash(VARCHAR) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rechercher_fichier_par_hash(VARCHAR) TO ycc_tenant_app;

-- SECTION 6 — DROITS
GRANT SELECT, INSERT, UPDATE ON fichiers TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON ia_suggestions TO ycc_tenant_app;
GRANT SELECT, INSERT ON kpi_snapshots TO ycc_tenant_app;
GRANT USAGE, SELECT ON SEQUENCE kpi_snapshots_id_seq TO ycc_tenant_app;

-- SECTION 7 — VÉRIFICATIONS POST-MIGRATION
DO $$
DECLARE
    v_nb_tables INTEGER;
    v_nb_index  INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_nb_tables FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name IN ('fichiers','ia_suggestions','kpi_snapshots');
    IF v_nb_tables <> 3 THEN RAISE EXCEPTION 'Attendu 3 tables V9, trouve %', v_nb_tables; END IF;
    RAISE NOTICE '3 tables V9 verifiees';

    SELECT COUNT(*) INTO v_nb_index FROM pg_indexes
    WHERE tablename IN ('fichiers','ia_suggestions','kpi_snapshots');
    IF v_nb_index < 12 THEN RAISE EXCEPTION 'Index manquants V9 : %', v_nb_index; END IF;
    RAISE NOTICE '% index V9 verifies', v_nb_index;

    RAISE NOTICE '=============================================';
    RAISE NOTICE 'V9__transversal.sql — Fichiers + IA + KPI OK';
    RAISE NOTICE '=============================================';
END;
$$;
