-- V14_add_tenant_mfa.sql
-- Base : ycc_tenant_<id>
-- Objet : Ajout de la colonne mfa_secret_package (JSONB) sur users
-- Ref.  : ADR-002, ADR-005, BL-012, NFR-SEC-21
-- Origine : renommage de V8_add_tenant_mfa.sql (M01, résolution du doublon C1)
-- Phase : P0 — Assainissement du dépôt
-- Idempotente : oui

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

-- ============================================================================
-- Vérifications post-migration
-- ============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'users'
          AND column_name  = 'mfa_secret_package'
    ) THEN
        RAISE EXCEPTION 'V14 : colonne users.mfa_secret_package absente après migration';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_users_mfa_package_json'
    ) THEN
        RAISE EXCEPTION 'V14 : contrainte chk_users_mfa_package_json absente après migration';
    END IF;
END $$;
