-- ============================================================================
-- test_v10_migration.sql
-- Tests du bloc V10 — Référentiel Tiers
-- ============================================================================

SET search_path TO public;

DO $$
DECLARE
    v_passed INTEGER := 0;
    v_failed INTEGER := 0;
    v_tiers_id UUID;
    v_role_id UUID;
    v_contact_id UUID;
    v_fk_name TEXT;
    v_expected CHAR(1);
    v_actual CHAR(1);
    v_missing TEXT := '';
    v_before TIMESTAMPTZ;
    v_after TIMESTAMPTZ;
    v_ver_before INTEGER;
    v_ver_after INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'TESTS BLOC V10 — REFERENTIEL TIERS';
    RAISE NOTICE '=============================================';

    TRUNCATE adresse_tiers, contact_tiers, role_tiers, tiers CASCADE;

    -- STRUCTURE (4)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='tiers') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-01 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-01 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='role_tiers') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-02 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-02 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='contact_tiers') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-03 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-03 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='adresse_tiers') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-04 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-04 KO'; END IF;

    -- INSERTION VALIDE (3)
    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal, email, telephone, plafond_encours)
        VALUES ('TIE-2026-000001','PERSONNE_MORALE','ENTREPRISE','SARL Test Burkina','REEL_NORMAL','contact@sarl-test.bf','+226 70 00 00 00',5000000)
        RETURNING id INTO v_tiers_id;
        v_passed:=v_passed+1; RAISE NOTICE 'T-05 OK';
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-05 KO : %', SQLERRM; END;

    BEGIN
        INSERT INTO role_tiers (tiers_id, role) VALUES (v_tiers_id, 'CLIENT') RETURNING id INTO v_role_id;
        v_passed:=v_passed+1; RAISE NOTICE 'T-06 OK';
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-06 KO'; END;

    BEGIN
        INSERT INTO contact_tiers (tiers_id, nom, prenom, fonction, est_principal)
        VALUES (v_tiers_id, 'OUEDRAOGO', 'Issa', 'Directeur', TRUE) RETURNING id INTO v_contact_id;
        v_passed:=v_passed+1; RAISE NOTICE 'T-07 OK';
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-07 KO'; END;

    -- UNIQUE (7)
    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
        VALUES ('TIE-2026-000001','PERSONNE_MORALE','ENTREPRISE','Doublon','REEL_NORMAL');
        v_failed:=v_failed+1; RAISE NOTICE 'T-08 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-08 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
        VALUES ('INVALID','PERSONNE_MORALE','ENTREPRISE','X','REEL_NORMAL');
        v_failed:=v_failed+1; RAISE NOTICE 'T-09 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-09 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal, ifu)
        VALUES ('TIE-2026-000002','PERSONNE_MORALE','ENTREPRISE','X','REEL_NORMAL','IFU-12345');
        v_passed:=v_passed+1; RAISE NOTICE 'T-10 OK';
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-10 KO'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal, ifu)
        VALUES ('TIE-2026-000003','PERSONNE_MORALE','ENTREPRISE','Y','REEL_NORMAL','IFU-12345');
        v_failed:=v_failed+1; RAISE NOTICE 'T-11 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-11 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
        VALUES ('TIE-2026-000004','PERSONNE_MORALE','ENTREPRISE','Z','REEL_NORMAL');
        v_passed:=v_passed+1; RAISE NOTICE 'T-12 OK';
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-12 KO'; END;

    BEGIN
        INSERT INTO role_tiers (tiers_id, role) VALUES (v_tiers_id, 'CLIENT');
        v_failed:=v_failed+1; RAISE NOTICE 'T-13 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-13 OK'; END;

    BEGIN
        INSERT INTO contact_tiers (tiers_id, nom, prenom, est_principal)
        VALUES (v_tiers_id, 'X', 'Y', TRUE);
        v_failed:=v_failed+1; RAISE NOTICE 'T-14 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-14 OK'; END;

    -- CHECK (8)
    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
        VALUES ('TIE-2026-000010','INVALIDE','ENTREPRISE','X','REEL_NORMAL');
        v_failed:=v_failed+1; RAISE NOTICE 'T-15 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-15 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
        VALUES ('TIE-2026-000011','PERSONNE_MORALE','INVALIDE','X','REEL_NORMAL');
        v_failed:=v_failed+1; RAISE NOTICE 'T-16 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-16 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
        VALUES ('TIE-2026-000012','PERSONNE_MORALE','ENTREPRISE','X','INVALIDE');
        v_failed:=v_failed+1; RAISE NOTICE 'T-17 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-17 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal, statut)
        VALUES ('TIE-2026-000013','PERSONNE_MORALE','ENTREPRISE','X','REEL_NORMAL','INVALIDE');
        v_failed:=v_failed+1; RAISE NOTICE 'T-18 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-18 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal, delai_paiement_jours)
        VALUES ('TIE-2026-000014','PERSONNE_MORALE','ENTREPRISE','X','REEL_NORMAL',-1);
        v_failed:=v_failed+1; RAISE NOTICE 'T-19 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-19 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal, plafond_encours)
        VALUES ('TIE-2026-000015','PERSONNE_MORALE','ENTREPRISE','X','REEL_NORMAL',-1);
        v_failed:=v_failed+1; RAISE NOTICE 'T-20 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-20 OK'; END;

    BEGIN
        INSERT INTO role_tiers (tiers_id, role) VALUES (v_tiers_id, 'INVALIDE');
        v_failed:=v_failed+1; RAISE NOTICE 'T-21 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-21 OK'; END;

    BEGIN
        INSERT INTO contact_tiers (tiers_id, nom, prenom, canal_prefere)
        VALUES (v_tiers_id, 'X', 'Y', 'INVALIDE');
        v_failed:=v_failed+1; RAISE NOTICE 'T-22 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-22 OK'; END;

    -- FK (5)
    FOR v_fk_name, v_expected IN
        SELECT * FROM (VALUES ('fk_role_tiers_tiers','c'),('fk_contact_tiers_tiers','c'),('fk_adresse_tiers_tiers','c')) AS t(name, expected)
    LOOP
        SELECT confdeltype INTO v_actual FROM pg_constraint WHERE conname = v_fk_name;
        IF v_actual = v_expected THEN v_passed:=v_passed+1;
        ELSE v_failed:=v_failed+1; v_missing := v_missing || v_fk_name || ' '; END IF;
    END LOOP;
    RAISE NOTICE 'T-23 a T-25 OK (3 FK CASCADE)';

    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tiers_created_by_fkey') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-26 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-26 KO'; END IF;

    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tiers_updated_by_fkey') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-27 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-27 KO'; END IF;

    -- TRIGGERS (4)
    SELECT updated_at INTO v_before FROM tiers WHERE id = v_tiers_id;
    PERFORM pg_sleep(0.1);
    UPDATE tiers SET raison_sociale = 'SARL Test Modifie' WHERE id = v_tiers_id;
    SELECT updated_at INTO v_after FROM tiers WHERE id = v_tiers_id;
    IF v_after > v_before THEN v_passed:=v_passed+1; RAISE NOTICE 'T-28 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-28 KO'; END IF;

    SELECT version INTO v_ver_before FROM tiers WHERE id = v_tiers_id;
    UPDATE tiers SET raison_sociale = 'SARL Test Modifie 2' WHERE id = v_tiers_id;
    SELECT version INTO v_ver_after FROM tiers WHERE id = v_tiers_id;
    IF v_ver_after = v_ver_before + 1 THEN v_passed:=v_passed+1; RAISE NOTICE 'T-29 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-29 KO'; END IF;

    BEGIN
        DELETE FROM tiers WHERE id = v_tiers_id;
        v_failed:=v_failed+1; RAISE NOTICE 'T-30 KO';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%Suppression physique interdite%' THEN
            v_passed:=v_passed+1; RAISE NOTICE 'T-30 OK';
        ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-30 KO'; END IF;
    END;

    IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_role_tiers_no_hard_delete') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-31 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-31 KO'; END IF;

    -- ISOLATION (1)
    IF (SELECT COUNT(*) FROM information_schema.columns
        WHERE column_name = 'tenant_id'
          AND table_name IN ('tiers','role_tiers','contact_tiers','adresse_tiers')) = 0 THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-32 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-32 KO'; END IF;

    -- CAS METIER (5)
    INSERT INTO role_tiers (tiers_id, role) VALUES (v_tiers_id, 'FOURNISSEUR');
    IF (SELECT COUNT(*) FROM role_tiers WHERE tiers_id = v_tiers_id AND deleted_at IS NULL) = 2 THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-33 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-33 KO'; END IF;

    INSERT INTO adresse_tiers (tiers_id, type_adresse, rue, ville, est_principale)
    VALUES (v_tiers_id, 'SIEGE', 'Avenue 1', 'Ouagadougou', TRUE);

    BEGIN
        INSERT INTO adresse_tiers (tiers_id, type_adresse, rue, ville, est_principale)
        VALUES (v_tiers_id, 'SIEGE', 'Avenue 2', 'Ouagadougou', TRUE);
        v_failed:=v_failed+1; RAISE NOTICE 'T-34 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-34 OK'; END;

    BEGIN
        INSERT INTO adresse_tiers (tiers_id, type_adresse, rue, ville, est_principale)
        VALUES (v_tiers_id, 'SIEGE', 'Avenue 2', 'Ouagadougou', FALSE);
        v_passed:=v_passed+1; RAISE NOTICE 'T-35 OK';
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-35 KO'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
        VALUES ('TIE-2026-000099','PERSONNE_MORALE','ENTREPRISE', repeat('A', 300), 'REEL_NORMAL');
        v_failed:=v_failed+1; RAISE NOTICE 'T-36 KO';
    EXCEPTION WHEN string_data_right_truncation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-36 OK'; END;

    BEGIN
        INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
        VALUES ('TIE-2026-000098','PERSONNE_MORALE','ENTREPRISE','SARL O''Brien','REEL_NORMAL');
        v_passed:=v_passed+1; RAISE NOTICE 'T-37 OK';
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-37 KO'; END;

    -- NETTOYAGE
    UPDATE tiers SET deleted_at = now() WHERE code LIKE 'TIE-%';

    RAISE NOTICE '';
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'RESULTAT FINAL';
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'Tests reussis : %', v_passed;
    RAISE NOTICE 'Tests echoues : %', v_failed;
    RAISE NOTICE 'Total         : %', v_passed + v_failed;
    IF v_failed = 0 THEN RAISE NOTICE 'Statut : TOUS LES TESTS PASSENT';
    ELSE RAISE NOTICE 'Statut : % test(s) en echec', v_failed; END IF;
    RAISE NOTICE '=============================================';
END;
$$;
