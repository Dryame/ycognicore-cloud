-- =====================================================================
-- V9 — Chiffrement applicatif : cles par entreprise (control plane)
-- Phase : P4 — Lot L1
-- Ref : D-10, D-P4-1, D-P4-4, D-P4-12, ADR-040
-- Immuable des application. Aucun GRANT DELETE. Aucun GRANT TRUNCATE.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Table cles_tenant
CREATE TABLE IF NOT EXISTS cles_tenant (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  version integer NOT NULL CHECK (version >= 1),
  cle_wrapped text NOT NULL,
  type_cle varchar(10) NOT NULL CHECK (type_cle IN ('DATA','HMAC')),
  statut varchar(20) NOT NULL DEFAULT 'ACTIVE'
    CHECK (statut IN ('ACTIVE','DEPRECATED','REVOKED')),
  date_creation timestamptz NOT NULL DEFAULT now(),
  date_rotation_prevue timestamptz,
  date_rotation_effectuee timestamptz,
  created_by uuid,
  CONSTRAINT uq_cles_tenant_version UNIQUE (tenant_id, version, type_cle)
);

-- 2. Index : une seule cle ACTIVE par (tenant, type)
CREATE UNIQUE INDEX IF NOT EXISTS uq_cles_tenant_active
  ON cles_tenant (tenant_id, type_cle)
  WHERE statut = 'ACTIVE';

-- 3. Index pour lookup rapide
CREATE INDEX IF NOT EXISTS idx_cles_tenant_lookup
  ON cles_tenant (tenant_id, type_cle, statut);

-- 4. Roles applicatifs (defensif : creation si absents)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ycc_encryption_app') THEN
    CREATE ROLE ycc_encryption_app NOLOGIN;
    RAISE NOTICE 'V9 : role ycc_encryption_app cree';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ycc_key_rotation_app') THEN
    CREATE ROLE ycc_key_rotation_app NOLOGIN;
    RAISE NOTICE 'V9 : role ycc_key_rotation_app cree';
  END IF;
END $$;

-- 5. GRANTs (D-P4-12 : SELECT pour encryption, INSERT+UPDATE pour rotation)
GRANT USAGE ON SCHEMA public TO ycc_encryption_app, ycc_key_rotation_app;

GRANT SELECT ON cles_tenant TO ycc_encryption_app;

GRANT SELECT, INSERT, UPDATE ON cles_tenant TO ycc_key_rotation_app;

REVOKE DELETE, TRUNCATE ON cles_tenant FROM ycc_encryption_app;
REVOKE DELETE, TRUNCATE ON cles_tenant FROM ycc_key_rotation_app;

-- 6. Trigger anti-DELETE (une cle n'est jamais supprimee, elle est REVOKED)
CREATE OR REPLACE FUNCTION forbid_delete_cles_tenant()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'cles_tenant : DELETE interdit. Utiliser statut=REVOKED.'
    USING ERRCODE = '42501';
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_cles_tenant_no_delete'
  ) THEN
    CREATE TRIGGER trg_cles_tenant_no_delete
      BEFORE DELETE ON cles_tenant
      FOR EACH ROW EXECUTE FUNCTION forbid_delete_cles_tenant();
    RAISE NOTICE 'V9 : trigger trg_cles_tenant_no_delete cree';
  END IF;
END $$;

-- 7. Verification post-migration
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_name = 'cles_tenant'
  ) THEN
    RAISE EXCEPTION 'V9 : table cles_tenant absente';
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM information_schema.columns
  WHERE table_name = 'cles_tenant'
    AND column_name IN ('tenant_id','version','cle_wrapped','type_cle','statut');
  IF v_count < 5 THEN
    RAISE EXCEPTION 'V9 : colonnes manquantes (% / 5)', v_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_cles_tenant_no_delete'
  ) THEN
    RAISE EXCEPTION 'V9 : trigger anti-DELETE absent';
  END IF;

  RAISE NOTICE 'V9 : OK';
END $$;
