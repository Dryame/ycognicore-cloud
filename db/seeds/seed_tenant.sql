-- =====================================================================
-- seed_tenant.sql
-- Base : ycc_tenant_<id>
-- Objet : Rôles préconfigurés (4 profils) + utilisateurs métiers test
-- Réf.  : 04-78 section 1.3
-- =====================================================================

\echo '=== SEED TENANT ==='

DO $$
DECLARE
    v_role_id UUID;
    v_hash TEXT := '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewKyOaXnvGzU5m2q';
BEGIN
    -- Rôle 1 : Responsable Commercial
    IF NOT EXISTS (SELECT 1 FROM roles WHERE nom = 'Responsable Commercial') THEN
        INSERT INTO roles (nom, description, est_systeme, scope, statut)
        VALUES ('Responsable Commercial',
                'Pilote le cycle commercial', TRUE,
                '{"fonctions": ["Commercial"]}'::jsonb, 'ACTIF')
        RETURNING id INTO v_role_id;

        INSERT INTO role_permissions (role_id, permission_id, module_id)
        SELECT v_role_id, p.id, m.id FROM permissions p CROSS JOIN modules m
        WHERE p.code IN ('LIRE','CREER','MODIFIER','VALIDER','EXPORTER')
          AND m.code IN ('CRM','VENTES','CLIENTS','TABLEAU_DE_BORD','RAPPORTS_BI');

        RAISE NOTICE 'Rôle "Responsable Commercial" créé';
    END IF;

    -- Rôle 2 : Responsable Financier
    IF NOT EXISTS (SELECT 1 FROM roles WHERE nom = 'Responsable Financier et Comptable') THEN
        INSERT INTO roles (nom, description, est_systeme, scope, statut)
        VALUES ('Responsable Financier et Comptable',
                'Comptabilité et fiscalité', TRUE,
                '{"fonctions": ["Finance"]}'::jsonb, 'ACTIF')
        RETURNING id INTO v_role_id;

        INSERT INTO role_permissions (role_id, permission_id, module_id)
        SELECT v_role_id, p.id, m.id FROM permissions p CROSS JOIN modules m
        WHERE p.code IN ('LIRE','CREER','MODIFIER','VALIDER','EXPORTER')
          AND m.code IN ('COMPTABILITE','TRESORERIE','TABLEAU_DE_BORD','RAPPORTS_BI');

        RAISE NOTICE 'Rôle "Responsable Financier et Comptable" créé';
    END IF;

    -- Rôle 3 : Magasinier
    IF NOT EXISTS (SELECT 1 FROM roles WHERE nom = 'Responsable des Stocks et Magasinier') THEN
        INSERT INTO roles (nom, description, est_systeme, scope, statut)
        VALUES ('Responsable des Stocks et Magasinier',
                'Stocks et logistique', TRUE,
                '{"fonctions": ["Logistique"]}'::jsonb, 'ACTIF')
        RETURNING id INTO v_role_id;

        INSERT INTO role_permissions (role_id, permission_id, module_id)
        SELECT v_role_id, p.id, m.id FROM permissions p CROSS JOIN modules m
        WHERE p.code IN ('LIRE','CREER','MODIFIER','VALIDER','EXPORTER')
          AND m.code IN ('STOCK','ARTICLES','TABLEAU_DE_BORD');

        RAISE NOTICE 'Rôle "Responsable des Stocks et Magasinier" créé';
    END IF;

    -- Rôle 4 : Responsable Achats
    IF NOT EXISTS (SELECT 1 FROM roles WHERE nom = 'Responsable Achats') THEN
        INSERT INTO roles (nom, description, est_systeme, scope, statut)
        VALUES ('Responsable Achats',
                'Approvisionnement', TRUE,
                '{"fonctions": ["Achats"]}'::jsonb, 'ACTIF')
        RETURNING id INTO v_role_id;

        INSERT INTO role_permissions (role_id, permission_id, module_id)
        SELECT v_role_id, p.id, m.id FROM permissions p CROSS JOIN modules m
        WHERE p.code IN ('LIRE','CREER','MODIFIER','VALIDER','EXPORTER')
          AND m.code IN ('ACHATS','FOURNISSEURS','ARTICLES','TABLEAU_DE_BORD');

        RAISE NOTICE 'Rôle "Responsable Achats" créé';
    END IF;

    -- 4 utilisateurs de test (1 par rôle)
    INSERT INTO users (email, mot_de_passe_hash, nom, prenom, type_utilisateur, statut,
                       mot_de_passe_a_changer, langue_preferee, date_expiration_mot_de_passe)
    SELECT * FROM (VALUES
        ('commercial@demo001.bf', v_hash, 'OUEDRAOGO', 'Awa', 'INTERNE', 'ACTIF', TRUE, 'fr', (CURRENT_DATE + INTERVAL '90 days')::DATE),
        ('comptable@demo001.bf',  v_hash, 'SAWADOGO', 'Ibrahim', 'INTERNE', 'ACTIF', TRUE, 'fr', (CURRENT_DATE + INTERVAL '90 days')::DATE),
        ('magasinier@demo001.bf', v_hash, 'KONE', 'Fatimata', 'INTERNE', 'ACTIF', TRUE, 'fr', (CURRENT_DATE + INTERVAL '90 days')::DATE),
        ('acheteur@demo001.bf',   v_hash, 'TRAORE', 'Boukary', 'INTERNE', 'ACTIF', TRUE, 'fr', (CURRENT_DATE + INTERVAL '90 days')::DATE)
    ) AS t(email, hash, nom, prenom, type, statut, a_changer, langue, exp)
    WHERE NOT EXISTS (SELECT 1 FROM users u WHERE u.email = t.email);

    -- Historique initial des mots de passe
    INSERT INTO password_history (user_id, hash, motif)
    SELECT u.id, v_hash, 'FORCE' FROM users u
    WHERE u.email LIKE '%@demo001.bf'
      AND NOT EXISTS (SELECT 1 FROM password_history ph WHERE ph.user_id = u.id);

    -- Lier les utilisateurs à leurs rôles
    INSERT INTO user_roles (user_id, role_id, statut)
    SELECT u.id, r.id, 'ACTIF' FROM users u CROSS JOIN roles r
    WHERE (u.email = 'commercial@demo001.bf' AND r.nom = 'Responsable Commercial')
       OR (u.email = 'comptable@demo001.bf' AND r.nom = 'Responsable Financier et Comptable')
       OR (u.email = 'magasinier@demo001.bf' AND r.nom = 'Responsable des Stocks et Magasinier')
       OR (u.email = 'acheteur@demo001.bf' AND r.nom = 'Responsable Achats')
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Utilisateurs de test créés (mot de passe : Test@2026!)';
END $$;

\echo ''
\echo '=== ÉTAT APRÈS SEED TENANT ==='
SELECT 'modules' AS table_name, COUNT(*) AS nb FROM modules
UNION ALL SELECT 'permissions', COUNT(*) FROM permissions
UNION ALL SELECT 'roles', COUNT(*) FROM roles
UNION ALL SELECT 'role_permissions', COUNT(*) FROM role_permissions
UNION ALL SELECT 'users', COUNT(*) FROM users
UNION ALL SELECT 'user_roles', COUNT(*) FROM user_roles;

\echo ''
\echo 'Utilisateurs de test :'
SELECT u.email, r.nom AS role FROM users u
JOIN user_roles ur ON ur.user_id = u.id
JOIN roles r ON r.id = ur.role_id
WHERE u.email LIKE '%@demo001.bf'
ORDER BY u.email;
