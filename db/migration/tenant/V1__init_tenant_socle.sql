-- =====================================================================
-- V1__init_tenant_socle.sql
-- Base : ycc_tenant_<id> (une par entreprise cliente)
-- Objet : Référentiel modules + socle RBAC (6 permissions) + audit
--         trail partitionné par mois
-- Réf. rapport 04-78 : section 1.2.2 / 1.2.4 / 2.3 / 2.4 / section 4
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- ---------------------------------------------------------------------
-- Table : modules
-- Référentiel des modules fonctionnels (section 4 du rapport). Cible de
-- role_permissions.module_id : évite les fautes de frappe qu'un simple
-- VARCHAR libre permettrait (ex. 'VENTE' au lieu de 'VENTES').
-- ---------------------------------------------------------------------
CREATE TABLE modules (
    id              SERIAL PRIMARY KEY,
    code            VARCHAR(30)  NOT NULL UNIQUE,
    libelle         VARCHAR(100) NOT NULL,
    ordre_affichage SMALLINT     NOT NULL DEFAULT 0
);

INSERT INTO modules (code, libelle, ordre_affichage) VALUES
    ('TABLEAU_DE_BORD', 'Tableau de bord',                     1),
    ('CRM',              'CRM',                                 2),
    ('VENTES',           'Ventes',                              3),
    ('ACHATS',           'Achats',                              4),
    ('CLIENTS',          'Clients',                             5),
    ('FOURNISSEURS',     'Fournisseurs',                        6),
    ('ARTICLES',         'Articles',                            7),
    ('STOCK',            'Stock',                               8),
    ('TRESORERIE',       'Trésorerie',                          9),
    ('COMPTABILITE',     'Comptabilité & Fiscalité',           10),
    ('PROJETS',          'Projets',                            11),
    ('NOTIFICATIONS',    'Notifications intelligentes',        12),
    ('RAPPORTS_BI',      'Rapports & Business Intelligence',   13),
    ('RECHERCHE',        'Recherche globale',                  14),
    ('SAUVEGARDE',       'Sauvegarde',                         15),
    ('PARAMETRES',       'Paramètres',                         16);

COMMENT ON TABLE modules IS 'Référentiel des modules fonctionnels de la plateforme (section 4 du rapport 04-78).';

