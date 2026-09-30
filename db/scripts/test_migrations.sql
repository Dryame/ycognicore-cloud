-- =====================================================================
-- test_migrations.sql
-- Base : ycc_control_plane
-- Objet : Vérification post-migration (21 tables attendues)
-- Usage : psql -h localhost -U postgres -d ycc_control_plane -f db/scripts/test_migrations.sql
-- =====================================================================

\echo '═══════════════════════════════════════════════════════'
\echo '  TEST CONTROL PLANE — 21 tables attendues'
\echo '═══════════════════════════════════════════════════════'
\echo ''

\echo '=== TEST 1 : Nombre de tables ==='
SELECT COUNT(*) AS nb_tables_attendu_21
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

\echo ''
\echo '=== TEST 2 : Liste des tables ==='
\dt

\echo ''
\echo '=== TEST 3 : Tables manquantes (doit être vide) ==='
SELECT t AS table_manquante
FROM (VALUES
    ('tenants'), ('tenant_databases'), ('superadmin_users'),
    ('kyc_documents'), ('system_monitoring'),
    ('subscriptions'), ('subscription_invoices'),
    ('ia_quotas'),
    ('modules'), ('formule_caracteristiques'), ('formule_modules'),
    ('numero_sequences'), ('payment_transactions'), ('webhook_events'),
    ('alertes_securite'), ('notifications_queue'), ('jobs_async'),
    ('superadmin_password_history'), ('superadmin_login_attempts'),
    ('superadmin_sessions'), ('superadmin_audit_log')
) AS expected(t)
WHERE t NOT IN (
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'public'
);

\echo ''
\echo '=== TEST 4 : Colonnes critiques ==='
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
      (table_name = 'superadmin_users' AND column_name IN ('mfa_secret_package', 'mfa_enabled'))
      OR (table_name = 'subscription_invoices' AND column_name = 'numero_facture')
      OR (table_name = 'system_monitoring' AND column_name = 'tenant_id')
      OR (table_name = 'ia_quotas' AND column_name IN ('alerte_envoyee', 'cout_total', 'cache_hits'))
      OR (table_name = 'tenants' AND column_name IN ('date_fin_essai', 'date_suppression'))
      OR (table_name = 'subscriptions' AND column_name IN ('date_resiliation', 'reference_contrat'))
  )
ORDER BY table_name, column_name;

\echo ''
\echo '=== TEST 5 : Triggers immuabilité ==='
SELECT tgname AS trigger_name, tgrelid::regclass AS table_name
FROM pg_trigger
WHERE tgname IN (
    'trg_tenants_code_immuable',
    'trg_sa_pwd_history_append_only',
    'trg_sa_audit_immuable',
    'trg_verrouillage_sa'
) ORDER BY tgname;

\echo ''
\echo '=== TEST 6 : Fonctions critiques ==='
SELECT proname AS function_name FROM pg_proc
WHERE proname IN (
    'prochain_numero',
    'incrementer_consommation_ia',
    'verrouiller_superadmin_apres_echecs',
    'empecher_modification_code_tenant',
    'empecher_modification_sa_pwd_history',
    'empecher_modification_sa_audit'
) ORDER BY proname;

\echo ''
\echo '=== TEST 7 : Partitions superadmin ==='
SELECT relname AS partition_name FROM pg_class
WHERE relname LIKE 'superadmin_%' AND relkind = 'r'
  AND relname NOT LIKE '%_pkey%'
ORDER BY relname;

\echo ''
\echo '=== TEST 8 : Immuabilité du code tenant ==='
DO $$
BEGIN
    BEGIN
        INSERT INTO tenants (code, nom, email_contact)
        VALUES ('TEST-IMMU', 'Test', 'test-immu@test.bf');
        UPDATE tenants SET code = 'TEST-MODIF' WHERE code = 'TEST-IMMU';
        RAISE EXCEPTION 'ECHEC : le trigger immuabilité n''a pas bloqué !';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%immuable%' THEN
            RAISE NOTICE 'OK : immuabilité tenants.code fonctionne';
        ELSE
            RAISE;
        END IF;
    END;
    DELETE FROM tenants WHERE code = 'TEST-IMMU';
END $$;

\echo ''
\echo '=== TEST 9 : Fonction prochain_numero ==='
SELECT prochain_numero('FACTURE_SAAS', EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER) AS numero_genere;

\echo ''
\echo '═══════════════════════════════════════════════════════'
\echo '  FIN DES TESTS CONTROL PLANE'
\echo '═══════════════════════════════════════════════════════'
