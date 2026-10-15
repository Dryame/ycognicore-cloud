-- =====================================================================
-- V17 — Sécurité des accès, sessions, appareils et audit chaîné
-- Phase : P3 — Lot L1
-- Auteur : Yameogo Idrissa
-- Réf : D-04, D-05, D-06, D-11, ADR-030, ADR-033
-- Immuable dès application. Aucun GRANT DELETE. Aucun GRANT TRUNCATE.
-- =====================================================================

BEGIN;

-- 1. Table appareils
CREATE TABLE IF NOT EXISTS appareils (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  nom varchar(100),
  type varchar(50),
  os varchar(100),
  navigateur varchar(100),
  empreinte varchar(255),
  statut varchar(20) NOT NULL DEFAULT 'AUTORISE'
    CHECK (statut IN ('AUTORISE','BLOQUE','SUPPRIME')),
  premiere_vue timestamptz NOT NULL DEFAULT now(),
  derniere_vue timestamptz NOT NULL DEFAULT now(),
  date_creation timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_appareils_user ON appareils(user_id);
CREATE INDEX IF NOT EXISTS idx_appareils_empreinte ON appareils(user_id, empreinte);

-- 2. Table sessions_actives
CREATE TABLE IF NOT EXISTS sessions_actives (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_history_id uuid,
  token_hash text NOT NULL,
  refresh_token_hash text,
  appareil_id uuid REFERENCES appareils(id) ON DELETE SET NULL,
  ip inet,
  user_agent text,
  date_ouverture timestamptz NOT NULL DEFAULT now(),
  date_derniere_activite timestamptz NOT NULL DEFAULT now(),
  date_expiration timestamptz NOT NULL,
  date_fermeture timestamptz,
  motif_fermeture varchar(50)
    CHECK (motif_fermeture IS NULL OR motif_fermeture IN ('LOGOUT','EXPIRATION','REVOCATION_ADMIN','REVOCATION_GLOBALE','CHANGEMENT_MDP','CHANGEMENT_MFA')),
  statut varchar(20) NOT NULL DEFAULT 'ACTIVE'
    CHECK (statut IN ('ACTIVE','EXPIREE','REVOQUEE')),
  date_creation timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sessions_actives_user_statut
  ON sessions_actives(user_id, statut);
CREATE INDEX IF NOT EXISTS idx_sessions_actives_expiration
  ON sessions_actives(date_expiration) WHERE statut = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_sessions_actives_token_hash
  ON sessions_actives(token_hash);

-- 3. Table politiques_session
CREATE TABLE IF NOT EXISTS politiques_session (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope varchar(20) NOT NULL CHECK (scope IN ('PLATEFORME','ENTREPRISE')),
  sessions_max integer NOT NULL DEFAULT 5
    CHECK (sessions_max BETWEEN 1 AND 20),
  inactivite_minutes integer NOT NULL DEFAULT 30
    CHECK (inactivite_minutes BETWEEN 5 AND 480),
  duree_absolue_heures integer NOT NULL DEFAULT 12
    CHECK (duree_absolue_heures BETWEEN 1 AND 168),
  access_token_minutes integer NOT NULL DEFAULT 30
    CHECK (access_token_minutes BETWEEN 5 AND 60),
  refresh_token_jours integer NOT NULL DEFAULT 7
    CHECK (refresh_token_jours BETWEEN 1 AND 30),
  verrouillage_seuil integer NOT NULL DEFAULT 5,
  verrouillage_duree_minutes integer NOT NULL DEFAULT 15
    CHECK (verrouillage_duree_minutes BETWEEN 5 AND 60),
  date_creation timestamptz NOT NULL DEFAULT now(),
  date_modification timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES users(id)
);

-- 4. Table evenements_securite
CREATE TABLE IF NOT EXISTS evenements_securite (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type varchar(50) NOT NULL,
  gravite varchar(20) NOT NULL DEFAULT 'INFO'
    CHECK (gravite IN ('INFO','WARN','ERROR','CRITIQUE')),
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  session_id uuid,
  appareil_id uuid REFERENCES appareils(id) ON DELETE SET NULL,
  ip inet,
  pays char(2),
  ville varchar(100),
  details jsonb,
  statut_traitement varchar(20) NOT NULL DEFAULT 'NOUVEAU'
    CHECK (statut_traitement IN ('NOUVEAU','EN_COURS','TRAITE','IGNORE')),
  traite_par uuid REFERENCES users(id) ON DELETE SET NULL,
  date_traitement timestamptz,
  date_creation timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_evenements_securite_user
  ON evenements_securite(user_id, date_creation DESC);
CREATE INDEX IF NOT EXISTS idx_evenements_securite_type
  ON evenements_securite(type, date_creation DESC);
CREATE INDEX IF NOT EXISTS idx_evenements_securite_statut
  ON evenements_securite(statut_traitement) WHERE statut_traitement = 'NOUVEAU';

-- 5. Table droits_speciaux
CREATE TABLE IF NOT EXISTS droits_speciaux (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(50) NOT NULL UNIQUE,
  libelle varchar(200) NOT NULL,
  description text,
  date_creation timestamptz NOT NULL DEFAULT now()
);

-- 6. Table role_droits_speciaux
CREATE TABLE IF NOT EXISTS role_droits_speciaux (
  role_id uuid NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  droit_special_id uuid NOT NULL REFERENCES droits_speciaux(id) ON DELETE RESTRICT,
  accordee_par uuid REFERENCES users(id) ON DELETE SET NULL,
  date_attribution timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (role_id, droit_special_id)
);

-- Insertion du droit CONSOLE_SECURITE (idempotent)
INSERT INTO droits_speciaux (code, libelle, description)
SELECT 'CONSOLE_SECURITE', 'Accès console de sécurité',
       'Permet l''accès à la console de sécurité du tenant (appareils, sessions, événements)'
WHERE NOT EXISTS (SELECT 1 FROM droits_speciaux WHERE code = 'CONSOLE_SECURITE');

-- 7. Colonnes audit_log (propage automatiquement aux partitions en PG 11+)
ALTER TABLE audit_log ADD COLUMN IF NOT EXISTS hash_precedent varchar(64);
ALTER TABLE audit_log ADD COLUMN IF NOT EXISTS hash_entree   varchar(64);
CREATE INDEX IF NOT EXISTS idx_audit_log_hash_entree ON audit_log(hash_entree);

-- 8. Colonne users.verrouille_jusqu_a (temporisation D17-2)
ALTER TABLE users ADD COLUMN IF NOT EXISTS verrouille_jusqu_a timestamptz;

-- 9. Remplacement de la fonction V7 — verrouillage temporisé (D-06, P-01)
CREATE OR REPLACE FUNCTION verrouiller_compte_apres_echecs()
RETURNS TRIGGER AS $$
DECLARE
  v_echecs INTEGER;
  v_seuil INTEGER := 5;
  v_duree INTEGER := 15;
BEGIN
  IF NEW.succes = FALSE THEN
    SELECT COUNT(*) INTO v_echecs
    FROM (
      SELECT succes FROM login_attempts
      WHERE email = NEW.email
      ORDER BY timestamp DESC LIMIT 10
    ) sub WHERE succes = FALSE;

    IF v_echecs >= 10 THEN v_duree := 60;
    ELSIF v_echecs >= 5 THEN v_duree := 15;
    ELSE v_duree := 0;
    END IF;

    IF v_echecs >= v_seuil THEN
      UPDATE users
         SET statut = 'VERROUILLE',
             date_verrouillage = now(),
             verrouille_jusqu_a = now() + (v_duree || ' minutes')::interval,
             motif_verrouillage = 'Echecs repetes'
       WHERE email = NEW.email
         AND statut = 'ACTIF';

      INSERT INTO audit_log (
        user_id, action, entite, niveau, succes, details, ip, timestamp
      ) VALUES (
        NEW.user_id, 'VERROUILLAGE_AUTO', 'users', 'SECURITE', TRUE,
        jsonb_build_object('email', NEW.email, 'nb_echecs', v_echecs, 'duree_minutes', v_duree),
        NEW.ip, now()
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 10. Fonction verifier_chaine_audit (structure — formule figée par D17-1)
CREATE OR REPLACE FUNCTION verifier_chaine_audit(p_partition text)
RETURNS TABLE (
  ligne_id bigint,
  hash_attendu varchar(64),
  hash_stocke varchar(64),
  hash_precedent_attendu varchar(64),
  hash_precedent_stocke varchar(64),
  valide boolean
) AS $$
DECLARE
  r RECORD;
  v_precedent varchar(64) := NULL;
  v_calcule varchar(64);
BEGIN
  FOR r IN EXECUTE format(
    'SELECT id, user_id, action, entite, entite_id, timestamp, details,
            hash_entree, hash_precedent
     FROM %I ORDER BY id', p_partition
  ) LOOP
    v_calcule := encode(digest(
      coalesce(v_precedent,'') || '|' ||
      r.id::text || '|' ||
      coalesce(r.user_id::text,'') || '|' ||
      r.action || '|' ||
      r.entite || '|' ||
      coalesce(r.entite_id::text,'') || '|' ||
      to_char(r.timestamp AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US') || '|' ||
      coalesce(r.details::text,'')
    , 'sha256'), 'hex');

    ligne_id := r.id;
    hash_attendu := v_calcule;
    hash_stocke := r.hash_entree;
    hash_precedent_attendu := v_precedent;
    hash_precedent_stocke := r.hash_precedent;
    valide := (r.hash_entree = v_calcule)
          AND (coalesce(r.hash_precedent,'') = coalesce(v_precedent,''));
    RETURN NEXT;
    v_precedent := r.hash_entree;
  END LOOP;
END;
$$ LANGUAGE plpgsql STABLE;

-- 11. Trigger anti-TRUNCATE sur login_attempts (renforcement P3-7)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_login_attempts_no_truncate'
  ) THEN
    CREATE TRIGGER trg_login_attempts_no_truncate
      BEFORE TRUNCATE ON login_attempts
      FOR EACH STATEMENT EXECUTE FUNCTION forbid_truncate();
  END IF;
END $$;

-- 12. GRANT — jamais DELETE, jamais TRUNCATE (ADR-033)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ycc_tenant_app') THEN
    GRANT SELECT, INSERT, UPDATE ON appareils            TO ycc_tenant_app;
    GRANT SELECT, INSERT, UPDATE ON sessions_actives     TO ycc_tenant_app;
    GRANT SELECT, INSERT, UPDATE ON politiques_session   TO ycc_tenant_app;
    GRANT SELECT, INSERT, UPDATE ON evenements_securite  TO ycc_tenant_app;
    GRANT SELECT, INSERT, UPDATE ON droits_speciaux      TO ycc_tenant_app;
    GRANT SELECT, INSERT, UPDATE ON role_droits_speciaux TO ycc_tenant_app;
    GRANT SELECT, INSERT, UPDATE ON audit_log            TO ycc_tenant_app;
    REVOKE DELETE, TRUNCATE ON appareils, sessions_actives,
      politiques_session, evenements_securite, droits_speciaux,
      role_droits_speciaux FROM ycc_tenant_app;
  END IF;
END $$;

-- 13. Vérifications post-migration
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM information_schema.tables
    WHERE table_schema='public'
      AND table_name IN ('appareils','sessions_actives','politiques_session',
                         'evenements_securite','droits_speciaux','role_droits_speciaux');
  IF v_count < 6 THEN
    RAISE EXCEPTION 'V17 : tables manquantes (% / 6)', v_count;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='audit_log' AND column_name='hash_entree') THEN
    RAISE EXCEPTION 'V17 : colonne audit_log.hash_entree absente';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='users' AND column_name='verrouille_jusqu_a') THEN
    RAISE EXCEPTION 'V17 : colonne users.verrouille_jusqu_a absente';
  END IF;

  RAISE NOTICE 'V17 : OK';
END $$;

COMMIT;