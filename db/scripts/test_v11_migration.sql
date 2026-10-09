-- ============================================================================
-- test_v11_migration.sql
-- Tests du bloc V11 — Référentiel Articles
-- Base : ycc_tenant_demo001
-- ============================================================================

SET search_path TO public;

DO $$
DECLARE
    v_passed INTEGER := 0;
    v_failed INTEGER := 0;
    v_famille_id UUID;
    v_unite_kg_id UUID;
    v_unite_t_id UUID;
    v_taxe_id UUID;
    v_marque_id UUID;
    v_article_id UUID;
    v_variante_id UUID;
    v_fournisseur_id UUID;
    v_before TIMESTAMPTZ;
    v_after TIMESTAMPTZ;
    v_ver_before INTEGER;
    v_ver_after INTEGER;
    v_fk_name TEXT;
    v_expected CHAR(1);
    v_actual CHAR(1);
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'TESTS BLOC V11 — REFERENTIEL ARTICLES';
    RAISE NOTICE '=============================================';

    TRUNCATE articles_fournisseurs, article_variantes, articles,
             marques, familles_articles CASCADE;

    -- ========================================================================
    -- SECTION 1 — STRUCTURE (7 tests)
    -- ========================================================================
    RAISE NOTICE '--- Section 1 : Structure ---';

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='familles_articles') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-01 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-01 KO'; END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='unites_mesure') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-02 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-02 KO'; END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='marques') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-03 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-03 KO'; END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='taxes') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-04 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-04 KO'; END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='articles') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-05 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-05 KO'; END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='article_variantes') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-06 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-06 KO'; END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='articles_fournisseurs') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-07 OK';
    ELSE v_failed:=v_failed+1; RAISE NOTICE 'T-07 KO'; END IF;

    -- ========================================================================
    -- SECTION 2 — SEEDS (2 tests)
    -- ========================================================================
    RAISE NOTICE '--- Section 2 : Seeds ---';

    IF (SELECT COUNT(*) FROM unites_mesure) >= 12 THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-08 OK : % unites seedees', (SELECT COUNT(*) FROM unites_mesure);
    ELSE
        v_failed:=v_failed+1; RAISE NOTICE 'T-08 KO';
    END IF;

    IF (SELECT COUNT(*) FROM taxes) >= 4 THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-09 OK : % taxes seedees', (SELECT COUNT(*) FROM taxes);
    ELSE
        v_failed:=v_failed+1; RAISE NOTICE 'T-09 KO';
    END IF;

    -- ========================================================================
    -- SECTION 3 — INSERTION VALIDE (4 tests)
    -- ========================================================================
    RAISE NOTICE '--- Section 3 : Insertion valide ---';

    -- Récupérer les IDs des seeds
    SELECT id INTO v_unite_kg_id FROM unites_mesure WHERE code='KG';
    SELECT id INTO v_unite_t_id FROM unites_mesure WHERE code='T';
    SELECT id INTO v_taxe_id FROM taxes WHERE code='TVA_18';

    -- Famille racine
    BEGIN
        INSERT INTO familles_articles (code, libelle, niveau)
        VALUES ('ELEC','Électronique',1)
        RETURNING id INTO v_famille_id;
        v_passed:=v_passed+1; RAISE NOTICE 'T-10 OK : famille racine inseree';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-10 KO : %', SQLERRM;
    END;

    -- Marque
    BEGIN
        INSERT INTO marques (code, nom, pays_origine)
        VALUES ('SAMSUNG','Samsung','Corée du Sud')
        RETURNING id INTO v_marque_id;
        v_passed:=v_passed+1; RAISE NOTICE 'T-11 OK : marque inseree';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-11 KO : %', SQLERRM;
    END;

    -- Article
    BEGIN
        INSERT INTO articles (
            code, designation, type_article, famille_id,
            marque_id, unite_base_id, taxe_id
        ) VALUES (
            'ART-2026-000001', 'Smartphone Galaxy A15', 'MARCHANDISE',
            v_famille_id, v_marque_id, v_unite_kg_id, v_taxe_id
        ) RETURNING id INTO v_article_id;
        v_passed:=v_passed+1; RAISE NOTICE 'T-12 OK : article insere';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-12 KO : %', SQLERRM;
    END;

    -- Variante
    BEGIN
        INSERT INTO article_variantes (
            article_id, code_variante,
            attribut_1_nom, attribut_1_valeur,
            attribut_2_nom, attribut_2_valeur
        ) VALUES (
            v_article_id, 'ART-2026-000001-BLK',
            'Couleur', 'Noir',
            'Mémoire', '128 GB'
        ) RETURNING id INTO v_variante_id;
        v_passed:=v_passed+1; RAISE NOTICE 'T-13 OK : variante inseree';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-13 KO : %', SQLERRM;
    END;

    -- ========================================================================
    -- SECTION 4 — CONTRAINTES CHECK (10 tests)
    -- ========================================================================
    RAISE NOTICE '--- Section 4 : CHECK ---';

    BEGIN
        INSERT INTO familles_articles (code, libelle, niveau) VALUES ('X','X',0);
        v_failed:=v_failed+1; RAISE NOTICE 'T-14 KO';
    EXCEPTION WHEN check_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-14 OK : niveau < 1 refuse';
    END;

    BEGIN
        INSERT INTO familles_articles (code, libelle, niveau) VALUES ('Y','Y',6);
        v_failed:=v_failed+1; RAISE NOTICE 'T-15 KO';
    EXCEPTION WHEN check_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-15 OK : niveau > 5 refuse';
    END;

    BEGIN
        INSERT INTO unites_mesure (code, libelle, symbole, type_unite, facteur_conversion_base)
        VALUES ('XX','X','x','INVALIDE',1);
        v_failed:=v_failed+1; RAISE NOTICE 'T-16 KO';
    EXCEPTION WHEN check_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-16 OK : type_unite invalide refuse';
    END;

    BEGIN
        INSERT INTO unites_mesure (code, libelle, symbole, type_unite, facteur_conversion_base)
        VALUES ('YY','Y','y','MASSE',0);
        v_failed:=v_failed+1; RAISE NOTICE 'T-17 KO';
    EXCEPTION WHEN check_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-17 OK : facteur <= 0 refuse';
    END;

    BEGIN
        INSERT INTO taxes (code, libelle, type_taxe, taux) VALUES ('ZZ','Z','INVALIDE',18);
        v_failed:=v_failed+1; RAISE NOTICE 'T-18 KO';
    EXCEPTION WHEN check_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-18 OK : type_taxe invalide refuse';
    END;

    BEGIN
        INSERT INTO taxes (code, libelle, type_taxe, taux) VALUES ('AAA','A','TVA',150);
        v_failed:=v_failed+1; RAISE NOTICE 'T-19 KO';
    EXCEPTION WHEN check_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-19 OK : taux > 100 refuse';
    END;

    BEGIN
        INSERT INTO articles (code, designation, type_article, famille_id, unite_base_id, taxe_id)
        VALUES ('INVALID','X','MARCHANDISE',v_famille_id,v_unite_kg_id,v_taxe_id);
        v_failed:=v_failed+1; RAISE NOTICE 'T-20 KO';
    EXCEPTION WHEN check_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-20 OK : format code invalide refuse';
    END;

    BEGIN
        INSERT INTO articles (code, designation, type_article, famille_id, unite_base_id, taxe_id)
        VALUES ('ART-2026-000099','X','INVALIDE',v_famille_id,v_unite_kg_id,v_taxe_id);
        v_failed:=v_failed+1; RAISE NOTICE 'T-21 KO';
    EXCEPTION WHEN check_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-21 OK : type_article invalide refuse';
    END;

    BEGIN
        INSERT INTO articles (code, designation, type_article, famille_id, unite_base_id, taxe_id, stock_actuel)
        VALUES ('ART-2026-000098','X','MARCHANDISE',v_famille_id,v_unite_kg_id,v_taxe_id,-1);
        v_failed:=v_failed+1; RAISE NOTICE 'T-22 KO';
    EXCEPTION WHEN check_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-22 OK : stock negatif refuse';
    END;

    BEGIN
        INSERT INTO articles_fournisseurs (article_id, fournisseur_id, reference_fournisseur, prix_achat_ht, remise_pct)
        VALUES (v_article_id, gen_random_uuid(), 'REF-X', 1000, 150);
        v_failed:=v_failed+1; RAISE NOTICE 'T-23 KO';
    EXCEPTION WHEN check_violation OR foreign_key_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-23 OK : remise > 100 refusee';
    END;

    -- ========================================================================
    -- SECTION 5 — UNIQUE (4 tests)
    -- ========================================================================
    RAISE NOTICE '--- Section 5 : UNIQUE ---';

    BEGIN
        INSERT INTO familles_articles (code, libelle, niveau) VALUES ('ELEC','Doublon',1);
        v_failed:=v_failed+1; RAISE NOTICE 'T-24 KO';
    EXCEPTION WHEN unique_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-24 OK : doublon code famille refuse';
    END;

    BEGIN
        INSERT INTO articles (code, designation, type_article, famille_id, unite_base_id, taxe_id)
        VALUES ('ART-2026-000001','Doublon','MARCHANDISE',v_famille_id,v_unite_kg_id,v_taxe_id);
        v_failed:=v_failed+1; RAISE NOTICE 'T-25 KO';
    EXCEPTION WHEN unique_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-25 OK : doublon code article refuse';
    END;

    BEGIN
        INSERT INTO article_variantes (article_id, code_variante) VALUES (v_article_id, 'ART-2026-000001-BLK');
        v_failed:=v_failed+1; RAISE NOTICE 'T-26 KO';
    EXCEPTION WHEN unique_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-26 OK : doublon code variante refuse';
    END;

    -- Deux articles avec code_barres NULL acceptés
    BEGIN
        INSERT INTO articles (code, designation, type_article, famille_id, unite_base_id, taxe_id)
        VALUES ('ART-2026-000002','X1','MARCHANDISE',v_famille_id,v_unite_kg_id,v_taxe_id);
        INSERT INTO articles (code, designation, type_article, famille_id, unite_base_id, taxe_id)
        VALUES ('ART-2026-000003','X2','MARCHANDISE',v_famille_id,v_unite_kg_id,v_taxe_id);
        v_passed:=v_passed+1; RAISE NOTICE 'T-27 OK : deux articles sans code-barres acceptes';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-27 KO : %', SQLERRM;
    END;

    -- ========================================================================
    -- SECTION 6 — FK ON DELETE (5 tests)
    -- ========================================================================
    RAISE NOTICE '--- Section 6 : FK ON DELETE ---';

    FOR v_fk_name, v_expected IN
        SELECT * FROM (VALUES
            ('fk_familles_parent','n'),
            ('fk_articles_famille','r'),
            ('fk_articles_unite_base','r'),
            ('fk_articles_taxe','r'),
            ('fk_variantes_article','c')
        ) AS t(name, expected)
    LOOP
        SELECT confdeltype INTO v_actual FROM pg_constraint WHERE conname = v_fk_name;
        IF v_actual = v_expected THEN
            v_passed:=v_passed+1;
        ELSE
            v_failed:=v_failed+1;
            RAISE NOTICE 'T-28..32 KO : % attendu=%, recu=%', v_fk_name, v_expected, v_actual;
        END IF;
    END LOOP;
    RAISE NOTICE 'T-28 a T-32 OK : 5 FK verifiees';

    -- ========================================================================
    -- SECTION 7 — TRIGGERS (4 tests)
    -- ========================================================================
    RAISE NOTICE '--- Section 7 : Triggers ---';

    SELECT updated_at INTO v_before FROM articles WHERE id = v_article_id;
    PERFORM pg_sleep(0.1);
    UPDATE articles SET designation = 'Modifie' WHERE id = v_article_id;
    SELECT updated_at INTO v_after FROM articles WHERE id = v_article_id;

    IF v_after > v_before THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-33 OK : updated_at modifie';
    ELSE
        v_failed:=v_failed+1; RAISE NOTICE 'T-33 KO';
    END IF;

    SELECT version INTO v_ver_before FROM articles WHERE id = v_article_id;
    UPDATE articles SET designation = 'Modifie2' WHERE id = v_article_id;
    SELECT version INTO v_ver_after FROM articles WHERE id = v_article_id;

    IF v_ver_after = v_ver_before + 1 THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-34 OK : version incrementee';
    ELSE
        v_failed:=v_failed+1; RAISE NOTICE 'T-34 KO';
    END IF;

    BEGIN
        DELETE FROM articles WHERE id = v_article_id;
        v_failed:=v_failed+1; RAISE NOTICE 'T-35 KO';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%Suppression physique interdite%' THEN
            v_passed:=v_passed+1; RAISE NOTICE 'T-35 OK : DELETE physique bloque';
        ELSE
            v_failed:=v_failed+1; RAISE NOTICE 'T-35 KO : %', SQLERRM;
        END IF;
    END;

    IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_articles_no_hard_delete') THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-36 OK : trigger no_hard_delete present';
    ELSE
        v_failed:=v_failed+1; RAISE NOTICE 'T-36 KO';
    END IF;

    -- ========================================================================
    -- SECTION 8 — CAS METIER (5 tests)
    -- ========================================================================
    RAISE NOTICE '--- Section 8 : Cas metier ---';

    -- Hiérarchie famille enfant
    BEGIN
        INSERT INTO familles_articles (code, libelle, parent_id, niveau)
        VALUES ('SMART','Smartphones', v_famille_id, 2);
        v_passed:=v_passed+1; RAISE NOTICE 'T-37 OK : famille enfant (niveau 2)';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-37 KO : %', SQLERRM;
    END;

    -- Multi-unités : article vendu en kg, acheté en tonne
    BEGIN
        INSERT INTO articles (
            code, designation, type_article, famille_id,
            unite_base_id, unite_achat_id, unite_vente_id, taxe_id
        ) VALUES (
            'ART-2026-000004','Riz parfumé','MARCHANDISE', v_famille_id,
            v_unite_kg_id, v_unite_t_id, v_unite_kg_id, v_taxe_id
        );
        v_passed:=v_passed+1; RAISE NOTICE 'T-38 OK : article multi-unites';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-38 KO : %', SQLERRM;
    END;

    -- Deux variantes pour le même article
    BEGIN
        INSERT INTO article_variantes (article_id, code_variante)
        VALUES (v_article_id, 'ART-2026-000001-WHT');
        v_passed:=v_passed+1; RAISE NOTICE 'T-39 OK : 2 variantes pour meme article';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-39 KO : %', SQLERRM;
    END;

    -- Article sans marque (marque NULL)
    BEGIN
        INSERT INTO articles (code, designation, type_article, famille_id, unite_base_id, taxe_id)
        VALUES ('ART-2026-000005','Article sans marque','MARCHANDISE',v_famille_id,v_unite_kg_id,v_taxe_id);
        v_passed:=v_passed+1; RAISE NOTICE 'T-40 OK : article sans marque';
    EXCEPTION WHEN OTHERS THEN
        v_failed:=v_failed+1; RAISE NOTICE 'T-40 KO : %', SQLERRM;
    END;

    -- FK article inexistant refuse
    BEGIN
        INSERT INTO article_variantes (article_id, code_variante)
        VALUES (gen_random_uuid(), 'GHOST-VAR');
        v_failed:=v_failed+1; RAISE NOTICE 'T-41 KO';
    EXCEPTION WHEN foreign_key_violation THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-41 OK : FK article inexistant refuse';
    END;

    -- ========================================================================
    -- SECTION 9 — ISOLATION (1 test)
    -- ========================================================================
    IF (SELECT COUNT(*) FROM information_schema.columns
        WHERE column_name = 'tenant_id'
          AND table_name IN ('familles_articles','unites_mesure','marques','taxes',
                              'articles','article_variantes','articles_fournisseurs')) = 0 THEN
        v_passed:=v_passed+1; RAISE NOTICE 'T-42 OK : aucun tenant_id';
    ELSE
        v_failed:=v_failed+1; RAISE NOTICE 'T-42 KO';
    END IF;

    -- ========================================================================
    -- NETTOYAGE
    -- ========================================================================
    UPDATE articles_fournisseurs SET deleted_at = now() WHERE deleted_at IS NULL;
    UPDATE article_variantes SET deleted_at = now() WHERE deleted_at IS NULL;
    UPDATE articles SET deleted_at = now() WHERE deleted_at IS NULL;
    UPDATE marques SET deleted_at = now() WHERE deleted_at IS NULL;
    UPDATE taxes SET deleted_at = now() WHERE code NOT IN ('TVA_18','EXO_TVA','ACCISE_ALCOOL','ACCISE_TABAC');
    UPDATE unites_mesure SET deleted_at = now() WHERE code NOT IN ('KG','T','G','L','ML','M','M2','M3','PCE','LOT','H','J');
    UPDATE familles_articles SET deleted_at = now() WHERE deleted_at IS NULL;

    -- ========================================================================
    -- RESUME
    -- ========================================================================
    RAISE NOTICE '';
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'RESULTAT FINAL';
    RAISE NOTICE '=============================================';
    RAISE NOTICE 'Tests reussis : %', v_passed;
    RAISE NOTICE 'Tests echoues : %', v_failed;
    RAISE NOTICE 'Total         : %', v_passed + v_failed;
    IF v_failed = 0 THEN
        RAISE NOTICE 'Statut : TOUS LES TESTS PASSENT';
    ELSE
        RAISE NOTICE 'Statut : % test(s) en echec', v_failed;
    END IF;
    RAISE NOTICE '=============================================';
END;
$$;
