-- ============================================================================
-- V12__crm.sql
-- Base : ycc_tenant_<id>
-- Objet : Module CRM (14 tables : prospects, contacts, campagnes, pipeline, suivi, workflow)
-- Réf.  : Design Bible Phase 2 — Bloc V12
-- ============================================================================

SET search_path TO public;

-- ============================================================================
-- SECTION 1 — ACTEURS
-- ============================================================================

CREATE TABLE prospects (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                        VARCHAR(30) NOT NULL,
    nom                         VARCHAR(255) NOT NULL,
    email                       CITEXT,
    telephone                   VARCHAR(30),
    source                      VARCHAR(30) NOT NULL DEFAULT 'AUTRE',
    score_ia                    SMALLINT DEFAULT 0,
    score_manuel                SMALLINT DEFAULT 0,
    consentement_email          BOOLEAN NOT NULL DEFAULT FALSE,
    consentement_sms            BOOLEAN NOT NULL DEFAULT FALSE,
    consentement_whatsapp       BOOLEAN NOT NULL DEFAULT FALSE,
    tiers_id                    UUID REFERENCES tiers(id) ON DELETE SET NULL,
    converti                    BOOLEAN NOT NULL DEFAULT FALSE,
    date_conversion             TIMESTAMPTZ,
    statut                      VARCHAR(20) NOT NULL DEFAULT 'NOUVEAU',
    notes                       TEXT,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at                  TIMESTAMPTZ,
    version                     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_prospects_source
        CHECK (source IN ('WEB','SALON','RECOMMANDATION','PUB','AUTRE')),
    CONSTRAINT chk_prospects_statut
        CHECK (statut IN ('NOUVEAU','CONTACTE','QUALIFIE','CONVERTI','PERDU')),
    CONSTRAINT chk_prospects_score
        CHECK (score_ia BETWEEN 0 AND 100 AND score_manuel BETWEEN 0 AND 100),
    CONSTRAINT uq_prospects_code UNIQUE (code)
);
CREATE INDEX idx_prospects_statut ON prospects (statut) WHERE deleted_at IS NULL;
CREATE INDEX idx_prospects_tiers ON prospects (tiers_id) WHERE tiers_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_prospects_converti ON prospects (converti) WHERE deleted_at IS NULL;

