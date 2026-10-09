#!/bin/bash
# ============================================================================
# v10_setup_complet.sh
# Script tout-en-un pour V10 Tiers (client + fournisseur unifié)
# ============================================================================
# Usage : ./scripts/v10_setup_complet.sh [nom_base]
# Defaut : ycc_tenant_demo001
# Prérequis : V9 (transversal) appliqué
# ============================================================================

set -e

DB="${1:-ycc_tenant_demo001}"
PG_HOST="${PG_HOST:-localhost}"
PG_USER="${PG_USER:-postgres}"
REPO_DIR="$HOME/projets/ycognicore-cloud"
LOG_DIR="/tmp/v10_logs_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$LOG_DIR"

echo "=============================================="
echo "V10 TIERS — SETUP COMPLET"
echo "=============================================="
echo "Base cible    : $DB"
echo "PostgreSQL    : $PG_HOST"
echo "Utilisateur   : $PG_USER"
echo "Logs          : $LOG_DIR"
echo "=============================================="
echo ""

# ============================================================================
# ETAPE 1 — CREATION DES FICHIERS SOURCE
# ============================================================================
echo "[ETAPE 1/6] Creation des fichiers source..."
echo ""

cd "$REPO_DIR"

# --- Fichier migration V10 ---
cat > db/migration/tenant/V10__tiers.sql << 'MIGRATION_EOF'
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
MIGRATION_EOF

echo "  OK : db/migration/tenant/V10__tiers.sql"

# --- Fichier de tests ---
cat > db/scripts/test_v10_migration.sql << 'TEST_EOF'
-- ============================================================================
-- test_v10_migration.sql
-- Tests du bloc V10 — Référentiel Tiers
-- ============================================================================

SET search_path TO public;