-- ---------------------------------------------------------------------
-- Table : users
-- Comptes utilisateurs internes de l'entreprise (créés par l'Admin Client)
-- ---------------------------------------------------------------------
CREATE TABLE users (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email                   CITEXT NOT NULL UNIQUE,
    mot_de_passe_hash       TEXT NOT NULL,
    nom                     VARCHAR(100) NOT NULL,
    prenom                  VARCHAR(100) NOT NULL,
    telephone               VARCHAR(30),
    type_utilisateur        VARCHAR(30) NOT NULL DEFAULT 'INTERNE'
                                CHECK (type_utilisateur IN ('INTERNE', 'EXTERNE')),
    statut                  VARCHAR(20) NOT NULL DEFAULT 'ACTIF'
                                CHECK (statut IN ('ACTIF', 'VERROUILLE', 'DESACTIVE')),
    mfa_enabled             BOOLEAN NOT NULL DEFAULT FALSE,
    mot_de_passe_a_changer  BOOLEAN NOT NULL DEFAULT TRUE,
    date_creation           TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON COLUMN users.mot_de_passe_hash IS 'Hash bcrypt/Argon2 (NFR-SEC-22).';
COMMENT ON COLUMN users.type_utilisateur IS 'INTERNE = collaborateur (section 1.3), EXTERNE = portail sécurisé (section 1.4).';

-- ---------------------------------------------------------------------
-- Table : roles
-- ---------------------------------------------------------------------
CREATE TABLE roles (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nom             VARCHAR(100) NOT NULL UNIQUE,
    description     TEXT,
    est_systeme     BOOLEAN NOT NULL DEFAULT FALSE
);

COMMENT ON COLUMN roles.est_systeme IS 'TRUE = profil préconfiguré (sections 1.3.1 à 1.3.4), non supprimable.';

-- ---------------------------------------------------------------------
-- Table : permissions — les 6 permissions FIXES, jamais modifiables
-- ---------------------------------------------------------------------
CREATE TABLE permissions (
    id      SERIAL PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE,
    libelle VARCHAR(50) NOT NULL
);

INSERT INTO permissions (code, libelle) VALUES
    ('LIRE',      'Lire'),
    ('CREER',     'Créer'),
    ('MODIFIER',  'Modifier'),
    ('SUPPRIMER', 'Supprimer'),
    ('VALIDER',   'Valider'),
    ('EXPORTER',  'Exporter');

CREATE OR REPLACE FUNCTION empecher_modification_permissions()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Les permissions de base sont fixes et non modifiables/supprimables';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_permissions_immuables
    BEFORE UPDATE OR DELETE ON permissions
    FOR EACH ROW
    EXECUTE FUNCTION empecher_modification_permissions();

-- ---------------------------------------------------------------------
-- Table : role_permissions
-- Le triplet (rôle, permission, module) définit le périmètre exact,
-- ex. rôle "Comptable" + permission "VALIDER" + module "COMPTABILITE"
-- ---------------------------------------------------------------------
CREATE TABLE role_permissions (
    role_id         UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id   INTEGER NOT NULL REFERENCES permissions(id) ON DELETE RESTRICT,
    module_id       INTEGER NOT NULL REFERENCES modules(id) ON DELETE RESTRICT,
    PRIMARY KEY (role_id, permission_id, module_id)
);

CREATE INDEX idx_role_permissions_module ON role_permissions (module_id);

-- ---------------------------------------------------------------------
-- Table : user_roles
-- ---------------------------------------------------------------------
CREATE TABLE user_roles (
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id          UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    date_attribution TIMESTAMPTZ NOT NULL DEFAULT now(),
    attribue_par     UUID REFERENCES users(id),
    PRIMARY KEY (user_id, role_id)
);

-- ---------------------------------------------------------------------
-- Table : sessions_history
-- Journal des sessions à des fins d'audit (NFR-SEC-19). Les sessions
-- ACTIVES vivent dans Redis (TTL natif, cache rapide) — cette table ne
-- garde qu'une trace persistante, sans logique d'expiration temps réel.
-- ---------------------------------------------------------------------
CREATE TABLE sessions_history (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash      TEXT NOT NULL,
    ip              INET NOT NULL,
    user_agent      TEXT,
    date_ouverture  TIMESTAMPTZ NOT NULL DEFAULT now(),
    date_fermeture  TIMESTAMPTZ,
    motif_fermeture VARCHAR(30)
                        CHECK (motif_fermeture IN ('LOGOUT', 'EXPIRATION', 'REVOCATION_ADMIN'))
);

CREATE INDEX idx_sessions_history_user ON sessions_history (user_id);
CREATE INDEX idx_sessions_history_ouverture ON sessions_history (date_ouverture);
COMMENT ON TABLE sessions_history IS 'Journal des sessions (audit). Les sessions actives vivent dans Redis, pas ici.';

-- ---------------------------------------------------------------------
-- Table : audit_log — PARTITIONNÉE PAR MOIS (RANGE sur timestamp)
-- Rétention légale 10 ans (NFR-CONF-04) : le partitionnement mensuel
-- permet d'archiver/détacher les vieilles partitions sans verrouiller
-- la table entière, et garde les requêtes récentes rapides.
-- ---------------------------------------------------------------------
CREATE TABLE audit_log (
    id          BIGSERIAL,
    user_id     UUID REFERENCES users(id),
    action      VARCHAR(100) NOT NULL,
    entite      VARCHAR(100) NOT NULL,
    entite_id   UUID,
    timestamp   TIMESTAMPTZ NOT NULL DEFAULT now(),
    ip          INET NOT NULL,
    details     JSONB,
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

-- Partitions initiales (mois courant + 2 mois suivants, à adapter à la
-- date réelle de déploiement). Une partition DEFAULT capte tout le
-- reste pour ne jamais rejeter un INSERT faute de partition existante.
CREATE TABLE audit_log_2026_09 PARTITION OF audit_log
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE audit_log_2026_10 PARTITION OF audit_log
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE audit_log_2026_11 PARTITION OF audit_log
    FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE audit_log_default PARTITION OF audit_log DEFAULT;

CREATE OR REPLACE FUNCTION empecher_modification_audit()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'La table audit_log est append-only (UPDATE/DELETE interdits)';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_log_immuable
    BEFORE UPDATE OR DELETE ON audit_log
    FOR EACH ROW
    EXECUTE FUNCTION empecher_modification_audit();

CREATE INDEX idx_audit_log_user ON audit_log (user_id);
CREATE INDEX idx_audit_log_entite ON audit_log (entite, entite_id);

COMMENT ON TABLE audit_log IS 'Journal infalsifiable et append-only (NFR-SEC-16), partitionné par mois. Conservation légale 10 ans (NFR-CONF-04).';

-- Fonction de maintenance : crée la partition du mois demandé, à
-- planifier chaque mois via pg_cron ou un job applicatif @Scheduled
-- (Spring Boot) — non exécutée automatiquement par cette migration.
CREATE OR REPLACE FUNCTION creer_partition_mensuelle_audit_log(p_mois DATE)
RETURNS VOID AS $$
DECLARE
    v_nom_partition TEXT := 'audit_log_' || to_char(p_mois, 'YYYY_MM');
    v_debut         DATE := date_trunc('month', p_mois)::DATE;
    v_fin           DATE := (date_trunc('month', p_mois) + INTERVAL '1 month')::DATE;
BEGIN
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF audit_log FOR VALUES FROM (%L) TO (%L)',
        v_nom_partition, v_debut, v_fin
    );
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- Sécurité applicative : rôle technique dédié à privilèges minimaux
-- (NFR-SEC-29). Mot de passe injecté via coffre-fort (NFR-OPS-03).
-- audit_log : SELECT + INSERT uniquement (ni UPDATE ni DELETE, déjà
-- bloqués par trigger — le REVOKE est une défense en profondeur).
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'ycc_tenant_app') THEN
        CREATE ROLE ycc_tenant_app LOGIN PASSWORD 'CHANGE_ME_VIA_VAULT';
    END IF;
END $$;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;

GRANT SELECT ON modules, permissions TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON users, roles, role_permissions, user_roles, sessions_history TO ycc_tenant_app;
GRANT SELECT, INSERT ON audit_log TO ycc_tenant_app;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ycc_tenant_app;
GRANT EXECUTE ON FUNCTION creer_partition_mensuelle_audit_log(DATE) TO ycc_tenant_app;
