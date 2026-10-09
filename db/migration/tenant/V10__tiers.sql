-- ============================================================================
-- V10__tiers.sql
-- Base : ycc_tenant_<id>
-- Objet : Référentiel Tiers (client + fournisseur unifié)
-- Réf.  : Design Bible Phase 2 — Bloc V10
-- ============================================================================

SET search_path TO public;

-- SECTION 1 — TABLE tiers
CREATE TABLE tiers (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                    VARCHAR(20) NOT NULL,
    type_tiers              VARCHAR(20) NOT NULL,
    categorie               VARCHAR(20) NOT NULL,
    raison_sociale          VARCHAR(255) NOT NULL,
    nom_commercial          VARCHAR(255),
    ifu                     VARCHAR(20),
    rccm                    VARCHAR(50),
    regime_fiscal           VARCHAR(30) NOT NULL,
    secteur_activite_id     UUID,
    email                   CITEXT,
    telephone               VARCHAR(30),
    site_web                VARCHAR(255),
    delai_paiement_jours    INTEGER NOT NULL DEFAULT 30,
    plafond_encours         NUMERIC(15,2),
    devise_preferee         VARCHAR(3) NOT NULL DEFAULT 'XOF',
    langue_preferee         VARCHAR(5) NOT NULL DEFAULT 'fr',
    conditions_reglement    TEXT,
    statut                  VARCHAR(20) NOT NULL DEFAULT 'ACTIF',
    prospect_id             UUID,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at              TIMESTAMPTZ,
    version                 INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_tiers_type CHECK (type_tiers IN ('PERSONNE_PHYSIQUE','PERSONNE_MORALE')),
    CONSTRAINT chk_tiers_categorie CHECK (categorie IN ('PARTICULIER','ENTREPRISE','ADMINISTRATION','ONG','ASSOCIATION')),
    CONSTRAINT chk_tiers_regime CHECK (regime_fiscal IN ('REEL_NORMAL','REEL_SIMPLIFIE','CONTRIBUTION_UNIQUE')),
    CONSTRAINT chk_tiers_statut CHECK (statut IN ('ACTIF','INACTIF','ARCHIVE')),
    CONSTRAINT chk_tiers_delai CHECK (delai_paiement_jours >= 0),
    CONSTRAINT chk_tiers_plafond CHECK (plafond_encours IS NULL OR plafond_encours >= 0),
    CONSTRAINT chk_tiers_code_format CHECK (code ~ '^TIE-[0-9]{4}-[0-9]{6}$'),
    CONSTRAINT uq_tiers_code UNIQUE (code)
);

CREATE UNIQUE INDEX uq_tiers_ifu ON tiers (ifu) WHERE ifu IS NOT NULL AND deleted_at IS NULL;
CREATE UNIQUE INDEX uq_tiers_rccm ON tiers (rccm) WHERE rccm IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_tiers_raison_sociale ON tiers (raison_sociale) WHERE deleted_at IS NULL;
CREATE INDEX idx_tiers_statut ON tiers (statut) WHERE deleted_at IS NULL;
CREATE INDEX idx_tiers_type ON tiers (type_tiers) WHERE deleted_at IS NULL;
CREATE INDEX idx_tiers_prospect ON tiers (prospect_id) WHERE prospect_id IS NOT NULL AND deleted_at IS NULL;

COMMENT ON TABLE tiers IS 'Référentiel unifié client + fournisseur — Design Bible V10';