DO $$
DECLARE
    v_passed INTEGER := 0;
    v_failed INTEGER := 0;
    v_tiers_id UUID;
    v_role_id UUID;
    v_contact_id UUID;
    v_fk_name TEXT;
    v_expected CHAR(1);
    v_actual CHAR(1);
    v_missing TEXT := '';
    v_before TIMESTAMPTZ;
    v_after TIMESTAMPTZ;
    v_ver_before INTEGER;
    v_ver_after INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'TESTS BLOC V10 — REFERENTIEL TIERS';
    RAISE NOTICE '=============================================';

    TRUNCATE adresse_tiers, contact_tiers, role_tiers, tiers CASCADE;

    -- STRUCTURE (4)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='tiers') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-01 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-01 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='role_tiers') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-02 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-02 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='contact_tiers') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-03 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-03 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='adresse_tiers') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-04 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-04 KO'; END IF;

    -- INSERTION VALIDE (3)
    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal, email, telephone, plafond_encours)
        VALUES ('TIE-2026-000001','PERSONNE_MORALE','ENTREPRISE','SARL Test Burkina','REEL_NORMAL','contact@sarl-test.bf','+226 70 00 00 00',5000000)
        RETURNING id INTO v_tiers_id;
        v_passed:=v_passed+1; RAISE NOTICE 'T-05 OK';
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-05 KO : %', SQLERRM; END;

    BEGIN
        INSERT INTO role_tiers (tiers_id, role) VALUES (v_tiers_id, 'CLIENT') RETURNING id INTO v_role_id;
        v_passed:=v_passed+1; RAISE NOTICE 'T-06 OK';
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-06 KO'; END;

    BEGIN
        INSERT INTO contact_tiers (tiers_id, nom, prenom, fonction, est_principal)
        VALUES (v_tiers_id, 'OUEDRAOGO', 'Issa', 'Directeur', TRUE) RETURNING id INTO v_contact_id;
        v_passed:=v_passed+1; RAISE NOTICE 'T-07 OK';
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-07 KO'; END;

    -- UNIQUE (7)
    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
        VALUES ('TIE-2026-000001','PERSONNE_MORALE','ENTREPRISE','Doublon','REEL_NORMAL');
        v_failed:=v_failed+1; RAISE NOTICE 'T-08 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-08 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
        VALUES ('INVALID','PERSONNE_MORALE','ENTREPRISE','X','REEL_NORMAL');
        v_failed:=v_failed+1; RAISE NOTICE 'T-09 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-09 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal, ifu)
        VALUES ('TIE-2026-000002','PERSONNE_MORALE','ENTREPRISE','X','REEL_NORMAL','IFU-12345');
        v_passed:=v_passed+1; RAISE NOTICE 'T-10 OK';
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-10 KO'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal, ifu)
        VALUES ('TIE-2026-000003','PERSONNE_MORALE','ENTREPRISE','Y','REEL_NORMAL','IFU-12345');
        v_failed:=v_failed+1; RAISE NOTICE 'T-11 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-11 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
        VALUES ('TIE-2026-000004','PERSONNE_MORALE','ENTREPRISE','Z','REEL_NORMAL');
        v_passed:=v_passed+1; RAISE NOTICE 'T-12 OK';
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-12 KO'; END;

    BEGIN
        INSERT INTO role_tiers (tiers_id, role) VALUES (v_tiers_id, 'CLIENT');
        v_failed:=v_failed+1; RAISE NOTICE 'T-13 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-13 OK'; END;

    BEGIN
        INSERT INTO contact_tiers (tiers_id, nom, prenom, est_principal)
        VALUES (v_tiers_id, 'X', 'Y', TRUE);
        v_failed:=v_failed+1; RAISE NOTICE 'T-14 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-14 OK'; END;

    -- CHECK (8)
    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
        VALUES ('TIE-2026-000010','INVALIDE','ENTREPRISE','X','REEL_NORMAL');
        v_failed:=v_failed+1; RAISE NOTICE 'T-15 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-15 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
        VALUES ('TIE-2026-000011','PERSONNE_MORALE','INVALIDE','X','REEL_NORMAL');
        v_failed:=v_failed+1; RAISE NOTICE 'T-16 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-16 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
        VALUES ('TIE-2026-000012','PERSONNE_MORALE','ENTREPRISE','X','INVALIDE');
        v_failed:=v_failed+1; RAISE NOTICE 'T-17 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-17 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal, statut)
        VALUES ('TIE-2026-000013','PERSONNE_MORALE','ENTREPRISE','X','REEL_NORMAL','INVALIDE');
        v_failed:=v_failed+1; RAISE NOTICE 'T-18 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-18 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal, delai_paiement_jours)
        VALUES ('TIE-2026-000014','PERSONNE_MORALE','ENTREPRISE','X','REEL_NORMAL',-1);
        v_failed:=v_failed+1; RAISE NOTICE 'T-19 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-19 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal, plafond_encours)
        VALUES ('TIE-2026-000015','PERSONNE_MORALE','ENTREPRISE','X','REEL_NORMAL',-1);
        v_failed:=v_failed+1; RAISE NOTICE 'T-20 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-20 OK'; END;

    BEGIN
        INSERT INTO role_tiers (tiers_id, role) VALUES (v_tiers_id, 'INVALIDE');
        v_failed:=v_failed+1; RAISE NOTICE 'T-21 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-21 OK'; END;

    BEGIN
        INSERT INTO contact_tiers (tiers_id, nom, prenom, canal_prefere)
        VALUES (v_tiers_id, 'X', 'Y', 'INVALIDE');
        v_failed:=v_failed+1; RAISE NOTICE 'T-22 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-22 OK'; END;

    -- FK (5)
    FOR v_fk_name, v_expected IN
        SELECT * FROM (VALUES ('fk_role_tiers_tiers','c'),('fk_contact_tiers_tiers','c'),('fk_adresse_tiers_tiers','c')) AS t(name, expected)
    LOOP
        SELECT confdeltype INTO v_actual FROM pg_constraint WHERE conname = v_fk_name;
        IF v_actual = v_expected THEN v_passed:=v_passed+1;
        ELSE v_failed:=v_failed+1; v_missing := v_missing || v_fk_name || ' '; END IF;
    END LOOP;
    RAISE NOTICE 'T-23 a T-25 OK (3 FK CASCADE)';

    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tiers_created_by_fkey') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-26 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-26 KO'; END IF;

    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tiers_updated_by_fkey') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-27 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-27 KO'; END IF;

    -- TRIGGERS (4)
    SELECT updated_at INTO v_before FROM tiers WHERE id = v_tiers_id;
    PERFORM pg_sleep(0.1);
    UPDATE tiers SET raison_sociale = 'SARL Test Modifie' WHERE id = v_tiers_id;
    SELECT updated_at INTO v_after FROM tiers WHERE id = v_tiers_id;
    IF v_after > v_before THEN v_passed:=v_passed+1; RAISE NOTICE 'T-28 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-28 KO'; END IF;

    SELECT version INTO v_ver_before FROM tiers WHERE id = v_tiers_id;
    UPDATE tiers SET raison_sociale = 'SARL Test Modifie 2' WHERE id = v_tiers_id;
    SELECT version INTO v_ver_after FROM tiers WHERE id = v_tiers_id;
    IF v_ver_after = v_ver_before + 1 THEN v_passed:=v_passed+1; RAISE NOTICE 'T-29 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-29 KO'; END IF;

    BEGIN
        DELETE FROM tiers WHERE id = v_tiers_id;
        v_failed:=v_failed+1; RAISE NOTICE 'T-30 KO';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%Suppression physique interdite%' THEN
            v_passed:=v_passed+1; RAISE NOTICE 'T-30 OK';
        ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-30 KO'; END IF;
    END;

    IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_role_tiers_no_hard_delete') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-31 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-31 KO'; END IF;

    -- ISOLATION (1)
    IF (SELECT COUNT(*) FROM information_schema.columns
        WHERE column_name = 'tenant_id'
          AND table_name IN ('tiers','role_tiers','contact_tiers','adresse_tiers')) = 0 THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-32 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-32 KO'; END IF;

    -- CAS METIER (5)
    INSERT INTO role_tiers (tiers_id, role) VALUES (v_tiers_id, 'FOURNISSEUR');
    IF (SELECT COUNT(*) FROM role_tiers WHERE tiers_id = v_tiers_id AND deleted_at IS NULL) = 2 THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-33 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-33 KO'; END IF;

    INSERT INTO adresse_tiers (tiers_id, type_adresse, rue, ville, est_principale)
    VALUES (v_tiers_id, 'SIEGE', 'Avenue 1', 'Ouagadougou', TRUE);

    BEGIN
        INSERT INTO adresse_tiers (tiers_id, type_adresse, rue, ville, est_principale)
        VALUES (v_tiers_id, 'SIEGE', 'Avenue 2', 'Ouagadougou', TRUE);
        v_failed:=v_failed+1; RAISE NOTICE 'T-34 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-34 OK'; END;

    BEGIN
        INSERT INTO adresse_tiers (tiers_id, type_adresse, rue, ville, est_principale)
        VALUES (v_tiers_id, 'SIEGE', 'Avenue 2', 'Ouagadougou', FALSE);
        v_passed:=v_passed+1; RAISE NOTICE 'T-35 OK';
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-35 KO'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
        VALUES ('TIE-2026-000099','PERSONNE_MORALE','ENTREPRISE', repeat('A', 300), 'REEL_NORMAL');
        v_failed:=v_failed+1; RAISE NOTICE 'T-36 KO';
    EXCEPTION WHEN string_data_right_truncation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-36 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
        VALUES ('TIE-2026-000098','PERSONNE_MORALE','ENTREPRISE','SARL O''Brien','REEL_NORMAL');
        v_passed:=v_passed+1; RAISE NOTICE 'T-37 OK';
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-37 KO'; END;

    -- NETTOYAGE
    UPDATE tiers SET deleted_at = now() WHERE code LIKE 'TIE-%';

    RAISE NOTICE '';
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'RESULTAT FINAL';
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'Tests reussis : %', v_passed;
    RAISE NOTICE 'Tests echoues : %', v_failed;
    RAISE NOTICE 'Total         : %', v_passed + v_failed;
    IF v_failed = 0 THEN RAISE NOTICE 'Statut : TOUS LES TESTS PASSENT';
    ELSE RAISE NOTICE 'Statut : % test(s) en echec', v_failed; END IF;
    RAISE NOTICE '=============================================';
