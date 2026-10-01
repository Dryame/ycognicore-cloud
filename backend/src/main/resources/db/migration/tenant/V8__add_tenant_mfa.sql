-- =====================================================================
-- V8__add_tenant_mfa.sql
-- Base : ycc_tenant_<id>
-- Objet : Ajout de la colonne mfa_secret_package (JSONB) sur users
-- Ref.  : ADR-002, ADR-005, BL-012, NFR-SEC-21
-- =====================================================================

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS mfa_secret_package JSONB;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_users_mfa_package_json') THEN
        ALTER TABLE users ADD CONSTRAINT chk_users_mfa_package_json
        CHECK (
            mfa_secret_package IS NULL
            OR jsonb_typeof(mfa_secret_package) = 'object'
        );
    END IF;
END $$;

COMMENT ON COLUMN users.mfa_secret_package IS
  'Package MFA chiffre via Vault transit (AES-256-GCM). Format : {"algo":"aes256-gcm96","vault_ct":"vault:v1:...","version":1,"created_at":"..."}';
