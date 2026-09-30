-- =====================================================================
-- seed_control_plane.sql
-- Base : ycc_control_plane
-- Objet : Données initiales de test (Superadmin, tenants DEMO, KYC)
-- =====================================================================

\echo '=== SEED CONTROL PLANE ==='

DO $$
DECLARE
    v_superadmin_id UUID;
    v_email CITEXT := 'superadmin@ycognicore.bf';
    v_hash TEXT := '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewKyOaXnvGzU5m2q';
BEGIN
    IF NOT EXISTS (SELECT 1 FROM superadmin_users WHERE email = v_email) THEN
        INSERT INTO superadmin_users (
            email, nom_complet, mot_de_passe_hash,
            mfa_enabled, statut, date_expiration_mot_de_passe
        ) VALUES (
            v_email, 'Super Administrateur yCogniCore',
            v_hash, FALSE, 'ACTIF',
            (CURRENT_DATE + INTERVAL '90 days')::DATE
        ) RETURNING id INTO v_superadmin_id;

        INSERT INTO superadmin_password_history
            (superadmin_id, hash, change_par)
        VALUES (v_superadmin_id, v_hash, v_superadmin_id);

        RAISE NOTICE 'Superadmin créé : %', v_email;
        RAISE NOTICE 'Mot de passe initial : SuperAdmin@2026! (À CHANGER)';
    ELSE
        RAISE NOTICE 'Superadmin déjà présent : %', v_email;
    END IF;
END $$;

DO $$
DECLARE
    v_tenant_id UUID;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tenants WHERE code = 'DEMO001') THEN
        INSERT INTO tenants (
            code, nom, email_contact, telephone, adresse, pays,
            statut, formule, date_fin_essai
        ) VALUES (
            'DEMO001', 'Entreprise de Démonstration SARL',
            'contact@demo001.bf', '+226 70 00 00 01',
            'Ouagadougou, Burkina Faso', 'Burkina Faso',
            'TRIAL', 'TRIAL',
            (CURRENT_DATE + INTERVAL '30 days')::DATE
        ) RETURNING id INTO v_tenant_id;

        INSERT INTO kyc_documents (
            tenant_id, type_document, url, hash_document, statut_verification
        ) VALUES
            (v_tenant_id, 'REGISTRE_COMMERCE', 'minio://kyc/DEMO001/rc.pdf',
             encode(digest('rc-demo-001'::bytea, 'sha256'), 'hex'), 'EN_ATTENTE'),
            (v_tenant_id, 'IDENTIFIANT_FISCAL', 'minio://kyc/DEMO001/ifu.pdf',
             encode(digest('ifu-demo-001'::bytea, 'sha256'), 'hex'), 'EN_ATTENTE');

        RAISE NOTICE 'Tenant DEMO001 créé + 2 KYC';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM tenants WHERE code = 'DEMO002') THEN
        INSERT INTO tenants (
            code, nom, email_contact, telephone, pays, statut, formule
        ) VALUES (
            'DEMO002', 'Entreprise Démo 2 SARL',
            'contact@demo002.bf', '+226 70 00 00 02',
            'Burkina Faso', 'ACTIF', 'STANDARD'
        ) RETURNING id INTO v_tenant_id;

        RAISE NOTICE 'Tenant DEMO002 créé';
    END IF;
END $$;

\echo ''
\echo '=== ÉTAT APRÈS SEED ==='
SELECT 'superadmin_users' AS table_name, COUNT(*) AS nb FROM superadmin_users
UNION ALL SELECT 'tenants', COUNT(*) FROM tenants
UNION ALL SELECT 'kyc_documents', COUNT(*) FROM kyc_documents
UNION ALL SELECT 'formule_caracteristiques', COUNT(*) FROM formule_caracteristiques
UNION ALL SELECT 'modules', COUNT(*) FROM modules
UNION ALL SELECT 'numero_sequences', COUNT(*) FROM numero_sequences;
