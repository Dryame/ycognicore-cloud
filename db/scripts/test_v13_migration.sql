-- ============================================================================
-- test_v13_migration.sql
-- Tests du bloc V13 — Ventes (13 tables)
-- ============================================================================

SET search_path TO public;

DO $$
DECLARE
    v_passed INTEGER := 0;
    v_failed INTEGER := 0;
    v_tiers_id UUID;
    v_article_id UUID;
    v_doc_devis_id UUID;
    v_doc_commande_id UUID;
    v_doc_facture_id UUID;
    v_paiement_id UUID;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'TESTS BLOC V13 — VENTES';
    RAISE NOTICE '=============================================';

    -- Nettoyage (préserver les seeds sequences)
    DELETE FROM paiements_allocations;
    DELETE FROM paiements;
    DELETE FROM relances_factures;
    DELETE FROM validations_documents;
    DELETE FROM circuits_validation;
    DELETE FROM promotions;
    DELETE FROM lignes_tarif;
    DELETE FROM listes_prix;
    DELETE FROM documents_vente_liens;
    DELETE FROM documents_vente_historique_statuts;
    DELETE FROM documents_vente_lignes;
    DELETE FROM documents_vente;

    -- Récupérer Tiers + Article
    SELECT id INTO v_tiers_id FROM tiers WHERE code='TIE-2026-000001' LIMIT 1;
    SELECT id INTO v_article_id FROM articles LIMIT 1;

    -- ========================================================================
    -- STRUCTURE (13 tests)
    -- ========================================================================
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='sequences_documents') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-01 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='documents_vente') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-02 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='documents_vente_lignes') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-03 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='documents_vente_liens') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-04 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='documents_vente_historique_statuts') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-05 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='listes_prix') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-06 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='lignes_tarif') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-07 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='promotions') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-08 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='circuits_validation') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-09 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='validations_documents') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-10 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='paiements') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-11 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='paiements_allocations') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-12 KO'; END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='relances_factures') THEN v_passed:=v_passed+1; ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-13 KO'; END IF;
    RAISE NOTICE 'T-01 a T-13 OK : 13 tables existent';

    -- ========================================================================
    -- SEEDS SEQUENCES
    -- ========================================================================
    IF (SELECT COUNT(*) FROM sequences_documents) >= 6 THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-14 OK : % sequences', (SELECT COUNT(*) FROM sequences_documents);
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-14 KO'; END IF;

    -- ========================================================================
    -- INSERER DEVIS + CONVERSION
    -- ========================================================================
    BEGIN
        INSERT INTO documents_vente (type_document, numero, tiers_id, date_validite,
            total_ht, total_tva, total_ttc)
        VALUES ('DEVIS', prochain_numero_document('DEVIS', EXTRACT(YEAR FROM CURRENT_DATE)::INT),
            v_tiers_id, CURRENT_DATE + 30, 100000, 18000, 118000)
        RETURNING id INTO v_doc_devis_id;
        v_passed:=v_passed+1; RAISE NOTICE 'T-15 OK : devis cree';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-15 KO : %', SQLERRM;
    END;

    BEGIN
        INSERT INTO documents_vente_lignes (document_id, article_id, designation,
            quantite, prix_unitaire, montant_ht, montant_tva, montant_ttc)
        VALUES (v_doc_devis_id, v_article_id, 'Article test', 10, 10000, 100000, 18000, 118000);
        v_passed:=v_passed+1; RAISE NOTICE 'T-16 OK : ligne devis';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-16 KO : %', SQLERRM;
    END;

    -- Convertir en commande
    BEGIN
        INSERT INTO documents_vente (type_document, numero, tiers_id,
            total_ht, total_tva, total_ttc)
        VALUES ('COMMANDE', prochain_numero_document('COMMANDE', EXTRACT(YEAR FROM CURRENT_DATE)::INT),
            v_tiers_id, 100000, 18000, 118000)
        RETURNING id INTO v_doc_commande_id;
        INSERT INTO documents_vente_liens (document_source_id, document_cible_id, type_lien)
        VALUES (v_doc_devis_id, v_doc_commande_id, 'CONVERSION');
        v_passed:=v_passed+1; RAISE NOTICE 'T-17 OK : devis converti en commande';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-17 KO : %', SQLERRM;
    END;

    -- ========================================================================
    -- HISTORIQUE AUTOMATIQUE
    -- ========================================================================
    UPDATE documents_vente SET statut='ENVOYE' WHERE id=v_doc_devis_id;
    UPDATE documents_vente SET statut='ACCEPTE' WHERE id=v_doc_devis_id;

    IF (SELECT COUNT(*) FROM documents_vente_historique_statuts WHERE document_id=v_doc_devis_id) >= 2 THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-18 OK : historique automatique (% entrees)',
            (SELECT COUNT(*) FROM documents_vente_historique_statuts WHERE document_id=v_doc_devis_id);
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-18 KO'; END IF;

    -- ========================================================================
    -- CHECK
    -- ========================================================================
    BEGIN
        INSERT INTO documents_vente (type_document, numero, tiers_id, total_ht, total_tva, total_ttc)
        VALUES ('INVALIDE','X',v_tiers_id,0,0,0);
        v_failed:=v_failed+1; RAISE NOTICE 'T-19 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-19 OK : type invalide'; END;

    BEGIN
        INSERT INTO documents_vente_lignes (document_id, designation, quantite, prix_unitaire, montant_ht, montant_tva, montant_ttc)
        VALUES (v_doc_devis_id, 'X', 0, 100, 0, 0, 0);
        v_failed:=v_failed+1; RAISE NOTICE 'T-20 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-20 OK : quantite 0'; END;

    BEGIN
        INSERT INTO documents_vente_lignes (document_id, designation, quantite, prix_unitaire, montant_ht, montant_tva, montant_ttc)
        VALUES (v_doc_devis_id, 'X', 1, 100, 100, 0, 200);
        v_failed:=v_failed+1; RAISE NOTICE 'T-21 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-21 OK : totaux incoherents'; END;

    -- ========================================================================
    -- PAIEMENTS + ALLOCATIONS
    -- ========================================================================
    INSERT INTO documents_vente (type_document, numero, tiers_id, statut, total_ht, total_tva, total_ttc)
    VALUES ('FACTURE', prochain_numero_document('FACTURE', EXTRACT(YEAR FROM CURRENT_DATE)::INT),
        v_tiers_id, 'EMISE', 100000, 18000, 118000)
    RETURNING id INTO v_doc_facture_id;
    v_passed:=v_passed+1; RAISE NOTICE 'T-22 OK : facture creee';

    BEGIN
        INSERT INTO paiements (numero, tiers_id, mode_paiement, montant)
        VALUES ('PAY-001', v_tiers_id, 'VIREMENT', 118000) RETURNING id INTO v_paiement_id;
        v_passed:=v_passed+1; RAISE NOTICE 'T-23 OK : paiement cree';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-23 KO : %', SQLERRM;
    END;

    BEGIN
        INSERT INTO paiements_allocations (paiement_id, document_id, montant_alloue)
        VALUES (v_paiement_id, v_doc_facture_id, 118000);
        v_passed:=v_passed+1; RAISE NOTICE 'T-24 OK : allocation paiement';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-24 KO : %', SQLERRM;
    END;

    -- Montant négatif refusé
    BEGIN
        INSERT INTO paiements (numero, tiers_id, mode_paiement, montant)
        VALUES ('PAY-002', v_tiers_id, 'ESPECES', -100);
        v_failed:=v_failed+1; RAISE NOTICE 'T-25 KO';
    EXCEPTION WHEN check_violation THEN v_passed:=v_passed+1; RAISE NOTICE 'T-25 OK : montant negatif'; END;

    -- ========================================================================
    -- APPEND-ONLY HISTORIQUE
    -- ========================================================================
    BEGIN
        UPDATE documents_vente_historique_statuts SET commentaire='X' WHERE document_id=v_doc_devis_id;
        v_failed:=v_failed+1; RAISE NOTICE 'T-26 KO';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%append-only%' THEN v_passed:=v_passed+1; RAISE NOTICE 'T-26 OK : append-only';
        ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-26 KO : %', SQLERRM; END IF;
    END;

    -- ========================================================================
    -- TRIGGERS UPDATE
    -- ========================================================================
    DECLARE
        v_before TIMESTAMPTZ; v_after TIMESTAMPTZ;
    BEGIN
        SELECT updated_at INTO v_before FROM documents_vente WHERE id=v_doc_devis_id;
        PERFORM pg_sleep(0.1);
        UPDATE documents_vente SET notes='test' WHERE id=v_doc_devis_id;
        SELECT updated_at INTO v_after FROM documents_vente WHERE id=v_doc_devis_id;
        IF v_after > v_before THEN v_passed:=v_passed+1; RAISE NOTICE 'T-27 OK : updated_at';
        ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-27 KO'; END IF;
    END;

    BEGIN
        DELETE FROM documents_vente WHERE id=v_doc_devis_id;
        v_failed:=v_failed+1; RAISE NOTICE 'T-28 KO';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%Suppression physique interdite%' THEN v_passed:=v_passed+1; RAISE NOTICE 'T-28 OK : DELETE bloque';
        ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-28 KO'; END IF;
    END;

    -- ========================================================================
    -- ISOLATION
    -- ========================================================================
    IF (SELECT COUNT(*) FROM information_schema.columns
        WHERE column_name='tenant_id' AND table_name LIKE 'documents_vente%') = 0 THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-29 OK : pas de tenant_id';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-29 KO'; END IF;

    -- Nettoyage
    UPDATE documents_vente SET deleted_at = now() WHERE deleted_at IS NULL;
    UPDATE paiements SET deleted_at = now() WHERE deleted_at IS NULL;
    UPDATE listes_prix SET deleted_at = now() WHERE deleted_at IS NULL;
    UPDATE promotions SET deleted_at = now() WHERE deleted_at IS NULL;
    UPDATE circuits_validation SET deleted_at = now() WHERE deleted_at IS NULL;

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
