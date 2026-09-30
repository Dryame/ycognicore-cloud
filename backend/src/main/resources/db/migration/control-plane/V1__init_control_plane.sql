-- =====================================================================
-- V1__init_control_plane.sql
-- Base : ycc_control_plane (unique, partagée)
-- Objet : Types partagés + socle control plane — tenants, provisioning,
--         superadmin, KYC, monitoring
-- Réf. rapport 04-78 : section 1.1 / 2.1 / 3.1
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS citext;     -- emails insensibles à la casse

-- ---------------------------------------------------------------------
-- Types partagés du control plane
-- Centralisés ici pour éviter de dupliquer le même CHECK() dans
-- plusieurs tables : tenants, subscriptions (V2) et ia_quotas (V3)
-- partagent tous le même ensemble de formules.
-- ---------------------------------------------------------------------
CREATE TYPE formule_abonnement AS ENUM ('TRIAL', 'STANDARD', 'ENTERPRISE');
CREATE TYPE statut_tenant       AS ENUM ('TRIAL', 'ACTIF', 'SUSPENDU', 'RESILIE');

-- ---------------------------------------------------------------------
-- Table : tenants
-- Chaque entreprise cliente abonnée à la plateforme
-- ---------------------------------------------------------------------
CREATE TABLE tenants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(50)  NOT NULL UNIQUE,
    nom             VARCHAR(255) NOT NULL,
    email_contact   CITEXT       NOT NULL,
    telephone       VARCHAR(30),
    adresse         TEXT,
    pays            VARCHAR(100) NOT NULL DEFAULT 'Burkina Faso',
    statut          statut_tenant      NOT NULL DEFAULT 'TRIAL',
    formule         formule_abonnement NOT NULL DEFAULT 'TRIAL',
    date_creation   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    date_maj        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

COMMENT ON TABLE tenants IS 'Entreprises clientes abonnées à la plateforme (control plane).';
COMMENT ON COLUMN tenants.code IS 'Identifiant unique et IMMUABLE (NFR-SEC-01), jamais réutilisé même si le tenant est supprimé.';

-- Le code tenant ne doit jamais changer une fois créé
CREATE OR REPLACE FUNCTION empecher_modification_code_tenant()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.code <> OLD.code THEN
        RAISE EXCEPTION 'Le champ tenants.code est immuable et ne peut pas être modifié';
    END IF;
    NEW.date_maj := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tenants_code_immuable
    BEFORE UPDATE ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION empecher_modification_code_tenant();

-- ---------------------------------------------------------------------
-- Table : tenant_databases
-- Référence technique de la base dédiée de chaque tenant
-- ---------------------------------------------------------------------
CREATE TABLE tenant_databases (
    tenant_id       UUID PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE,
    db_name         VARCHAR(100) NOT NULL UNIQUE,
    db_host         VARCHAR(255) NOT NULL,
    db_port         INTEGER      NOT NULL DEFAULT 5432,
    version_schema  VARCHAR(20)  NOT NULL DEFAULT 'V1',
    db_status       VARCHAR(20)  NOT NULL DEFAULT 'EN_COURS'
                        CHECK (db_status IN ('EN_COURS', 'PROVISIONNEE', 'ERREUR', 'SUPPRIMEE')),
    date_creation   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    date_maj        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

COMMENT ON TABLE tenant_databases IS 'Référence technique de la base PostgreSQL dédiée de chaque tenant. db_name ne doit JAMAIS être exposé côté client.';

-- ---------------------------------------------------------------------
-- Table : superadmin_users
-- Créée AVANT kyc_documents, qui référence valide_par
-- ---------------------------------------------------------------------
CREATE TABLE superadmin_users (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email               CITEXT       NOT NULL UNIQUE,
    nom_complet         VARCHAR(255) NOT NULL,
    mot_de_passe_hash   TEXT         NOT NULL,
    mfa_secret          TEXT,
    statut              VARCHAR(20)  NOT NULL DEFAULT 'ACTIF'
                            CHECK (statut IN ('ACTIF', 'DESACTIVE')),
    date_creation       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    date_maj            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

COMMENT ON COLUMN superadmin_users.mot_de_passe_hash IS 'Hash bcrypt ou Argon2 (NFR-SEC-22) — jamais de mot de passe en clair.';

-- ---------------------------------------------------------------------
-- Table : kyc_documents
-- ---------------------------------------------------------------------
CREATE TABLE kyc_documents (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id             UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    type_document         VARCHAR(50) NOT NULL
                              CHECK (type_document IN ('REGISTRE_COMMERCE', 'IDENTIFIANT_FISCAL')),
    url                   TEXT NOT NULL,
    statut_verification   VARCHAR(20) NOT NULL DEFAULT 'EN_ATTENTE'
                              CHECK (statut_verification IN ('EN_ATTENTE', 'VALIDE', 'REJETE')),
    valide_par            UUID REFERENCES superadmin_users(id),
    date_soumission       TIMESTAMPTZ NOT NULL DEFAULT now(),
    date_verification     TIMESTAMPTZ
);

CREATE INDEX idx_kyc_documents_tenant ON kyc_documents (tenant_id);
COMMENT ON TABLE kyc_documents IS 'Pièces justificatives KYC (NFR-SEC-31) : registre de commerce, identifiant fiscal.';

-- ---------------------------------------------------------------------
-- Table : system_monitoring
-- ---------------------------------------------------------------------
CREATE TABLE system_monitoring (
    id          BIGSERIAL PRIMARY KEY,
    timestamp   TIMESTAMPTZ NOT NULL DEFAULT now(),
    metrique    VARCHAR(100) NOT NULL,
    valeur      NUMERIC NOT NULL
);

CREATE INDEX idx_system_monitoring_metrique_ts ON system_monitoring (metrique, timestamp);
COMMENT ON TABLE system_monitoring IS 'Métriques Monitoring APM (NFR-MON-01) : santé serveurs, performance, tentatives d''attaque.';

-- ---------------------------------------------------------------------
-- Sécurité applicative : rôle technique dédié à privilèges minimaux
-- (NFR-SEC-29 : principe du moindre privilège). Le mot de passe réel
-- est injecté via le coffre-fort de secrets (Vault / KMS cloud —
-- NFR-OPS-03) lors du déploiement, jamais laissé en clair ici.
-- DELETE n'est accordé que sur tenant_databases et kyc_documents
-- (droit à l'oubli NFR-SEC-32) ; les autres tables se gèrent par statut.
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'ycc_control_plane_app') THEN
        CREATE ROLE ycc_control_plane_app LOGIN PASSWORD 'CHANGE_ME_VIA_VAULT';
    END IF;
END $$;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;

GRANT SELECT, INSERT, UPDATE, DELETE ON tenant_databases, kyc_documents TO ycc_control_plane_app;
GRANT SELECT, INSERT, UPDATE ON tenants, system_monitoring, superadmin_users TO ycc_control_plane_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ycc_control_plane_app;
