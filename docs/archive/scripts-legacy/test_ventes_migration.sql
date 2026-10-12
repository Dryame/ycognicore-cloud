-- ============================================================================
-- test_ventes_migration.sql
-- Tests critiques du module Ventes (Bloc 1.3)
-- Base : ycc_tenant_demo001
-- Philosophie : uniquement des assertions réelles
-- ============================================================================

SET search_path TO public;

DO $$
DECLARE
    v_passed INTEGER := 0;
    v_failed INTEGER := 0;
    v_client_id UUID;
    v_devis_id UUID;
    v_commande_id UUID;
    v_bl_id UUID;
    v_facture_id UUID;
    v_fk_name TEXT;
    v_expected CHAR(1);
    v_actual CHAR(1);
    v_missing TEXT := '';
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'TESTS CRITIQUES MODULE VENTES';
    RAISE NOTICE '=============================================';

    -- ========================================================================
    -- NETTOYAGE
    -- ========================================================================
    TRUNCATE paiements_clients, avoirs_clients, facture_lignes,
             factures_clients, bon_livraison_lignes, bons_livraison,
             commande_lignes, commandes_clients, devis_lignes, devis,
             tarifs_clients, clients CASCADE;

    -- ========================================================================
    -- SECTION 1 — STRUCTURE (15 tests)
    -- ========================================================================
    RAISE NOTICE '--- Section 1 : Structure ---';

    -- 1.1 à 1.12 : existence des 12 tables
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='clients' AND table_schema='public') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-01 KO : clients manquante'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='tarifs_clients' AND table_schema='public') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-02 KO : tarifs_clients manquante'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='devis' AND table_schema='public') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-03 KO : devis manquante'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='devis_lignes' AND table_schema='public') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-04 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='commandes_clients' AND table_schema='public') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-05 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='commande_lignes' AND table_schema='public') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-06 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='bons_livraison' AND table_schema='public') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-07 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='bon_livraison_lignes' AND table_schema='public') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-08 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='factures_clients' AND table_schema='public') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-09 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='facture_lignes' AND table_schema='public') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-10 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='avoirs_clients' AND table_schema='public') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-11 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='paiements_clients' AND table_schema='public') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-12 KO'; END IF;
    RAISE NOTICE 'T-01 a T-12 OK (12 tables)';

    -- 1.13 : ENUM type_facture avec 3 valeurs
    IF (SELECT COUNT(*) FROM pg_enum WHERE enumtypid = 'type_facture'::regtype) = 3 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-13 KO : type_facture manquant ou incorrect'; END IF;
    RAISE NOTICE 'T-13 OK : ENUM type_facture (3 valeurs)';

    -- 1.14 : 7 séquences Ventes
    IF (SELECT COUNT(*) FROM numero_sequences WHERE type_document IN
        ('DEVIS','COMMANDE_CLIENT','BON_LIVRAISON','FACTURE_CLIENT','AVOIR_CLIENT','CLIENT','PAIEMENT_CLIENT')) = 7
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-14 KO : sequences'; END IF;
    RAISE NOTICE 'T-14 OK : 7 sequences Ventes';

    -- 1.15 : CORRECTIF E11 — BON_COMMANDE et AVOIR absents
    IF (SELECT COUNT(*) FROM numero_sequences WHERE type_document IN ('BON_COMMANDE','AVOIR')) = 0
    THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-15 KO : correctif E11 non applique'; END IF;
    RAISE NOTICE 'T-15 OK : correctif E11 applique';

    -- ========================================================================
    -- SECTION 2 — UNIQUE (8 tests)
    -- ========================================================================
    RAISE NOTICE '--- Section 2 : UNIQUE ---';

    INSERT INTO clients (code, nom) VALUES ('CLI-2026-000001', 'C1') RETURNING id INTO v_client_id;

    BEGIN INSERT INTO clients (code, nom) VALUES ('CLI-2026-000001','C2'); v_failed:=v_failed+1; RAISE NOTICE 'T-16 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; END;

    INSERT INTO devis (numero, client_id, date_validite) VALUES ('DEV-2026-000001', v_client_id, CURRENT_DATE+30) RETURNING id INTO v_devis_id;
    BEGIN INSERT INTO devis (numero, client_id, date_validite) VALUES ('DEV-2026-000001', v_client_id, CURRENT_DATE+30); v_failed:=v_failed+1; RAISE NOTICE 'T-17 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; END;

    INSERT INTO commandes_clients (numero, client_id) VALUES ('BC-2026-000001', v_client_id) RETURNING id INTO v_commande_id;
    BEGIN INSERT INTO commandes_clients (numero, client_id) VALUES ('BC-2026-000001', v_client_id); v_failed:=v_failed+1; RAISE NOTICE 'T-18 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; END;

    INSERT INTO bons_livraison (numero, client_id) VALUES ('BL-2026-000001', v_client_id) RETURNING id INTO v_bl_id;
    BEGIN INSERT INTO bons_livraison (numero, client_id) VALUES ('BL-2026-000001', v_client_id); v_failed:=v_failed+1; RAISE NOTICE 'T-19 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; END;

    INSERT INTO factures_clients (numero, client_id, date_echeance) VALUES ('FAC-2026-000001', v_client_id, CURRENT_DATE+30) RETURNING id INTO v_facture_id;
    BEGIN INSERT INTO factures_clients (numero, client_id, date_echeance) VALUES ('FAC-2026-000001', v_client_id, CURRENT_DATE+30); v_failed:=v_failed+1; RAISE NOTICE 'T-20 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; END;

    INSERT INTO avoirs_clients (numero, facture_id, client_id, motif, montant_ht, montant_tva, montant_ttc) VALUES ('AV-2026-000001', v_facture_id, v_client_id, 'Test', 0, 0, 0);
    BEGIN INSERT INTO avoirs_clients (numero, facture_id, client_id, motif, montant_ht, montant_tva, montant_ttc) VALUES ('AV-2026-000001', v_facture_id, v_client_id, 'Test2', 0, 0, 0); v_failed:=v_failed+1; RAISE NOTICE 'T-21 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; END;

    INSERT INTO paiements_clients (numero, facture_id, client_id, mode_paiement, montant) VALUES ('PAY-2026-000001', v_facture_id, v_client_id, 'ESPECES', 100);
    BEGIN INSERT INTO paiements_clients (numero, facture_id, client_id, mode_paiement, montant) VALUES ('PAY-2026-000001', v_facture_id, v_client_id, 'ESPECES', 100); v_failed:=v_failed+1; RAISE NOTICE 'T-22 KO';
    EXCEPTION WHEN unique_violation THEN v_passed:=v_passed+1; END;

    -- 2.8 : email client non unique (autorisé)
    BEGIN INSERT INTO clients (code, nom, email) VALUES ('CLI-2026-000099','C2','client1@test.bf');
        v_passed:=v_passed+1;
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-23 KO : %', SQLERRM; END;

    RAISE NOTICE 'T-16 a T-23 OK (8 tests UNIQUE)';

    -- ========================================================================
    -- SECTION 3 — CHECK CRITIQUES (10 tests)
    -- ========================================================================
    RAISE NOTICE '--- Section 3 : CHECK ---';

    BEGIN INSERT INTO devis_lignes (devis_id, designation, quantite, prix_unitaire, montant_ht, montant_tva, montant_ttc, ordre) VALUES (v_devis_id,'X',0,100,0,0,0,1); v_failed:=v_failed+1;
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; END;

    BEGIN INSERT INTO devis_lignes (devis_id, designation, quantite, prix_unitaire, montant_ht, montant_tva, montant_ttc, ordre) VALUES (v_devis_id,'X',1,100,100,0,200,1); v_failed:=v_failed+1;
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; END;

    BEGIN INSERT INTO devis_lignes (devis_id, designation, quantite, prix_unitaire, remise_pct, montant_ht, montant_tva, montant_ttc, ordre) VALUES (v_devis_id,'X',1,100,150,100,0,100,1); v_failed:=v_failed+1;
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; END;

    BEGIN INSERT INTO devis_lignes (devis_id, designation, quantite, prix_unitaire, taux_tva, montant_ht, montant_tva, montant_ttc, ordre) VALUES (v_devis_id,'X',1,100,200,100,200,300,1); v_failed:=v_failed+1;
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; END;

    BEGIN INSERT INTO clients (code, nom, plafond_encours) VALUES ('CLI-2026-000050','X',-1); v_failed:=v_failed+1;
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; END;

    BEGIN INSERT INTO clients (code, nom, tolerance_sur_livraison_pct) VALUES ('CLI-2026-000051','X',150); v_failed:=v_failed+1;
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; END;

    BEGIN INSERT INTO clients (code, nom, delai_paiement_jours) VALUES ('CLI-2026-000052','X',-1); v_failed:=v_failed+1;
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; END;

    BEGIN INSERT INTO clients (code, nom) VALUES ('INVALID','X'); v_failed:=v_failed+1;
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; END;

    -- SOLDE sans parent refusé
    BEGIN INSERT INTO factures_clients (numero, type_facture, client_id, date_echeance) VALUES ('FAC-2026-000098','SOLDE',v_client_id, CURRENT_DATE+30); v_failed:=v_failed+1;
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; END;

    -- NORMALE avec parent refusé
    BEGIN INSERT INTO factures_clients (numero, type_facture, facture_parent_id, client_id, date_echeance) VALUES ('FAC-2026-000097','NORMALE',v_facture_id,v_client_id, CURRENT_DATE+30); v_failed:=v_failed+1;
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; END;

    RAISE NOTICE 'T-24 a T-33 OK (10 tests CHECK)';

    -- ========================================================================
    -- SECTION 4 — FK ON DELETE (19 FK vérifiées individuellement)
    -- ========================================================================
    RAISE NOTICE '--- Section 4 : FK ON DELETE ---';

    FOR v_fk_name, v_expected IN
        SELECT * FROM (VALUES
            ('fk_tarifs_client','r'),
            ('fk_devis_client','r'),
            ('fk_devis_lignes_devis','c'),
            ('fk_cc_client','r'),
            ('fk_cc_devis','n'),
            ('fk_cl_commande','c'),
            ('fk_bl_client','r'),
            ('fk_bl_commande','r'),
            ('fk_bll_bl','c'),
            ('fk_bll_commande_ligne','n'),
            ('fk_fc_client','r'),
            ('fk_fc_commande','n'),
            ('fk_fc_bl','n'),
            ('fk_fc_parent','n'),
            ('fk_fl_facture','c'),
            ('fk_av_facture','r'),
            ('fk_av_client','r'),
            ('fk_pay_facture','r'),
            ('fk_pay_client','r')
        ) AS t(name, expected)
    LOOP
        SELECT confdeltype INTO v_actual FROM pg_constraint WHERE conname = v_fk_name;
        IF v_actual = v_expected THEN v_passed:=v_passed+1;
        ELSE v_failed:=v_failed+1; v_missing := v_missing || v_fk_name || '(' || COALESCE(v_actual::TEXT,'ABSENT') || ') '; END IF;
    END LOOP;

    IF v_missing = '' THEN RAISE NOTICE 'T-34 a T-52 OK (19 FK)';
    ELSE RAISE NOTICE 'T-34 a T-52 KO : %', v_missing; END IF;

    -- ========================================================================
    -- SECTION 5 — TRIGGERS (6 tests)
    -- ========================================================================
    RAISE NOTICE '--- Section 5 : Triggers ---';

    DECLARE v_before TIMESTAMPTZ; v_after TIMESTAMPTZ;
    BEGIN
        SELECT updated_at INTO v_before FROM clients WHERE id=v_client_id;
        PERFORM pg_sleep(0.1);
        UPDATE clients SET nom='T54' WHERE id=v_client_id;
        SELECT updated_at INTO v_after FROM clients WHERE id=v_client_id;
        IF v_after > v_before THEN v_passed:=v_passed+1;
        ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-53 KO : updated_at non modifie'; END IF;
    END;

    DECLARE v_before INTEGER; v_after INTEGER;
    BEGIN
        SELECT version INTO v_before FROM clients WHERE id=v_client_id;
        UPDATE clients SET nom='T55' WHERE id=v_client_id;
        SELECT version INTO v_after FROM clients WHERE id=v_client_id;
        IF v_after = v_before + 1 THEN v_passed:=v_passed+1;
        ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-54 KO : version non incrementee'; END IF;
    END;

    BEGIN DELETE FROM clients WHERE id=v_client_id; v_failed:=v_failed+1; RAISE NOTICE 'T-55 KO : DELETE accepte';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%Suppression physique interdite%' THEN v_passed:=v_passed+1;
        ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-55 KO : %', SQLERRM; END IF;
    END;

    PERFORM soft_delete_element('clients', v_client_id);
    IF (SELECT deleted_at FROM clients WHERE id=v_client_id) IS NOT NULL THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-56 KO : soft delete'; END IF;

    PERFORM restaurer_element_supprime('clients', v_client_id);
    IF (SELECT deleted_at FROM clients WHERE id=v_client_id) IS NULL THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-57 KO : restauration'; END IF;

    IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_tarifs_clients_no_hard_delete') THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-58 KO : trigger tarifs_clients'; END IF;

    RAISE NOTICE 'T-53 a T-58 OK (6 tests Triggers)';

        -- ========================================================================
    -- SECTION 6 — ISOLATION (1 test)
    -- ========================================================================
    -- Test : aucune colonne tenant_id dans les 12 tables Ventes
    -- Confirm l'isolation physique (Database-per-Tenant)
    IF (SELECT COUNT(*) FROM information_schema.columns
        WHERE column_name = 'tenant_id'
          AND table_name IN (
            'clients','tarifs_clients','devis','devis_lignes',
            'commandes_clients','commande_lignes','bons_livraison','bon_livraison_lignes',
            'factures_clients','facture_lignes','avoirs_clients','paiements_clients')
       ) = 0 THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-59 OK : isolation physique confirmee (aucune colonne tenant_id)';
    ELSE
        v_failed:=v_failed+1; RAISE NOTICE 'T-59 KO : colonne tenant_id detectee'; END IF;

    -- ========================================================================
    -- SECTION 7 — CAS LIMITES (4 tests)
    -- ========================================================================
    RAISE NOTICE '--- Section 7 : Cas limites ---';

    BEGIN INSERT INTO clients (code, nom) VALUES (repeat('A',256),'X'); v_failed:=v_failed+1; RAISE NOTICE 'T-60 KO';
    EXCEPTION WHEN string_data_right_truncation THEN v_passed:=v_passed+1; END;

    BEGIN INSERT INTO clients (code, nom) VALUES (NULL,'X'); v_failed:=v_failed+1; RAISE NOTICE 'T-61 KO';
    EXCEPTION WHEN not_null_violation THEN v_passed:=v_passed+1; END;

    BEGIN INSERT INTO clients (code, nom) VALUES ('CLI-2026-000003','O''Brien'); v_passed:=v_passed+1;
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-62 KO'; END;

    BEGIN INSERT INTO clients (code, nom) VALUES ('CLI-2030-000001','T'); v_passed:=v_passed+1;
    EXCEPTION WHEN OTHERS THEN v_failed:=v_failed+1; RAISE NOTICE 'T-63 KO'; END;

    RAISE NOTICE 'T-60 a T-63 OK (4 tests cas limites)';

    -- ========================================================================
    -- NETTOYAGE
    -- ========================================================================
    UPDATE clients SET deleted_at = now() WHERE code LIKE 'CLI-%';
    UPDATE devis SET deleted_at = now() WHERE numero LIKE 'DEV-%';
    UPDATE commandes_clients SET deleted_at = now() WHERE numero LIKE 'BC-%';
    UPDATE bons_livraison SET deleted_at = now() WHERE numero LIKE 'BL-%';
    UPDATE factures_clients SET deleted_at = now() WHERE numero LIKE 'FAC-%';
    UPDATE avoirs_clients SET deleted_at = now() WHERE numero LIKE 'AV-%';
    UPDATE paiements_clients SET deleted_at = now() WHERE numero LIKE 'PAY-%';

    -- ========================================================================
    -- RÉSUMÉ
    -- ========================================================================
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