CREATE TABLE contacts (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tiers_id                    UUID NOT NULL,
    nom                         VARCHAR(100) NOT NULL,
    prenom                      VARCHAR(100) NOT NULL,
    fonction                    VARCHAR(100),
    email                       CITEXT,
    telephone                   VARCHAR(30),
    canal_prefere               VARCHAR(20) NOT NULL DEFAULT 'EMAIL',
    langue                      VARCHAR(5) NOT NULL DEFAULT 'fr',
    est_principal               BOOLEAN NOT NULL DEFAULT FALSE,
    notes                       TEXT,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at                  TIMESTAMPTZ,
    version                     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_contacts_canal
        CHECK (canal_prefere IN ('EMAIL','SMS','WHATSAPP','APPEL')),
    CONSTRAINT fk_contacts_tiers
        FOREIGN KEY (tiers_id) REFERENCES tiers(id) ON DELETE RESTRICT
);
CREATE INDEX idx_contacts_tiers ON contacts (tiers_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX uq_contacts_principal
    ON contacts (tiers_id) WHERE est_principal AND deleted_at IS NULL;

CREATE TABLE campagnes (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                        VARCHAR(30) NOT NULL,
    nom                         VARCHAR(255) NOT NULL,
    type_campagne               VARCHAR(30) NOT NULL,
    date_debut                  DATE NOT NULL,
    date_fin                    DATE,
    budget                      NUMERIC(15,2),
    objectif                    TEXT,
    statut                      VARCHAR(20) NOT NULL DEFAULT 'PLANIFIEE',
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at                  TIMESTAMPTZ,
    version                     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_campagnes_type
        CHECK (type_campagne IN ('EMAILING','SMS','WHATSAPP','TELEMARKETING','EVENEMENT','RESEAUX')),
    CONSTRAINT chk_campagnes_statut
        CHECK (statut IN ('PLANIFIEE','EN_COURS','TERMINEE','ANNULEE')),
    CONSTRAINT chk_campagnes_dates
        CHECK (date_fin IS NULL OR date_fin >= date_debut),
    CONSTRAINT chk_campagnes_budget
        CHECK (budget IS NULL OR budget >= 0),
    CONSTRAINT uq_campagnes_code UNIQUE (code)
);
CREATE INDEX idx_campagnes_statut ON campagnes (statut) WHERE deleted_at IS NULL;

CREATE TABLE campagne_cibles (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campagne_id                 UUID NOT NULL,
    prospect_id                 UUID,
    contact_id                  UUID,
    statut_envoi                VARCHAR(20) NOT NULL DEFAULT 'EN_ATTENTE',
    date_envoi                  TIMESTAMPTZ,
    reponse                     VARCHAR(20),
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at                  TIMESTAMPTZ,
    version                     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_campagne_cibles_statut
        CHECK (statut_envoi IN ('EN_ATTENTE','ENVOYE','OUVERT','CLIQUE','REPONDU','ERREUR')),
    CONSTRAINT chk_campagne_cibles_rattachement
        CHECK (prospect_id IS NOT NULL OR contact_id IS NOT NULL),
    CONSTRAINT fk_campagne_cibles_campagne
        FOREIGN KEY (campagne_id) REFERENCES campagnes(id) ON DELETE CASCADE,
    CONSTRAINT fk_campagne_cibles_prospect
        FOREIGN KEY (prospect_id) REFERENCES prospects(id) ON DELETE CASCADE,
    CONSTRAINT fk_campagne_cibles_contact
        FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE
);

-- ============================================================================
-- SECTION 2 — PIPELINE
-- ============================================================================

CREATE TABLE pipelines (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                        VARCHAR(30) NOT NULL,
    nom                         VARCHAR(100) NOT NULL,
    est_standard                BOOLEAN NOT NULL DEFAULT FALSE,
    actif                       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at                  TIMESTAMPTZ,
    version                     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT uq_pipelines_code UNIQUE (code)
);

CREATE TABLE pipeline_etapes (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pipeline_id                 UUID NOT NULL,
    code                        VARCHAR(30) NOT NULL,
    libelle                     VARCHAR(100) NOT NULL,
    ordre                       SMALLINT NOT NULL,
    pourcentage_default         SMALLINT NOT NULL DEFAULT 0,
    actif                       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at                  TIMESTAMPTZ,
    version                     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_pipeline_etapes_pct
        CHECK (pourcentage_default BETWEEN 0 AND 100),
    CONSTRAINT uq_pipeline_etapes UNIQUE (pipeline_id, code),
    CONSTRAINT uq_pipeline_etapes_ordre UNIQUE (pipeline_id, ordre),
    CONSTRAINT fk_pipeline_etapes_pipeline
        FOREIGN KEY (pipeline_id) REFERENCES pipelines(id) ON DELETE CASCADE
);
CREATE INDEX idx_pipeline_etapes_pipeline ON pipeline_etapes (pipeline_id) WHERE deleted_at IS NULL;

CREATE TABLE opportunites (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                        VARCHAR(30) NOT NULL,
    nom                         VARCHAR(255) NOT NULL,
    tiers_id                    UUID NOT NULL,
    prospect_id                 UUID,
    pipeline_etape_id           UUID NOT NULL,
    montant_estime              NUMERIC(15,2) NOT NULL,
    devise                      VARCHAR(3) NOT NULL DEFAULT 'XOF',
    probabilite_manuelle        SMALLINT NOT NULL DEFAULT 0,
    probabilite_ia              SMALLINT,
    date_cloture_prevue         DATE NOT NULL,
    date_cloture_reelle         DATE,
    statut                      VARCHAR(20) NOT NULL DEFAULT 'OUVERTE',
    description                 TEXT,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at                  TIMESTAMPTZ,
    version                     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_opportunites_montant
        CHECK (montant_estime > 0),
    CONSTRAINT chk_opportunites_probabilite
        CHECK (probabilite_manuelle BETWEEN 0 AND 100
               AND (probabilite_ia IS NULL OR probabilite_ia BETWEEN 0 AND 100)),
    CONSTRAINT chk_opportunites_statut
        CHECK (statut IN ('OUVERTE','EN_NEGOCIATION','GAGNEE','PERDUE','ABANDONNEE')),
    CONSTRAINT uq_opportunites_code UNIQUE (code),
    CONSTRAINT fk_opportunites_tiers
        FOREIGN KEY (tiers_id) REFERENCES tiers(id) ON DELETE RESTRICT,
    CONSTRAINT fk_opportunites_prospect
        FOREIGN KEY (prospect_id) REFERENCES prospects(id) ON DELETE SET NULL,
    CONSTRAINT fk_opportunites_etape
        FOREIGN KEY (pipeline_etape_id) REFERENCES pipeline_etapes(id) ON DELETE RESTRICT
);
CREATE INDEX idx_opportunites_tiers ON opportunites (tiers_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_opportunites_statut ON opportunites (statut) WHERE deleted_at IS NULL;
CREATE INDEX idx_opportunites_etape ON opportunites (pipeline_etape_id) WHERE deleted_at IS NULL;

CREATE TABLE opportunites_historique_etapes (
    id                          BIGSERIAL PRIMARY KEY,
    opportunite_id              UUID NOT NULL,
    pipeline_etape_id           UUID NOT NULL,
    date_transition             TIMESTAMPTZ NOT NULL DEFAULT now(),
    change_par                  UUID REFERENCES users(id) ON DELETE SET NULL,
    commentaire                 TEXT,
    CONSTRAINT fk_opp_hist_opportunite
        FOREIGN KEY (opportunite_id) REFERENCES opportunites(id) ON DELETE CASCADE,
    CONSTRAINT fk_opp_hist_etape
        FOREIGN KEY (pipeline_etape_id) REFERENCES pipeline_etapes(id) ON DELETE RESTRICT
);
CREATE INDEX idx_opp_hist_opportunite ON opportunites_historique_etapes (opportunite_id, date_transition DESC);

-- ============================================================================
-- SECTION 3 — SUIVI
-- ============================================================================

CREATE TABLE activites (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type_activite               VARCHAR(20) NOT NULL,
    sujet                       VARCHAR(255) NOT NULL,
    description                 TEXT,
    date_debut                  TIMESTAMPTZ NOT NULL,
    date_fin                    TIMESTAMPTZ,
    statut                      VARCHAR(20) NOT NULL DEFAULT 'PLANIFIEE',
    assigne_a                   UUID REFERENCES users(id) ON DELETE SET NULL,
    prospect_id                 UUID,
    contact_id                  UUID,
    opportunite_id              UUID,
    campagne_id                 UUID,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at                  TIMESTAMPTZ,
    version                     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_activites_type
        CHECK (type_activite IN ('APPEL','EMAIL','RDV','VISITE','TACHE','NOTE')),
    CONSTRAINT chk_activites_statut
        CHECK (statut IN ('PLANIFIEE','EN_COURS','TERMINEE','ANNULEE')),
    CONSTRAINT chk_activites_rattachement
        CHECK (prospect_id IS NOT NULL OR contact_id IS NOT NULL
               OR opportunite_id IS NOT NULL OR campagne_id IS NOT NULL),
    CONSTRAINT fk_activites_prospect
        FOREIGN KEY (prospect_id) REFERENCES prospects(id) ON DELETE SET NULL,
    CONSTRAINT fk_activites_contact
        FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE SET NULL,
    CONSTRAINT fk_activites_opportunite
        FOREIGN KEY (opportunite_id) REFERENCES opportunites(id) ON DELETE SET NULL,
    CONSTRAINT fk_activites_campagne
        FOREIGN KEY (campagne_id) REFERENCES campagnes(id) ON DELETE SET NULL
);

CREATE TABLE interactions (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type_interaction            VARCHAR(20) NOT NULL,
    canal                       VARCHAR(20) NOT NULL,
    sujet                       VARCHAR(255) NOT NULL,
    contenu                     TEXT,
    date_interaction            TIMESTAMPTZ NOT NULL DEFAULT now(),
    duree_minutes               INTEGER,
    sentiment_ia                VARCHAR(20),
    resume_ia                   TEXT,
    prospect_id                 UUID,
    contact_id                  UUID,
    opportunite_id              UUID,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT chk_interactions_type
        CHECK (type_interaction IN ('APPEL','EMAIL','SMS','WHATSAPP','VISITE','REUNION','AUTRE')),
    CONSTRAINT chk_interactions_sentiment
        CHECK (sentiment_ia IS NULL OR sentiment_ia IN ('POSITIF','NEUTRE','NEGATIF')),
    CONSTRAINT chk_interactions_rattachement
        CHECK (prospect_id IS NOT NULL OR contact_id IS NOT NULL OR opportunite_id IS NOT NULL),
    CONSTRAINT fk_interactions_prospect
        FOREIGN KEY (prospect_id) REFERENCES prospects(id) ON DELETE SET NULL,
    CONSTRAINT fk_interactions_contact
        FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE SET NULL,
    CONSTRAINT fk_interactions_opportunite
        FOREIGN KEY (opportunite_id) REFERENCES opportunites(id) ON DELETE SET NULL
);
CREATE INDEX idx_interactions_date ON interactions (date_interaction DESC);
CREATE INDEX idx_interactions_prospect ON interactions (prospect_id) WHERE prospect_id IS NOT NULL;

CREATE TABLE rendez_vous (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    titre                       VARCHAR(255) NOT NULL,
    description                 TEXT,
    date_debut                  TIMESTAMPTZ NOT NULL,
    date_fin                    TIMESTAMPTZ NOT NULL,
    lieu                        VARCHAR(255),
    statut                      VARCHAR(20) NOT NULL DEFAULT 'PLANIFIE',
    prospect_id                 UUID,
    contact_id                  UUID,
    opportunite_id              UUID,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at                  TIMESTAMPTZ,
    version                     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_rdv_statut
        CHECK (statut IN ('PLANIFIE','CONFIRME','REALISE','ANNULE')),
    CONSTRAINT chk_rdv_dates
        CHECK (date_fin > date_debut),
    CONSTRAINT fk_rdv_prospect
        FOREIGN KEY (prospect_id) REFERENCES prospects(id) ON DELETE SET NULL,
    CONSTRAINT fk_rdv_contact
        FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE SET NULL,
    CONSTRAINT fk_rdv_opportunite
        FOREIGN KEY (opportunite_id) REFERENCES opportunites(id) ON DELETE SET NULL
);
CREATE INDEX idx_rdv_date_debut ON rendez_vous (date_debut) WHERE deleted_at IS NULL;

CREATE TABLE rendez_vous_participants (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rendez_vous_id              UUID NOT NULL,
    user_id                     UUID,
    contact_id                  UUID,
    statut_presence             VARCHAR(20) NOT NULL DEFAULT 'INVITE',
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_rdv_part_presence
        CHECK (statut_presence IN ('INVITE','CONFIRME','PRESENT','ABSENT')),
    CONSTRAINT chk_rdv_part_rattachement
        CHECK (user_id IS NOT NULL OR contact_id IS NOT NULL),
    CONSTRAINT fk_rdv_part_rdv
        FOREIGN KEY (rendez_vous_id) REFERENCES rendez_vous(id) ON DELETE CASCADE,
    CONSTRAINT fk_rdv_part_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_rdv_part_contact
        FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE CASCADE
);

-- ============================================================================
-- SECTION 4 — WORKFLOW
-- ============================================================================

CREATE TABLE crm_regles_automatisation (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                        VARCHAR(30) NOT NULL,
    nom                         VARCHAR(255) NOT NULL,
    description                 TEXT,
    condition_json              JSONB NOT NULL,
    action_type                 VARCHAR(30) NOT NULL,
    action_json                 JSONB NOT NULL,
    ordre_execution             SMALLINT NOT NULL DEFAULT 0,
    actif                       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at                  TIMESTAMPTZ,
    version                     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_crm_regles_action
        CHECK (action_type IN ('CREER_TACHE','ENVOYER_EMAIL','CHANGER_STATUT','ASSIGNER','NOTIFIER')),
    CONSTRAINT uq_crm_regles_code UNIQUE (code)
);

CREATE TABLE crm_regles_executions (
    id                          BIGSERIAL PRIMARY KEY,
    regle_id                    UUID NOT NULL,
    entite_cible                VARCHAR(50) NOT NULL,
    entite_id                   UUID NOT NULL,
    date_execution              TIMESTAMPTZ NOT NULL DEFAULT now(),
    succes                      BOOLEAN NOT NULL,
    details                     JSONB,
    erreur                      TEXT,
    CONSTRAINT fk_crm_regles_exec_regle
        FOREIGN KEY (regle_id) REFERENCES crm_regles_automatisation(id) ON DELETE CASCADE
);
CREATE INDEX idx_crm_regles_exec_regle ON crm_regles_executions (regle_id, date_execution DESC);
CREATE INDEX idx_crm_regles_exec_entite ON crm_regles_executions (entite_cible, entite_id);

-- ============================================================================
-- SECTION 5 — TRIGGERS
-- ============================================================================

SELECT attacher_triggers_standard('prospects');
SELECT attacher_triggers_standard('contacts');
SELECT attacher_triggers_standard('campagnes');
SELECT attacher_triggers_standard('campagne_cibles');
SELECT attacher_triggers_standard('pipelines');
SELECT attacher_triggers_standard('pipeline_etapes');
SELECT attacher_triggers_standard('opportunites');
SELECT attacher_triggers_standard('activites');
SELECT attacher_triggers_standard('rendez_vous');
SELECT attacher_triggers_standard('crm_regles_automatisation');

-- Interactions : append-only
CREATE OR REPLACE FUNCTION empecher_modification_interactions()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Table interactions append-only';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_interactions_append_only
BEFORE UPDATE OR DELETE ON interactions
FOR EACH ROW EXECUTE FUNCTION empecher_modification_interactions();

-- Historique : append-only
CREATE OR REPLACE FUNCTION empecher_modification_opp_hist()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Table opportunites_historique_etapes append-only';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_opp_hist_append_only
BEFORE UPDATE OR DELETE ON opportunites_historique_etapes
FOR EACH ROW EXECUTE FUNCTION empecher_modification_opp_hist();

-- ============================================================================
-- SECTION 6 — SEEDS
-- ============================================================================

-- Pipeline standard
INSERT INTO pipelines (code, nom, est_standard, actif)
VALUES ('STD', 'Pipeline standard', TRUE, TRUE)
ON CONFLICT (code) DO NOTHING;

INSERT INTO pipeline_etapes (pipeline_id, code, libelle, ordre, pourcentage_default)
SELECT p.id, e.code, e.libelle, e.ordre, e.pct
FROM pipelines p
CROSS JOIN (VALUES
    ('PROSPECTION',   'Prospection',    1, 10),
    ('QUALIFICATION', 'Qualification',  2, 25),
    ('PROPOSITION',   'Proposition',    3, 50),
    ('NEGOCIATION',   'Négociation',    4, 75),
    ('CLOTURE',       'Clôture',        5, 90),
    ('GAGNEE',        'Gagnée',         6, 100)
) AS e(code, libelle, ordre, pct)
WHERE p.code = 'STD'
ON CONFLICT (pipeline_id, code) DO NOTHING;

-- ============================================================================
-- SECTION 7 — DROITS
-- ============================================================================

GRANT SELECT, INSERT, UPDATE ON prospects TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON contacts TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON campagnes TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON campagne_cibles TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON pipelines TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON pipeline_etapes TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON opportunites TO ycc_tenant_app;
GRANT SELECT, INSERT ON opportunites_historique_etapes TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON activites TO ycc_tenant_app;
GRANT SELECT, INSERT ON interactions TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON rendez_vous TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON rendez_vous_participants TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON crm_regles_automatisation TO ycc_tenant_app;
GRANT SELECT, INSERT ON crm_regles_executions TO ycc_tenant_app;
GRANT USAGE, SELECT ON SEQUENCE opportunites_historique_etapes_id_seq TO ycc_tenant_app;
GRANT USAGE, SELECT ON SEQUENCE crm_regles_executions_id_seq TO ycc_tenant_app;

-- ============================================================================
-- SECTION 8 — VÉRIFICATIONS
-- ============================================================================

DO $$
DECLARE
    v_nb_tables INTEGER;
    v_nb_etapes INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_nb_tables
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name IN (
        'prospects','contacts','campagnes','campagne_cibles',
        'pipelines','pipeline_etapes','opportunites','opportunites_historique_etapes',
        'activites','interactions','rendez_vous','rendez_vous_participants',
        'crm_regles_automatisation','crm_regles_executions');

    IF v_nb_tables <> 14 THEN
        RAISE EXCEPTION 'Attendu 14 tables V12, trouve %', v_nb_tables;
    END IF;
    RAISE NOTICE '14 tables V12 verifiees';

    SELECT COUNT(*) INTO v_nb_etapes FROM pipeline_etapes;
    IF v_nb_etapes < 6 THEN
        RAISE EXCEPTION 'Seeds pipeline insuffisants : %', v_nb_etapes;
    END IF;
    RAISE NOTICE '% etapes pipeline seedees', v_nb_etapes;

    RAISE NOTICE '=============================================';
    RAISE NOTICE 'V12__crm.sql — Module CRM OK';
    RAISE NOTICE '=============================================';
END;
$$;