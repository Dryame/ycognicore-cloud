-- =====================================================================
-- V4__add_transversal_tables.sql
-- Base : ycc_control_plane
-- Objet : Référentiel global modules + tables transversales
-- Réf.  : ADR-001, Audit 29/09/2026 (P1, P7, P13)
-- =====================================================================

CREATE TABLE IF NOT EXISTS modules (
    id              SERIAL PRIMARY KEY,
    code            VARCHAR(30) NOT NULL UNIQUE,
    libelle         VARCHAR(100) NOT NULL,
    ordre_affichage SMALLINT NOT NULL DEFAULT 0,
    date_creation   TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO modules (code, libelle, ordre_affichage) VALUES
    ('TABLEAU_DE_BORD', 'Tableau de bord', 1),
    ('CRM', 'CRM', 2),
    ('VENTES', 'Ventes', 3),
    ('ACHATS', 'Achats', 4),
    ('CLIENTS', 'Clients', 5),
    ('FOURNISSEURS', 'Fournisseurs', 6),
    ('ARTICLES', 'Articles', 7),
    ('STOCK', 'Stock', 8),
    ('TRESORERIE', 'Trésorerie', 9),
    ('COMPTABILITE', 'Comptabilité & Fiscalité', 10),
    ('PROJETS', 'Projets', 11),
    ('NOTIFICATIONS', 'Notifications intelligentes', 12),
    ('RAPPORTS_BI', 'Rapports & Business Intelligence', 13),
    ('RECHERCHE', 'Recherche globale', 14),
    ('SAUVEGARDE', 'Sauvegarde', 15),
    ('PARAMETRES', 'Paramètres', 16)
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS formule_caracteristiques (
    id                  SERIAL PRIMARY KEY,
    formule             formule_abonnement NOT NULL,
    quota_ia_mensuel    INTEGER NOT NULL CHECK (quota_ia_mensuel >= 0),
    quota_utilisateurs  INTEGER CHECK (quota_utilisateurs IS NULL OR quota_utilisateurs > 0),
    quota_stockage_go   INTEGER CHECK (quota_stockage_go IS NULL OR quota_stockage_go > 0),
    prix_mensuel        NUMERIC(12,2) NOT NULL CHECK (prix_mensuel >= 0),
    devise              VARCHAR(3) NOT NULL DEFAULT 'XOF',
    date_effet          DATE NOT NULL DEFAULT CURRENT_DATE,
    date_fin            DATE,
    actif               BOOLEAN NOT NULL DEFAULT TRUE,
    date_creation       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_formule_date_effet UNIQUE (formule, date_effet),
    CONSTRAINT chk_dates_formule CHECK (date_fin IS NULL OR date_fin >= date_effet)
);

CREATE TABLE IF NOT EXISTS formule_modules (
    formule_caracteristique_id INTEGER NOT NULL
        REFERENCES formule_caracteristiques(id) ON DELETE CASCADE,
    module_id                  INTEGER NOT NULL
        REFERENCES modules(id) ON DELETE RESTRICT,
    PRIMARY KEY (formule_caracteristique_id, module_id)
);

CREATE INDEX IF NOT EXISTS idx_formule_modules_module ON formule_modules (module_id);

INSERT INTO formule_caracteristiques
    (formule, quota_ia_mensuel, quota_utilisateurs, quota_stockage_go, prix_mensuel)
VALUES
    ('TRIAL',      100,    5,    1,      0),
    ('STANDARD',   1000,   25,   20,     25000),
    ('ENTERPRISE', 10000,  500,  500,    150000)
ON CONFLICT (formule, date_effet) DO NOTHING;

INSERT INTO formule_modules (formule_caracteristique_id, module_id)
SELECT fc.id, m.id
FROM formule_caracteristiques fc
CROSS JOIN modules m
WHERE NOT EXISTS (
    SELECT 1 FROM formule_modules fm
    WHERE fm.formule_caracteristique_id = fc.id AND fm.module_id = m.id
);

CREATE TABLE IF NOT EXISTS numero_sequences (
    id              SERIAL PRIMARY KEY,
    type_document   VARCHAR(50) NOT NULL,
    prefixe         VARCHAR(20) NOT NULL,
    annee           INTEGER NOT NULL,
    dernier_numero  INTEGER NOT NULL DEFAULT 0 CHECK (dernier_numero >= 0),
    format          VARCHAR(100) NOT NULL DEFAULT '{PREFIXE}-{ANNEE}-{NUMERO:06d}',
    date_maj        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_numero_seq UNIQUE (type_document, annee)
);

INSERT INTO numero_sequences (type_document, prefixe, annee)
VALUES ('FACTURE_SAAS', 'FAC-SaaS', EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER)
ON CONFLICT (type_document, annee) DO NOTHING;

CREATE OR REPLACE FUNCTION prochain_numero(p_type_document VARCHAR, p_annee INTEGER)
RETURNS VARCHAR AS $$
DECLARE
    v_prefixe VARCHAR(20);
    v_format VARCHAR(100);
    v_numero INTEGER;
BEGIN
    UPDATE numero_sequences
    SET dernier_numero = dernier_numero + 1, date_maj = now()
    WHERE type_document = p_type_document AND annee = p_annee
    RETURNING prefixe, format, dernier_numero INTO v_prefixe, v_format, v_numero;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Séquence introuvable : % / %', p_type_document, p_annee;
    END IF;

    RETURN replace(
        replace(replace(v_format, '{PREFIXE}', v_prefixe), '{ANNEE}', p_annee::TEXT),
        '{NUMERO:06d}', lpad(v_numero::TEXT, 6, '0')
    );
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS payment_transactions (
    id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id                 UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    subscription_invoice_id   UUID REFERENCES subscription_invoices(id),
    aggregateur               VARCHAR(30) NOT NULL CHECK (aggregateur IN ('PAYDUNYA', 'LIGDICASH')),
    reference_externe         VARCHAR(150) NOT NULL UNIQUE,
    montant                   NUMERIC(12,2) NOT NULL CHECK (montant >= 0),
    devise                    VARCHAR(3) NOT NULL DEFAULT 'XOF',
    mode_paiement             VARCHAR(30) NOT NULL CHECK (mode_paiement IN ('MOBILE_MONEY', 'CARTE_BANCAIRE')),
    operateur                 VARCHAR(30),
    statut                    VARCHAR(30) NOT NULL DEFAULT 'INITIEE'
        CHECK (statut IN ('INITIEE','EN_ATTENTE','REUSSIE','ECHOUEE','ANNULEE','REMBOURSEE')),
    date_initiation           TIMESTAMPTZ NOT NULL DEFAULT now(),
    date_confirmation         TIMESTAMPTZ,
    payload_retour            JSONB
);

CREATE INDEX IF NOT EXISTS idx_payment_tx_tenant ON payment_transactions (tenant_id, date_initiation DESC);
CREATE INDEX IF NOT EXISTS idx_payment_tx_statut ON payment_transactions (statut);

CREATE TABLE IF NOT EXISTS webhook_events (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregateur        VARCHAR(30) NOT NULL,
    event_id_externe   VARCHAR(150) NOT NULL,
    signature          VARCHAR(500),
    payload_brut       JSONB NOT NULL,
    statut_traitement  VARCHAR(30) NOT NULL DEFAULT 'RECU'
        CHECK (statut_traitement IN ('RECU','TRAITE','REJETE','DOUBLON')),
    date_reception     TIMESTAMPTZ NOT NULL DEFAULT now(),
    date_traitement    TIMESTAMPTZ,
    erreur             TEXT,
    CONSTRAINT uq_webhook_event UNIQUE (aggregateur, event_id_externe)
);

CREATE INDEX IF NOT EXISTS idx_webhook_statut ON webhook_events (statut_traitement, date_reception DESC);

CREATE TABLE IF NOT EXISTS alertes_securite (
    id              BIGSERIAL PRIMARY KEY,
    tenant_id       UUID REFERENCES tenants(id) ON DELETE CASCADE,
    type_alerte     VARCHAR(50) NOT NULL,
    severite        VARCHAR(20) NOT NULL CHECK (severite IN ('INFO','AVERTISSEMENT','CRITIQUE')),
    description     TEXT NOT NULL,
    source          VARCHAR(100),
    ip              INET,
    user_id         UUID,
    statut          VARCHAR(20) NOT NULL DEFAULT 'NOUVELLE'
        CHECK (statut IN ('NOUVELLE','EN_COURS','RESOLUE','IGNOREE')),
    date_creation   TIMESTAMPTZ NOT NULL DEFAULT now(),
    date_resolution TIMESTAMPTZ,
    details         JSONB
);

CREATE INDEX IF NOT EXISTS idx_alertes_sev_statut ON alertes_securite (severite, statut, date_creation DESC);

CREATE TABLE IF NOT EXISTS notifications_queue (
    id              BIGSERIAL PRIMARY KEY,
    tenant_id       UUID REFERENCES tenants(id) ON DELETE CASCADE,
    destinataire    VARCHAR(255) NOT NULL,
    canal           VARCHAR(30) NOT NULL
        CHECK (canal IN ('EMAIL','SMS','WHATSAPP','TELEGRAM','PUSH','FACEBOOK')),
    sujet           VARCHAR(255),
    contenu         TEXT NOT NULL,
    statut          VARCHAR(20) NOT NULL DEFAULT 'EN_ATTENTE'
        CHECK (statut IN ('EN_ATTENTE','ENVOYEE','ECHOUEE','ANNULEE')),
    tentatives      SMALLINT NOT NULL DEFAULT 0,
    next_retry_at   TIMESTAMPTZ,
    date_creation   TIMESTAMPTZ NOT NULL DEFAULT now(),
    date_envoi      TIMESTAMPTZ,
    erreur          TEXT,
    metadata        JSONB
);

CREATE INDEX IF NOT EXISTS idx_notif_statut ON notifications_queue (statut, date_creation);
CREATE INDEX IF NOT EXISTS idx_notif_next_retry ON notifications_queue (next_retry_at) WHERE statut = 'ECHOUEE';

CREATE TABLE IF NOT EXISTS jobs_async (
    id                BIGSERIAL PRIMARY KEY,
    type_job          VARCHAR(100) NOT NULL,
    tenant_id         UUID REFERENCES tenants(id) ON DELETE CASCADE,
    payload           JSONB NOT NULL,
    statut            VARCHAR(20) NOT NULL DEFAULT 'EN_ATTENTE'
        CHECK (statut IN ('EN_ATTENTE','EN_COURS','TERMINE','ECHOUE')),
    priorite          SMALLINT NOT NULL DEFAULT 5 CHECK (priorite BETWEEN 1 AND 10),
    tentatives        SMALLINT NOT NULL DEFAULT 0,
    max_tentatives    SMALLINT NOT NULL DEFAULT 3,
    next_retry_at     TIMESTAMPTZ,
    date_creation     TIMESTAMPTZ NOT NULL DEFAULT now(),
    date_debut        TIMESTAMPTZ,
    date_fin          TIMESTAMPTZ,
    erreur            TEXT
);

CREATE INDEX IF NOT EXISTS idx_jobs_statut_prio ON jobs_async (statut, priorite, date_creation);
CREATE INDEX IF NOT EXISTS idx_jobs_next_retry ON jobs_async (next_retry_at) WHERE statut = 'ECHOUE';

GRANT SELECT, INSERT, UPDATE, DELETE ON
    modules, formule_caracteristiques, formule_modules,
    numero_sequences, payment_transactions, webhook_events,
    alertes_securite, notifications_queue, jobs_async
TO ycc_control_plane_app;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ycc_control_plane_app;
GRANT EXECUTE ON FUNCTION prochain_numero(VARCHAR, INTEGER) TO ycc_control_plane_app;
