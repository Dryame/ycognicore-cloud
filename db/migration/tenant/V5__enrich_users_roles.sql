-- =====================================================================
-- V5__enrich_users_roles.sql
-- Base : ycc_tenant_<id>
-- Objet : Enrichissements users, roles, role_permissions, user_roles
-- Réf.  : P4, ADR-001, NFR-SEC-09, NFR-SEC-19, NFR-UX-02
-- =====================================================================

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS date_derniere_connexion       TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS date_expiration_mot_de_passe  DATE,
    ADD COLUMN IF NOT EXISTS langue_preferee               VARCHAR(10) DEFAULT 'fr',
    ADD COLUMN IF NOT EXISTS fuseau_horaire                VARCHAR(50) DEFAULT 'Africa/Ouagadougou',
    ADD COLUMN IF NOT EXISTS created_by                    UUID REFERENCES users(id),
    ADD COLUMN IF NOT EXISTS date_verrouillage             TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS motif_verrouillage            VARCHAR(100);

ALTER TABLE roles DROP COLUMN IF EXISTS scope_type;
ALTER TABLE roles DROP COLUMN IF EXISTS scope_valeur;

ALTER TABLE roles
    ADD COLUMN IF NOT EXISTS scope JSONB,
    ADD COLUMN IF NOT EXISTS statut VARCHAR(20) NOT NULL DEFAULT 'ACTIF',
    ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES users(id),
    ADD COLUMN IF NOT EXISTS date_creation TIMESTAMPTZ NOT NULL DEFAULT now();

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_roles_statut') THEN
        ALTER TABLE roles ADD CONSTRAINT chk_roles_statut CHECK (statut IN ('ACTIF','INACTIF'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_roles_scope_json') THEN
        ALTER TABLE roles ADD CONSTRAINT chk_roles_scope_json
        CHECK (scope IS NULL OR jsonb_typeof(scope) = 'object');
    END IF;
END $$;

COMMENT ON COLUMN roles.scope IS 'Périmètre du rôle. Ex : {"departements":["Commercial"],"sites":["Ouagadougou"]}';

ALTER TABLE role_permissions
    ADD COLUMN IF NOT EXISTS accordee_par     UUID REFERENCES users(id),
    ADD COLUMN IF NOT EXISTS date_attribution TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE user_roles
    ADD COLUMN IF NOT EXISTS date_fin TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS statut   VARCHAR(20) NOT NULL DEFAULT 'ACTIF',
    ADD COLUMN IF NOT EXISTS motif    TEXT;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_user_roles_statut') THEN
        ALTER TABLE user_roles ADD CONSTRAINT chk_user_roles_statut
        CHECK (statut IN ('ACTIF','REVOQUE'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_user_roles_statut ON user_roles (user_id, statut) WHERE statut = 'ACTIF';

GRANT SELECT, INSERT, UPDATE, DELETE ON users, roles, role_permissions, user_roles TO ycc_tenant_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ycc_tenant_app;
