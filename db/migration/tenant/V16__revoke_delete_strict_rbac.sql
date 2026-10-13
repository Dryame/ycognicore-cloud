-- V16__revoke_delete_strict_rbac.sql
-- Base : ycc_tenant_<id>
-- Objet : Révoquer DELETE sur les 7 tables héritées de V1/V4/V5
-- Ref.  : T1.3, C31, exigence 2.1
-- Idempotente : oui (REVOKE est idempotent)
-- Défensive : tolère l'absence du rôle ycc_tenant_app (conteneur test vierge)

-- Les GRANT DELETE ont été accordés dans V1 (l.235), V4 (l.98), V5 (l.58).
-- V1/V4/V5 sont immuables (règle fondamentale).
-- Le design soft delete (deleted_at) exige l'absence de DELETE physique.

DO $$
DECLARE
    t TEXT;
    tables_cibles TEXT[] := ARRAY[
        'users',
        'roles',
        'role_permissions',
        'user_roles',
        'sessions_history',
        'numero_sequences',
        'user_invitations'
    ];
BEGIN
    -- Vérifier que le rôle applicatif existe
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ycc_tenant_app') THEN
        RAISE NOTICE 'V16 : rôle ycc_tenant_app absent — REVOKE différé (conteneur test ou provisioning incomplet)';
        RETURN;
    END IF;

    -- Révoquer DELETE sur chaque table si elle existe
    FOREACH t IN ARRAY tables_cibles LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = t
        ) THEN
            EXECUTE format('REVOKE DELETE ON %I FROM ycc_tenant_app', t);
            RAISE NOTICE 'V16 : DELETE révoqué sur %', t;
        ELSE
            RAISE NOTICE 'V16 : table % absente — REVOKE ignoré', t;
        END IF;
    END LOOP;
END $$;

-- ============================================================================
-- Vérifications post-migration (tolérantes)
-- ============================================================================
DO $$
DECLARE
    remaining INTEGER;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ycc_tenant_app') THEN
        RAISE NOTICE 'V16 OK — rôle absent, vérification ignorée';
        RETURN;
    END IF;

    SELECT COUNT(*) INTO remaining
    FROM information_schema.role_table_grants
    WHERE grantee = 'ycc_tenant_app'
      AND privilege_type = 'DELETE'
      AND table_schema = 'public'
      AND table_name IN ('users', 'roles', 'role_permissions', 'user_roles',
                         'sessions_history', 'numero_sequences', 'user_invitations');

    IF remaining > 0 THEN
        RAISE EXCEPTION 'V16 : % GRANT DELETE persistent(s) après REVOKE', remaining;
    END IF;

    RAISE NOTICE 'V16 OK — DELETE révoqué sur les 7 tables';
END $$;
