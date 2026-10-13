-- V15__protect_audit_log_from_truncate.sql
-- Base : ycc_tenant_<id>
-- Objet : Interdire TRUNCATE sur audit_log et les tables append-only
-- Ref.  : T1.3, M11, C3, exigence 2.7
-- Idempotente : oui
--
-- IMPORTANT : TRUNCATE ne déclenche PAS les triggers de niveau ligne.
-- Il faut un trigger BEFORE TRUNCATE (niveau STATEMENT).

-- ============================================================================
-- 1. Fonction de blocage générique
-- ============================================================================
CREATE OR REPLACE FUNCTION forbid_truncate()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'TRUNCATE interdit sur % (protection append-only)',
        TG_TABLE_NAME
        USING ERRCODE = '42501';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 2. Trigger sur audit_log (si présent)
-- ============================================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_class c
               JOIN pg_namespace n ON n.oid = c.relnamespace
               WHERE n.nspname = 'public' AND c.relname = 'audit_log')
    THEN
        EXECUTE 'DROP TRIGGER IF EXISTS trg_audit_log_no_truncate ON audit_log';
        EXECUTE 'CREATE TRIGGER trg_audit_log_no_truncate '
             || 'BEFORE TRUNCATE ON audit_log '
             || 'FOR EACH STATEMENT EXECUTE FUNCTION forbid_truncate()';
        RAISE NOTICE 'V15 : trigger posé sur audit_log';
    ELSE
        RAISE NOTICE 'V15 : audit_log absent, trigger parent non posé (sera posé en P3)';
    END IF;
END $$;

-- ============================================================================
-- 3. Triggers sur chaque partition de audit_log (si présentes)
-- ============================================================================
DO $$
DECLARE
    part_name TEXT;
BEGIN
    FOR part_name IN
        SELECT c.relname
        FROM pg_class c
        JOIN pg_inherits i ON i.inhrelid = c.oid
        JOIN pg_class p ON p.oid = i.inhparent
        WHERE p.relname = 'audit_log'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_no_truncate ON %I', part_name, part_name);
        EXECUTE format(
            'CREATE TRIGGER trg_%s_no_truncate BEFORE TRUNCATE ON %I '
            'FOR EACH STATEMENT EXECUTE FUNCTION forbid_truncate()',
            part_name, part_name);
        RAISE NOTICE 'V15 : trigger posé sur partition %', part_name;
    END LOOP;
END $$;

-- ============================================================================
-- 4. Triggers sur tables append-only (si présentes)
-- ============================================================================
DO $$
DECLARE
    t TEXT;
    tables_append_only TEXT[] := ARRAY[
        'password_history',
        'interactions',
        'opportunites_historique_etapes',
        'documents_vente_historique_statuts'
    ];
BEGIN
    FOREACH t IN ARRAY tables_append_only LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_schema = 'public' AND table_name = t) THEN
            EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_no_truncate ON %I', t, t);
            EXECUTE format(
                'CREATE TRIGGER trg_%s_no_truncate BEFORE TRUNCATE ON %I '
                'FOR EACH STATEMENT EXECUTE FUNCTION forbid_truncate()',
                t, t);
            RAISE NOTICE 'V15 : trigger posé sur %', t;
        END IF;
    END LOOP;
END $$;

-- ============================================================================
-- 5. REVOKE TRUNCATE du rôle applicatif (si rôle existe)
-- ============================================================================
DO $$
DECLARE
    part_name TEXT;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ycc_tenant_app') THEN
        IF EXISTS (SELECT 1 FROM pg_class c
                   JOIN pg_namespace n ON n.oid = c.relnamespace
                   WHERE n.nspname = 'public' AND c.relname = 'audit_log')
        THEN
            EXECUTE 'REVOKE TRUNCATE ON audit_log FROM ycc_tenant_app';
        END IF;

        FOR part_name IN
            SELECT c.relname FROM pg_class c
            JOIN pg_inherits i ON i.inhrelid = c.oid
            JOIN pg_class p ON p.oid = i.inhparent
            WHERE p.relname = 'audit_log'
        LOOP
            EXECUTE format('REVOKE TRUNCATE ON %I FROM ycc_tenant_app', part_name);
        END LOOP;
    END IF;
END $$;

-- ============================================================================
-- 6. Vérifications post-migration (tolérantes)
-- ============================================================================
DO $$
DECLARE
    has_trigger BOOLEAN;
BEGIN
    -- Vérifier le trigger si audit_log existe
    IF EXISTS (SELECT 1 FROM pg_class c
               JOIN pg_namespace n ON n.oid = c.relnamespace
               WHERE n.nspname = 'public' AND c.relname = 'audit_log')
    THEN
        SELECT EXISTS (
            SELECT 1 FROM pg_trigger
            WHERE tgname = 'trg_audit_log_no_truncate' AND NOT tgisinternal
        ) INTO has_trigger;

        IF NOT has_trigger THEN
            RAISE EXCEPTION 'V15 : trigger trg_audit_log_no_truncate absent';
        END IF;
    END IF;

    RAISE NOTICE 'V15 OK — protection TRUNCATE appliquée';
END $$;
