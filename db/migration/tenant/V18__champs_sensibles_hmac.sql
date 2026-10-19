-- =====================================================================
-- V18 — Champs sensibles : colonnes HMAC pour recherche exacte
-- Phase : P4 — Lot L1
-- Ref : D-P4-3, D-P4-4, D-P4-9, ADR-042
-- Immuable des application. Aucun GRANT DELETE. Aucun GRANT TRUNCATE.
-- Defensive : skip les tables absentes (tenants minimaux sans V9-V13).
-- =====================================================================

-- 1. Colonnes + index sur tiers (si table existe)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'tiers') THEN

    ALTER TABLE tiers ADD COLUMN IF NOT EXISTS ifu_hmac       varchar(64);
    ALTER TABLE tiers ADD COLUMN IF NOT EXISTS rccm_hmac      varchar(64);
    ALTER TABLE tiers ADD COLUMN IF NOT EXISTS telephone_hmac varchar(64);
    ALTER TABLE tiers ADD COLUMN IF NOT EXISTS email_hmac     varchar(64);

    CREATE INDEX IF NOT EXISTS idx_tiers_ifu_hmac
      ON tiers (ifu_hmac) WHERE ifu_hmac IS NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_tiers_rccm_hmac
      ON tiers (rccm_hmac) WHERE rccm_hmac IS NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_tiers_telephone_hmac
      ON tiers (telephone_hmac) WHERE telephone_hmac IS NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_tiers_email_hmac
      ON tiers (email_hmac) WHERE email_hmac IS NOT NULL;

    RAISE NOTICE 'V18 : colonnes HMAC ajoutees a tiers';
  ELSE
    RAISE NOTICE 'V18 : table tiers absente - skip (tenant minimal)';
  END IF;
END $$;

-- 2. Colonnes + index sur users (toujours presente)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'users') THEN

    ALTER TABLE users ADD COLUMN IF NOT EXISTS telephone_hmac varchar(64);
    ALTER TABLE users ADD COLUMN IF NOT EXISTS email_hmac     varchar(64);

    CREATE UNIQUE INDEX IF NOT EXISTS uq_users_email_hmac
      ON users (email_hmac) WHERE email_hmac IS NOT NULL;
    CREATE INDEX IF NOT EXISTS idx_users_telephone_hmac
      ON users (telephone_hmac) WHERE telephone_hmac IS NOT NULL;

    RAISE NOTICE 'V18 : colonnes HMAC ajoutees a users';
  ELSE
    RAISE EXCEPTION 'V18 : table users absente (tenant non provisionne)';
  END IF;
END $$;

-- 3. Verification post-migration
DO $$
DECLARE
  v_tiers_present BOOLEAN;
  v_count INTEGER;
BEGIN
  SELECT EXISTS (SELECT 1 FROM information_schema.tables
                 WHERE table_schema = 'public' AND table_name = 'tiers')
    INTO v_tiers_present;

  -- users doit avoir 2 colonnes HMAC
  SELECT COUNT(*) INTO v_count
  FROM information_schema.columns
  WHERE table_name = 'users'
    AND column_name IN ('telephone_hmac', 'email_hmac');
  IF v_count < 2 THEN
    RAISE EXCEPTION 'V18 : colonnes users manquantes (% / 2)', v_count;
  END IF;

  -- tiers : 4 colonnes si table existe
  IF v_tiers_present THEN
    SELECT COUNT(*) INTO v_count
    FROM information_schema.columns
    WHERE table_name = 'tiers'
      AND column_name IN ('ifu_hmac','rccm_hmac','telephone_hmac','email_hmac');
    IF v_count < 4 THEN
      RAISE EXCEPTION 'V18 : colonnes tiers manquantes (% / 4)', v_count;
    END IF;
  END IF;

  RAISE NOTICE 'V18 : OK (tiers presente=%)', v_tiers_present;
END $$;
