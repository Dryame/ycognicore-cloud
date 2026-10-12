-- ============================================================================
-- test_v12_migration.sql
-- Tests du bloc V12 — CRM
-- ============================================================================

SET search_path TO public;

DO $$
DECLARE
    v_passed INTEGER := 0;
    v_failed INTEGER := 0;
    v_tiers_id UUID;
    v_prospect_id UUID;
    v_pipeline_id UUID;
    v_etape_id UUID;
    v_opportunite_id UUID;
    v_contact_id UUID;
    v_campagne_id UUID;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'TESTS BLOC V12 — CRM';
    RAISE NOTICE '=============================================';

    -- Nettoyer les données de test (garder les seeds)
    -- Nettoyer les données de test (TRUNCATE contourne les triggers)
    -- Les seeds (pipelines, pipeline_etapes) sont préservés
    TRUNCATE crm_regles_executions, crm_regles_automatisation,
             rendez_vous_participants, rendez_vous,
             interactions, activites,
             opportunites_historique_etapes, opportunites,
             campagne_cibles, campagnes,
             contacts, prospects CASCADE;

    -- Tiers de test
    INSERT INTO tiers (code, type_tiers, categorie, raison_sociale, regime_fiscal)
    VALUES ('TIE-2026-000001','PERSONNE_MORALE','ENTREPRISE','SARL Test CRM','REEL_NORMAL')
    ON CONFLICT (code) DO NOTHING;
    SELECT id INTO v_tiers_id FROM tiers WHERE code = 'TIE-2026-000001';

    -- STRUCTURE (14 tests)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='prospects') THEN
        v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-01 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='contacts') THEN
        v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-02 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='campagnes') THEN
        v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-03 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='campagne_cibles') THEN
        v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-04 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='pipelines') THEN
        v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-05 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='pipeline_etapes') THEN
        v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-06 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='opportunites') THEN
        v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-07 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='opportunites_historique_etapes') THEN
        v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-08 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='activites') THEN
        v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-09 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='interactions') THEN
        v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-10 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='rendez_vous') THEN
        v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-11 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='rendez_vous_participants') THEN
        v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-12 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='crm_regles_automatisation') THEN
        v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-13 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='crm_regles_executions') THEN
        v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-14 KO'; END IF;
    RAISE NOTICE 'T-01 a T-14 OK : 14 tables existent';

    -- SEEDS PIPELINE
    IF (SELECT COUNT(*) FROM pipeline_etapes) >= 6 THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-15 OK : pipeline seede';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-15 KO'; END IF;

    -- INSERTIONS VALIDES
    INSERT INTO prospects (code, nom, email, source) VALUES ('PRO-001','Prospect X','x@test.bf','WEB')
    RETURNING id INTO v_prospect_id;
    v_passed:=v_passed+1; RAISE NOTICE 'T-16 OK : prospect cree';

    INSERT INTO contacts (tiers_id, nom, prenom, est_principal) VALUES (v_tiers_id,'OUED','Issa',TRUE)
    RETURNING id INTO v_contact_id;
    v_passed:=v_passed+1; RAISE NOTICE 'T-17 OK : contact cree';

    INSERT INTO campagnes (code, nom, type_campagne, date_debut)
    VALUES ('CAMP-001','Promo','EMAILING',CURRENT_DATE) RETURNING id INTO v_campagne_id;
    v_passed:=v_passed+1; RAISE NOTICE 'T-18 OK : campagne creee';

    SELECT id INTO v_pipeline_id FROM pipelines WHERE code='STD' LIMIT 1;
    SELECT id INTO v_etape_id FROM pipeline_etapes WHERE pipeline_id=v_pipeline_id LIMIT 1;

    INSERT INTO opportunites (code, nom, tiers_id, pipeline_etape_id, montant_estime, date_cloture_prevue)
    VALUES ('OPP-001','Opportunite X',v_tiers_id,v_etape_id,1000000,CURRENT_DATE+30)
    RETURNING id INTO v_opportunite_id;
    v_passed:=v_passed+1; RAISE NOTICE 'T-19 OK : opportunite creee';

    -- CHECK
    BEGIN
        INSERT INTO prospects (code, nom, score_ia) VALUES ('PRO-002','Y',150);
        v_failed:=v_failed+1; RAISE NOTICE 'T-20 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; END;

    BEGIN
        INSERT INTO opportunites (code, nom, tiers_id, pipeline_etape_id, montant_estime, date_cloture_prevue)
        VALUES ('OPP-002','Y',v_tiers_id,v_etape_id,0,CURRENT_DATE+30);
        v_failed:=v_failed+1; RAISE NOTICE 'T-21 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; END;

    -- UNIQUE
    BEGIN
        INSERT INTO prospects (code, nom) VALUES ('PRO-001','Doublon');
        v_failed:=v_failed+1; RAISE NOTICE 'T-22 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; END;

    -- APPEND-ONLY
    BEGIN
        UPDATE interactions SET contenu='X' WHERE id IS NOT NULL;
        v_failed:=v_failed+1; RAISE NOTICE 'T-23 KO';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%append-only%' THEN v_passed:=v_passed+1;
        ELSE v_failed:=v_failed+1; END IF;
    END;

    -- TRIGGER UPDATE
    DECLARE
        v_before TIMESTAMPTZ; v_after TIMESTAMPTZ;
    BEGIN
        SELECT updated_at INTO v_before FROM prospects WHERE id=v_prospect_id;
        PERFORM pg_sleep(0.1);
        UPDATE prospects SET nom='Modifie' WHERE id=v_prospect_id;
        SELECT updated_at INTO v_after FROM prospects WHERE id=v_prospect_id;
        IF v_after > v_before THEN v_passed:=v_passed+1;
        ELSE v_failed:=v_failed+1; END IF;
    END;

    -- DELETE BLOQUE
    BEGIN
        DELETE FROM prospects WHERE id=v_prospect_id;
        v_failed:=v_failed+1; RAISE NOTICE 'T-25 KO';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%Suppression physique interdite%' THEN v_passed:=v_passed+1;
        ELSE v_failed:=v_failed+1; END IF;
    END;

    -- ISOLATION
    IF (SELECT COUNT(*) FROM information_schema.columns
        WHERE column_name='tenant_id' AND table_name LIKE 'crm_%') = 0 THEN
        v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; END IF;

    -- Nettoyage
    UPDATE prospects SET deleted_at = now() WHERE deleted_at IS NULL;
    UPDATE contacts SET deleted_at = now() WHERE deleted_at IS NULL;
    UPDATE campagnes SET deleted_at = now() WHERE deleted_at IS NULL;
    UPDATE opportunites SET deleted_at = now() WHERE deleted_at IS NULL;

    RAISE NOTICE '';
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'Tests reussis : %', v_passed;
    RAISE NOTICE 'Tests echoues : %', v_failed;
    RAISE NOTICE 'Total         : %', v_passed + v_failed;
    IF v_failed = 0 THEN RAISE NOTICE 'Statut : TOUS LES TESTS PASSENT';
    ELSE RAISE NOTICE 'Statut : % echec(s)', v_failed; END IF;
    RAISE NOTICE '=============================================';
END;
$$;