-- SECTION 2 — TABLE role_tiers
CREATE TABLE role_tiers (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tiers_id            UUID NOT NULL,
    role                VARCHAR(20) NOT NULL,
    date_debut          DATE NOT NULL DEFAULT CURRENT_DATE,
    date_fin            DATE,
    actif               BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by          UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at          TIMESTAMPTZ,
    version             INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_role_tiers_role CHECK (role IN ('CLIENT','FOURNISSEUR','MIXTE')),
    CONSTRAINT chk_role_tiers_dates CHECK (date_fin IS NULL OR date_fin >= date_debut),
    CONSTRAINT fk_role_tiers_tiers FOREIGN KEY (tiers_id) REFERENCES tiers(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX uq_role_tiers_actif ON role_tiers (tiers_id, role) WHERE actif = TRUE AND deleted_at IS NULL;
CREATE INDEX idx_role_tiers_tiers ON role_tiers (tiers_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_role_tiers_role ON role_tiers (role) WHERE deleted_at IS NULL;

COMMENT ON TABLE role_tiers IS 'Rôle du tiers — Design Bible V10';

-- SECTION 3 — TABLE contact_tiers
CREATE TABLE contact_tiers (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tiers_id            UUID NOT NULL,
    nom                 VARCHAR(100) NOT NULL,
    prenom              VARCHAR(100) NOT NULL,
    fonction            VARCHAR(100),
    email               CITEXT,
    telephone           VARCHAR(30),
    canal_prefere       VARCHAR(20) NOT NULL DEFAULT 'EMAIL',
    langue              VARCHAR(5) NOT NULL DEFAULT 'fr',
    est_principal       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by          UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at          TIMESTAMPTZ,
    version             INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_contact_tiers_canal CHECK (canal_prefere IN ('EMAIL','SMS','WHATSAPP','APPEL')),
    CONSTRAINT fk_contact_tiers_tiers FOREIGN KEY (tiers_id) REFERENCES tiers(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX uq_contact_tiers_principal ON contact_tiers (tiers_id) WHERE est_principal = TRUE AND deleted_at IS NULL;
CREATE INDEX idx_contact_tiers_tiers ON contact_tiers (tiers_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_contact_tiers_email ON contact_tiers (email) WHERE email IS NOT NULL AND deleted_at IS NULL;

COMMENT ON TABLE contact_tiers IS 'Contacts rattachés à un tiers — Design Bible V10';

-- SECTION 4 — TABLE adresse_tiers
CREATE TABLE adresse_tiers (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tiers_id            UUID NOT NULL,
    type_adresse        VARCHAR(20) NOT NULL,
    rue                 VARCHAR(255) NOT NULL,
    ville               VARCHAR(100) NOT NULL,
    region              VARCHAR(100),
    pays                VARCHAR(100) NOT NULL DEFAULT 'Burkina Faso',
    code_postal         VARCHAR(20),
    est_principale      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by          UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at          TIMESTAMPTZ,
    version             INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_adresse_tiers_type CHECK (type_adresse IN ('SIEGE','FACTURATION','LIVRAISON')),
    CONSTRAINT fk_adresse_tiers_tiers FOREIGN KEY (tiers_id) REFERENCES tiers(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX uq_adresse_tiers_principale ON adresse_tiers (tiers_id, type_adresse) WHERE est_principale = TRUE AND deleted_at IS NULL;
CREATE INDEX idx_adresse_tiers_tiers ON adresse_tiers (tiers_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_adresse_tiers_type ON adresse_tiers (type_adresse) WHERE deleted_at IS NULL;

COMMENT ON TABLE adresse_tiers IS 'Adresses multiples du tiers — Design Bible V10';

-- SECTION 5 — TRIGGERS STANDARD (V8)
SELECT attacher_triggers_standard('tiers');
SELECT attacher_triggers_standard('role_tiers');
SELECT attacher_triggers_standard('contact_tiers');
SELECT attacher_triggers_standard('adresse_tiers');

-- SECTION 6 — DROITS
GRANT SELECT, INSERT, UPDATE ON tiers TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON role_tiers TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON contact_tiers TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON adresse_tiers TO ycc_tenant_app;

-- SECTION 7 — VÉRIFICATIONS POST-MIGRATION
DO $$
DECLARE
    v_nb_tables INTEGER;
    v_nb_index  INTEGER;
    v_nb_fk     INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_nb_tables FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name IN ('tiers','role_tiers','contact_tiers','adresse_tiers');
    IF v_nb_tables <> 4 THEN RAISE EXCEPTION 'Attendu 4 tables V10, trouve %', v_nb_tables; END IF;
    RAISE NOTICE '4 tables V10 verifiees';

    SELECT COUNT(*) INTO v_nb_index FROM pg_indexes
    WHERE tablename IN ('tiers','role_tiers','contact_tiers','adresse_tiers');
    IF v_nb_index < 15 THEN RAISE EXCEPTION 'Index manquants V10 : %', v_nb_index; END IF;
    RAISE NOTICE '% index V10 verifies', v_nb_index;

    SELECT COUNT(*) INTO v_nb_fk FROM pg_constraint
    WHERE contype = 'f'
      AND conrelid::regclass::text IN ('tiers','role_tiers','contact_tiers','adresse_tiers');
    IF v_nb_fk < 11 THEN RAISE EXCEPTION 'FK manquantes V10 : %', v_nb_fk; END IF;
    RAISE NOTICE '% FK V10 verifiees', v_nb_fk;

    RAISE NOTICE '=============================================';
    RAISE NOTICE 'V10__tiers.sql — Referentiel Tiers OK';
    RAISE NOTICE '=============================================';
END;
$$;