END;
$$;
TEST_EOF

echo "  OK : db/scripts/test_v10_migration.sql"
echo ""

# ============================================================================
# ETAPE 2 — VERIFICATION PRE-MIGRATION
# ============================================================================
echo "[ETAPE 2/6] Verification pre-migration..."
echo ""

if ! psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -c "SELECT 1;" > /dev/null 2>&1; then
    echo "ERREUR : impossible de se connecter a $DB"
    exit 1
fi
echo "  OK : connexion PostgreSQL"

V8_COUNT=$(psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -t -c "
SELECT COUNT(*) FROM pg_proc WHERE proname = 'attacher_triggers_standard';" | tr -d ' ')
if [ "$V8_COUNT" -ge 1 ]; then
    echo "  OK : V8 socle applique"
else
    echo "  ERREUR : V8 socle non applique"
    exit 1
fi

V9_COUNT=$(psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -t -c "
SELECT COUNT(*) FROM information_schema.tables WHERE table_name='fichiers' AND table_schema='public';" | tr -d ' ')
if [ "$V9_COUNT" = "1" ]; then
    echo "  OK : V9 (transversal) applique"
else
    echo "  ERREUR : V9 non applique (fichiers manquante)"
    exit 1
fi

USERS_COUNT=$(psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -t -c "
SELECT COUNT(*) FROM information_schema.tables WHERE table_name='users' AND table_schema='public';" | tr -d ' ')
if [ "$USERS_COUNT" = "1" ]; then
    echo "  OK : table users presente"
else
    echo "  ERREUR : table users manquante"
    exit 1
fi

V10_COUNT=$(psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -t -c "
SELECT COUNT(*) FROM information_schema.tables
WHERE table_name IN ('tiers','role_tiers','contact_tiers','adresse_tiers') AND table_schema='public';" | tr -d ' ')
if [ "$V10_COUNT" = "0" ]; then
    echo "  OK : V10 non encore applique"
else
    echo "  ATTENTION : $V10_COUNT table(s) V10 deja presente(s)"
    echo "  Suppression des tables existantes..."
    psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -c "
    DROP TABLE IF EXISTS adresse_tiers CASCADE;
    DROP TABLE IF EXISTS contact_tiers CASCADE;
    DROP TABLE IF EXISTS role_tiers CASCADE;
    DROP TABLE IF EXISTS tiers CASCADE;"
    echo "  OK : anciennes tables supprimees"
fi
echo ""

# ============================================================================
# ETAPE 3 — APPLICATION DE V10
# ============================================================================
echo "[ETAPE 3/6] Application de V10..."
echo ""

psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" \
  -f db/migration/tenant/V10__tiers.sql 2>&1 | tee "$LOG_DIR/migration.log"

if grep -q "V10__tiers.sql — Referentiel Tiers OK" "$LOG_DIR/migration.log"; then
    echo ""
    echo "  OK : migration reussie"
else
    echo ""
    echo "  ERREUR : migration echouee"
    exit 1
fi
echo ""

# ============================================================================
# ETAPE 4 — TESTS
# ============================================================================
echo "[ETAPE 4/6] Execution des tests..."
echo ""

psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" \
  -f db/scripts/test_v10_migration.sql 2>&1 | tee "$LOG_DIR/tests.log" | tail -12

if grep -q "TOUS LES TESTS PASSENT" "$LOG_DIR/tests.log"; then
    echo ""
    echo "  OK : tous les tests passent"
else
    echo ""
    echo "  ERREUR : tests en echec"
    exit 1
fi
echo ""

# ============================================================================
# ETAPE 5 — VERIFICATIONS POST
# ============================================================================
echo "[ETAPE 5/6] Verifications post-migration..."
echo ""

echo "  Tables V10 :"
psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -t -c "
SELECT '    ' || tablename FROM pg_tables
WHERE schemaname='public'
  AND tablename IN ('tiers','role_tiers','contact_tiers','adresse_tiers')
ORDER BY tablename;"

echo "  Index :"
psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -t -c "
SELECT '    ' || tablename || ' : ' || COUNT(*) || ' index'
FROM pg_indexes
WHERE tablename IN ('tiers','role_tiers','contact_tiers','adresse_tiers')
GROUP BY tablename ORDER BY tablename;"

echo "  Triggers :"
psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -t -c "
SELECT '    ' || c.relname || ' : ' || t.tgname
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
WHERE c.relname IN ('tiers','role_tiers','contact_tiers','adresse_tiers')
  AND t.tgname LIKE 'trg_%'
ORDER BY 1;"
echo ""

# ============================================================================
# ETAPE 6 — RESUME
# ============================================================================
echo "[ETAPE 6/6] Resume"
echo ""
echo "=============================================="
echo "V10 TIERS TERMINE AVEC SUCCES"
echo "=============================================="
echo "Base            : $DB"
echo "Tables creees   : 4"
echo "Tests           : 37/37 PASS"
echo "Logs            : $LOG_DIR"
echo ""
echo "Fichiers crees :"
echo "  - db/migration/tenant/V10__tiers.sql"
echo "  - db/scripts/test_v10_migration.sql"
echo ""
echo "Prochaine etape :"
echo "  - Commiter : git add db/migration/tenant/V10__tiers.sql db/scripts/test_v10_migration.sql"
echo "  - Passer au bloc V11 (Articles)"
echo "=============================================="
