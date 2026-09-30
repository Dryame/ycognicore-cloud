-- =====================================================================
-- V6__enrich_control_plane.sql
-- Base : ycc_control_plane
-- Objet : Enrichissements des tables V1-V3 (ALTER TABLE)
-- Réf.  : Audit 29/09/2026, ADR-002, ADR-005, P8
-- =====================================================================

-- ---------------------------------------------------------------------
-- tenants
-- ---------------------------------------------------------------------
ALTER TABLE tenants
    ADD COLUMN IF NOT EXISTS date_fin_essai   DATE,
    ADD COLUMN IF NOT EXISTS date_suppression TIMESTAMPTZ;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_tenants_email_contact') THEN
        ALTER TABLE tenants ADD CONSTRAINT uq_tenants_email_contact UNIQUE (email_contact);
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- tenant_databases
-- ---------------------------------------------------------------------
ALTER TABLE tenant_databases
    ADD COLUMN IF NOT EXISTS db_user                 VARCHAR(100) NOT NULL DEFAULT 'ycc_tenant_app',
    ADD COLUMN IF NOT EXISTS db_secret_ref           VARCHAR(255),
    ADD COLUMN IF NOT EXISTS date_derniere_migration TIMESTAMPTZ;

-- ---------------------------------------------------------------------
-- superadmin_users : MFA chiffré (ADR-002 + ADR-005)
-- ---------------------------------------------------------------------
ALTER TABLE superadmin_users DROP COLUMN IF EXISTS mfa_secret;

ALTER TABLE superadmin_users
    ADD COLUMN IF NOT EXISTS mfa_secret_package          JSONB,
    ADD COLUMN IF NOT EXISTS mfa_enabled                 BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS date_derniere_connexion     TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS date_expiration_mot_de_passe DATE;

DO $$
BEGIN
    ALTER TABLE superadmin_users DROP CONSTRAINT IF EXISTS superadmin_users_statut_check;
    ALTER TABLE superadmin_users ADD CONSTRAINT superadmin_users_statut_check
        CHECK (statut IN ('ACTIF','VERROUILLE','DESACTIVE'));
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_mfa_package_json') THEN
        ALTER TABLE superadmin_users ADD CONSTRAINT chk_mfa_package_json
        CHECK (
            mfa_secret_package IS NULL
            OR (
                jsonb_typeof(mfa_secret_package) = 'object'
                AND mfa_secret_package ? 'algo'
                AND mfa_secret_package ? 'iv'
                AND mfa_secret_package ? 'tag'
                AND mfa_secret_package ? 'ct'
            )
        );
    END IF;
END $$;

COMMENT ON COLUMN superadmin_users.mfa_secret_package IS
  'Package MFA chiffré AES-256-GCM. Format : {"algo":"AES-256-GCM","iv":"b64","tag":"b64","ct":"b64"}';

-- ---------------------------------------------------------------------
-- kyc_documents
-- ---------------------------------------------------------------------
ALTER TABLE kyc_documents
    ADD COLUMN IF NOT EXISTS hash_document   VARCHAR(128),
    ADD COLUMN IF NOT EXISTS date_expiration DATE,
    ADD COLUMN IF NOT EXISTS motif_rejet     TEXT;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_kyc_motif_rejet') THEN
        ALTER TABLE kyc_documents ADD CONSTRAINT chk_kyc_motif_rejet
        CHECK (statut_verification <> 'REJETE' OR motif_rejet IS NOT NULL);
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- system_monitoring
-- ---------------------------------------------------------------------
ALTER TABLE system_monitoring
    ADD COLUMN IF NOT EXISTS tenant_id    UUID REFERENCES tenants(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS unite        VARCHAR(20),
    ADD COLUMN IF NOT EXISTS niveau       VARCHAR(20),
    ADD COLUMN IF NOT EXISTS seuil_alerte NUMERIC,
    ADD COLUMN IF NOT EXISTS metadata     JSONB;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_sysmon_niveau') THEN
        ALTER TABLE system_monitoring ADD CONSTRAINT chk_sysmon_niveau
        CHECK (niveau IS NULL OR niveau IN ('INFO','AVERTISSEMENT','CRITIQUE'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_sysmon_tenant_ts ON system_monitoring (tenant_id, timestamp DESC);

-- ---------------------------------------------------------------------
-- subscriptions
-- ---------------------------------------------------------------------
ALTER TABLE subscriptions
    ADD COLUMN IF NOT EXISTS date_resiliation  DATE,
    ADD COLUMN IF NOT EXISTS motif_resiliation TEXT,
    ADD COLUMN IF NOT EXISTS reference_contrat VARCHAR(100);

CREATE UNIQUE INDEX IF NOT EXISTS uq_subscriptions_active_par_tenant
    ON subscriptions (tenant_id) WHERE statut = 'ACTIVE';

-- ---------------------------------------------------------------------
-- subscription_invoices
-- ---------------------------------------------------------------------
ALTER TABLE subscription_invoices
    ADD COLUMN IF NOT EXISTS numero_facture   VARCHAR(50),
    ADD COLUMN IF NOT EXISTS mode_paiement    VARCHAR(30),
    ADD COLUMN IF NOT EXISTS pdf_url          TEXT,
    ADD COLUMN IF NOT EXISTS pdf_hash         VARCHAR(128),
    ADD COLUMN IF NOT EXISTS date_annulation  DATE,
    ADD COLUMN IF NOT EXISTS motif_annulation TEXT;

UPDATE subscription_invoices
SET numero_facture = 'FAC-SaaS-LEGACY-' || substring(id::text, 1, 8)
WHERE numero_facture IS NULL;

ALTER TABLE subscription_invoices ALTER COLUMN numero_facture SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_invoice_numero') THEN
        ALTER TABLE subscription_invoices ADD CONSTRAINT uq_invoice_numero UNIQUE (numero_facture);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_invoice_motif_annulation') THEN
        ALTER TABLE subscription_invoices ADD CONSTRAINT chk_invoice_motif_annulation
        CHECK (statut <> 'ANNULEE' OR motif_annulation IS NOT NULL);
    END IF;
END $$;

-- ---------------------------------------------------------------------
-- ia_quotas
-- ---------------------------------------------------------------------
ALTER TABLE ia_quotas
    ADD COLUMN IF NOT EXISTS alerte_envoyee BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS date_alerte    TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS cout_total     NUMERIC(12,4) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cache_hits     INTEGER NOT NULL DEFAULT 0;
