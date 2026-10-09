-- ============================================================================
-- test_v9_migration.sql
-- Tests du bloc V9 — Fichiers + IA + KPI
-- ============================================================================

SET search_path TO public;

DO $$
DECLARE
    v_passed INTEGER := 0;
    v_failed INTEGER := 0;
    v_module_id INTEGER;
    v_fichier_id UUID;
    v_suggestion_id UUID;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'TESTS BLOC V9 — FICHIERS + IA + KPI';
    RAISE NOTICE '=============================================';

    TRUNCATE kpi_snapshots, ia_suggestions, fichiers CASCADE;

    SELECT id INTO v_module_id FROM modules WHERE code = 'CRM' LIMIT 1;

    -- STRUCTURE
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='fichiers') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-01 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-01 KO'; END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='ia_suggestions') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-02 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-02 KO'; END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='kpi_snapshots') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-03 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-03 KO'; END IF;

    -- FICHIERS
    BEGIN
        INSERT INTO fichiers (nom_original, nom_stockage, bucket, chemin,
            taille_octets, type_mime, hash_sha256)
        VALUES ('test.pdf','abc123.pdf','ycc-documents','/ycc-documents/abc123.pdf',
            1024, 'application/pdf',
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')
        RETURNING id INTO v_fichier_id;
        v_passed:=v_passed+1; RAISE NOTICE 'T-04 OK';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-04 KO : %', SQLERRM;
    END;

    BEGIN
        INSERT INTO fichiers (nom_original, nom_stockage, bucket, chemin,
            taille_octets, type_mime, hash_sha256)
        VALUES ('x.pdf','x1.pdf','invalide','/x1',1024,'application/pdf',repeat('a',64));
        v_failed:=v_failed+1; RAISE NOTICE 'T-05 KO';
    EXCEPTION WHEN check_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-05 OK';
    END;

    BEGIN
        INSERT INTO fichiers (nom_original, nom_stockage, bucket, chemin,
            taille_octets, type_mime, hash_sha256)
        VALUES ('y.pdf','y1.pdf','ycc-documents','/y1',1024,'application/pdf','invalid');
        v_failed:=v_failed+1; RAISE NOTICE 'T-06 KO';
    EXCEPTION WHEN check_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-06 OK';
    END;

    BEGIN
        DELETE FROM fichiers WHERE id = v_fichier_id;
        v_failed:=v_failed+1; RAISE NOTICE 'T-07 KO';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%Suppression physique interdite%' THEN
            v_passed:=v_passed+1; RAISE NOTICE 'T-07 OK';
        ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-07 KO : %', SQLERRM; END IF;
    END;

    IF (SELECT COUNT(*) FROM rechercher_fichier_par_hash(
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')) = 1 THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-08 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-08 KO'; END IF;

    -- IA
    BEGIN
        INSERT INTO ia_suggestions (module_id, type_suggestion, entite_cible, entite_id,
            contexte, suggestion, confiance, modele, tokens_consommes)
        VALUES (v_module_id, 'SCORING_PISTE', 'crm_pistes', gen_random_uuid(),
            '{"source":"test"}'::jsonb, '{"score":75}'::jsonb, 75, 'gpt-4-turbo', 250)
        RETURNING id INTO v_suggestion_id;
        v_passed:=v_passed+1; RAISE NOTICE 'T-09 OK';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-09 KO : %', SQLERRM;
    END;

    BEGIN
        INSERT INTO ia_suggestions (module_id, type_suggestion, entite_cible,
            contexte, suggestion, confiance, modele)
        VALUES (v_module_id,'TEST','x','{}'::jsonb,'{}'::jsonb,150,'x');
        v_failed:=v_failed+1; RAISE NOTICE 'T-10 KO';
    EXCEPTION WHEN check_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-10 OK';
    END;

    BEGIN
        INSERT INTO ia_suggestions (module_id, type_suggestion, entite_cible,
            contexte, suggestion, confiance, modele, statut)
        VALUES (v_module_id,'TEST','x','{}'::jsonb,'{}'::jsonb,50,'x','INVALIDE');
        v_failed:=v_failed+1; RAISE NOTICE 'T-11 KO';
    EXCEPTION WHEN check_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-11 OK';
    END;

    UPDATE ia_suggestions SET statut='ACCEPTEE', decision_humaine='ACCEPTEE',
        decidee_par=(SELECT id FROM users LIMIT 1), date_decision=now()
    WHERE id = v_suggestion_id;

    IF (SELECT statut FROM ia_suggestions WHERE id = v_suggestion_id) = 'ACCEPTEE' THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-12 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-12 KO'; END IF;

    -- KPI
    BEGIN
        INSERT INTO kpi_snapshots (code_kpi, module_id, date_snapshot, valeur, dimensions)
        VALUES ('CA_MENSUEL', v_module_id, CURRENT_DATE, 1500000.00,
                '{"tenant":"demo001"}'::jsonb);
        v_passed:=v_passed+1; RAISE NOTICE 'T-13 OK';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-13 KO : %', SQLERRM;
    END;

    BEGIN
        INSERT INTO kpi_snapshots (code_kpi, module_id, date_snapshot, valeur, dimensions)
        VALUES ('CA_MENSUEL', v_module_id, CURRENT_DATE, 2000000.00,
                '{"tenant":"demo001"}'::jsonb);
        v_failed:=v_failed+1; RAISE NOTICE 'T-14 KO';
    EXCEPTION WHEN unique_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-14 OK';
    END;

    -- NETTOYAGE
    UPDATE fichiers SET deleted_at = now() WHERE deleted_at IS NULL;
    UPDATE ia_suggestions SET deleted_at = now() WHERE deleted_at IS NULL;
    DELETE FROM kpi_snapshots WHERE date_snapshot = CURRENT_DATE;

    RAISE NOTICE '';
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'Tests reussis : %', v_passed;
    RAISE NOTICE 'Tests echoues : %', v_failed;
    RAISE NOTICE 'Total         : %', v_passed + v_failed;
    IF v_failed = 0 THEN RAISE NOTICE 'Statut : TOUS LES TESTS PASSENT';
    ELSE RAISE NOTICE 'Statut : % test(s) en echec', v_failed; END IF;
    RAISE NOTICE '=============================================';
END;
$$;
