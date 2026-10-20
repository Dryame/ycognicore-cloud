-- =====================================================================
-- V19 — Eclaircir les colonnes accueillant le ciphertext AES-GCM
-- Phase : P4 — Lot L3.2
-- Ref : D-P4-2 (format v<N>:base64(iv||ct||tag) ~51 caracteres minimum)
-- Immuable des application. Aucun GRANT DELETE. Aucun GRANT TRUNCATE.
-- Defensive : skip les tables absentes (tenants minimaux sans V9-V13).
-- =====================================================================

-- 1. Table tiers (peut etre absente sur demo002)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'tiers') THEN
    ALTER TABLE tiers ALTER COLUMN ifu        TYPE varchar(200);
    ALTER TABLE tiers ALTER COLUMN rccm       TYPE varchar(200);
    ALTER TABLE tiers ALTER COLUMN telephone  TYPE varchar(200);
    RAISE NOTICE 'V19 : colonnes tiers elargies (ifu, rccm, telephone)';
  ELSE
    RAISE NOTICE 'V19 : table tiers absente - skip';
  END IF;
END $$;

-- 2. Table users (toujours presente)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_name = 'users' AND column_name = 'telephone') THEN
    ALTER TABLE users ALTER COLUMN telephone TYPE varchar(200);
    RAISE NOTICE 'V19 : colonne users.telephone elargie';
  END IF;
END $$;

-- 3. Verification post-migration
DO $$
DECLARE
  v_tiers_len INTEGER;
  v_users_len INTEGER;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'tiers') THEN
    SELECT character_maximum_length INTO v_tiers_len
    FROM information_schema.columns
    WHERE table_name = 'tiers' AND column_name = 'ifu';
    IF v_tiers_len IS NULL OR v_tiers_len < 200 THEN
      RAISE EXCEPTION 'V19 : tiers.ifu non elargi (len=%)', v_tiers_len;
    END IF;
  END IF;

  SELECT character_maximum_length INTO v_users_len
  FROM information_schema.columns
  WHERE table_name = 'users' AND column_name = 'telephone';
  IF v_users_len IS NULL OR v_users_len < 200 THEN
    RAISE EXCEPTION 'V19 : users.telephone non elargi (len=%)', v_users_len;
  END IF;

  RAISE NOTICE 'V19 : OK';
END $$;
