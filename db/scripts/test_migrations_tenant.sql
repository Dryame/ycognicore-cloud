-- =====================================================================
-- test_migrations_tenant.sql (VERSION CORRIGÉE 30/09/2026)
-- Base : ycc_tenant_<id>
-- Objet : Vérification post-migration (14 tables + triggers + fonctions)
-- Note  : les tests 10 et 12 utilisent BEGIN/ROLLBACK pour ne pas
--         laisser de données résiduelles
-- =====================================================================

\echo '═══════════════════════════════════════════════════════'
\echo '  TEST TENANT — 14 tables attendues'
\echo '═══════════════════════════════════════════════════════'
\echo ''

\echo '=== TEST 1 : Nombre de tables ==='
SELECT COUNT(*) AS nb_tables_total
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

\echo ''
\echo '=== TEST 2 : Liste des tables ==='
\dt

\echo ''
\echo '=== TEST 3 : Tables manquantes (doit être vide) ==='
SELECT t AS table_manquante
FROM (VALUES
    ('modules'), ('permissions'), ('roles'), ('role_permissions'),
    ('users'), ('user_roles'), ('user_invitations'),
    ('sessions_history'), ('audit_log'), ('password_history'),
    ('login_attempts'),
    ('numero_sequences'), ('payment_transactions'), ('webhook_events')
) AS expected(t)
WHERE t NOT IN (
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'public'
);

\echo ''
\echo '=== TEST 4 : Permissions RBAC fixes ==='
SELECT code, libelle FROM permissions
WHERE code IN ('LIRE','CREER','MODIFIER','SUPPRIMER','VALIDER','EXPORTER')
ORDER BY code;

\echo ''
\echo '=== TEST 5 : Nombre de modules ==='
SELECT COUNT(*) AS nb_modules FROM modules;

\echo ''
\echo '=== TEST 6 : Colonnes critiques ==='
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
      (table_name = 'users' AND column_name IN ('date_expiration_mot_de_passe','date_verrouillage','langue_preferee'))
      OR (table_name = 'roles' AND column_name = 'scope')
      OR (table_name = 'user_roles' AND column_name IN ('date_fin','statut'))
      OR (table_name = 'sessions_history' AND column_name IN ('mfa_verifie','refresh_token_hash'))
      OR (table_name = 'audit_log' AND column_name IN ('session_id','module_id','niveau','avant','apres'))
      OR (table_name = 'password_history' AND column_name IN ('change_par','motif'))
      OR (table_name = 'login_attempts' AND column_name IN ('user_agent','raison_echec','pays'))
  )
ORDER BY table_name, column_name;

\echo ''
\echo '=== TEST 7 : Triggers ==='
SELECT DISTINCT tgname AS trigger_name
FROM pg_trigger
WHERE tgname IN (
    'trg_permissions_immuables',
    'trg_audit_log_immuable',
    'trg_password_history_append_only',
    'trg_verrouillage_auto'
) ORDER BY tgname;

\echo ''
\echo '=== TEST 8 : Partitions audit_log et login_attempts ==='
SELECT relname AS partition_name FROM pg_class
WHERE relkind = 'r'
  AND (relname LIKE 'audit_log_%' OR relname LIKE 'login_attempts_%')
  AND relname NOT LIKE '%_pkey%'
  AND relname NOT LIKE '%_idx%'
ORDER BY relname;

\echo ''
\echo '=== TEST 9 : Immuabilité des permissions ==='
DO $$
BEGIN
    BEGIN
        DELETE FROM permissions WHERE code = 'LIRE';
        RAISE EXCEPTION 'ECHEC : le trigger permissions n''a pas bloqué !';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%fixes%' THEN
            RAISE NOTICE 'OK : immuabilité permissions fonctionne';
        ELSE
            RAISE;
        END IF;
    END;
END $$;

\echo ''
\echo '=== TEST 10 : Verrouillage automatique (5 échecs) ==='
\echo 'Utilisation d''une transaction pour ne pas laisser de données résiduelles'
BEGIN;

INSERT INTO users (email, mot_de_passe_hash, nom, prenom)
VALUES ('verrou.test@tenant.bf', '$2a$10$dummy', 'Verrou', 'Test');

WITH u AS (SELECT id FROM users WHERE email = 'verrou.test@tenant.bf')
INSERT INTO login_attempts (email, user_id, succes, ip, raison_echec)
SELECT 'verrou.test@tenant.bf', u.id, FALSE, '10.0.0.1'::inet, 'MOT_DE_PASSE'
FROM u, generate_series(1,5);

SELECT email, statut, motif_verrouillage
FROM users WHERE email = 'verrou.test@tenant.bf';

DO $$
DECLARE
    v_statut VARCHAR(20);
BEGIN
    SELECT statut INTO v_statut FROM users WHERE email = 'verrou.test@tenant.bf';
    IF v_statut = 'VERROUILLE' THEN
        RAISE NOTICE 'OK : verrouillage automatique fonctionne (statut=%)', v_statut;
    ELSE
        RAISE EXCEPTION 'ECHEC : statut attendu=VERROUILLE, obtenu=%', v_statut;
    END IF;
END $$;

ROLLBACK;

\echo ''
\echo '=== TEST 11 : Fonction prochain_numero tenant ==='
SELECT prochain_numero('FACTURE_CLIENT', EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER) AS numero_client;

\echo ''
\echo '=== TEST 12 : Trigger append-only password_history ==='
BEGIN;

DO $$
DECLARE
    v_user_id UUID;
    v_pwd_id BIGINT;
BEGIN
    INSERT INTO users (email, mot_de_passe_hash, nom, prenom)
    VALUES ('pwd.test@tenant.bf', '$2a$10$dummy', 'Pwd', 'Test')
    RETURNING id INTO v_user_id;

    INSERT INTO password_history (user_id, hash, motif)
    VALUES (v_user_id, '$2a$10$dummy', 'FORCE')
    RETURNING id INTO v_pwd_id;

    BEGIN
        UPDATE password_history SET hash = 'modified' WHERE id = v_pwd_id;
        RAISE EXCEPTION 'ECHEC : trigger append-only n''a pas bloqué !';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%append-only%' THEN
            RAISE NOTICE 'OK : append-only password_history fonctionne';
        ELSE
            RAISE;
        END IF;
    END;
END $$;

ROLLBACK;

\echo ''
\echo '=== TEST 13 : Isolation (vérification préalable) ==='
SELECT 'Base courante : ' || current_database() AS info;

\echo ''
\echo '═══════════════════════════════════════════════════════'
\echo '  FIN DES TESTS TENANT'
\echo '═══════════════════════════════════════════════════════'
