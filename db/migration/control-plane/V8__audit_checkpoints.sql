-- =====================================================================
-- V8 — Point de contrôle d'audit (control plane)
-- Phase : P3 — Lot L1
-- Réf : D-03, N-4, ADR-030
-- =====================================================================

CREATE TABLE IF NOT EXISTS audit_checkpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  tenant_db_name varchar(255) NOT NULL,
  partition_name varchar(100) NOT NULL,
  hash_final varchar(64) NOT NULL,
  date_debut timestamptz NOT NULL,
  date_fin timestamptz NOT NULL,
  type_checkpoint varchar(20) NOT NULL DEFAULT 'HEBDO'
    CHECK (type_checkpoint IN ('HEBDO','MENSUEL')),
  date_creation timestamptz NOT NULL DEFAULT now(),
  created_by varchar(100) NOT NULL DEFAULT 'ycc_audit_writer'
);
CREATE INDEX IF NOT EXISTS idx_audit_checkpoints_tenant
  ON audit_checkpoints(tenant_db_name, date_fin DESC);
CREATE INDEX IF NOT EXISTS idx_audit_checkpoints_partition
  ON audit_checkpoints(tenant_db_name, partition_name);

-- 2. Table evenements_securite_agreges
CREATE TABLE IF NOT EXISTS evenements_securite_agreges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  tenant_db_name varchar(255) NOT NULL,
  type varchar(50) NOT NULL,
  gravite varchar(20) NOT NULL,
  date_evenement timestamptz NOT NULL,
  traite boolean NOT NULL DEFAULT false,
  date_creation timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_evenements_agreges_tenant
  ON evenements_securite_agreges(tenant_db_name, date_evenement DESC);
CREATE INDEX IF NOT EXISTS idx_evenements_agreges_gravite
  ON evenements_securite_agreges(gravite, date_evenement DESC)
  WHERE traite = false;

-- 3. Role ycc_audit_writer (defensif, NOLOGIN)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ycc_audit_writer') THEN
    CREATE ROLE ycc_audit_writer NOLOGIN;
    RAISE NOTICE 'V8 : role ycc_audit_writer cree (NOLOGIN)';
  END IF;
END $$;

GRANT USAGE ON SCHEMA public TO ycc_audit_writer;
GRANT SELECT, INSERT ON audit_checkpoints TO ycc_audit_writer;
REVOKE UPDATE, DELETE, TRUNCATE ON audit_checkpoints FROM ycc_audit_writer;
REVOKE UPDATE, DELETE, TRUNCATE ON evenements_securite_agreges FROM ycc_audit_writer;

-- 4. Trigger BEFORE UPDATE OR DELETE
CREATE OR REPLACE FUNCTION forbid_update_delete_checkpoints()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'audit_checkpoints : UPDATE/DELETE interdit'
    USING ERRCODE = '42501';
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_audit_checkpoints_immutable'
  ) THEN
    CREATE TRIGGER trg_audit_checkpoints_immutable
      BEFORE UPDATE OR DELETE ON audit_checkpoints
      FOR EACH ROW EXECUTE FUNCTION forbid_update_delete_checkpoints();
  END IF;
END $$;

-- 5. Verification post-migration
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                 WHERE table_name='audit_checkpoints') THEN
    RAISE EXCEPTION 'V8 : table audit_checkpoints absente';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                 WHERE table_name='evenements_securite_agreges') THEN
    RAISE EXCEPTION 'V8 : table evenements_securite_agreges absente';
  END IF;
  RAISE NOTICE 'V8 : OK';
END $$;
