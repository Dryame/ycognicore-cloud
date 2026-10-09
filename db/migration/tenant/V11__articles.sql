-- ============================================================================
-- V11__articles.sql
-- Base : ycc_tenant_<id>
-- Objet : Référentiel Articles (familles, unités, marques, taxes, articles, variantes, fournisseurs)
-- Réf.  : Design Bible Phase 2 — Bloc V11
-- ============================================================================

SET search_path TO public;

-- ============================================================================
-- SECTION 1 — TABLE familles_articles
-- ============================================================================

CREATE TABLE familles_articles (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                        VARCHAR(20) NOT NULL,
    libelle                     VARCHAR(255) NOT NULL,
    parent_id                   UUID,
    niveau                      SMALLINT NOT NULL DEFAULT 1,
    compte_comptable_stock      VARCHAR(20),
    compte_comptable_vente      VARCHAR(20),
    compte_comptable_achat      VARCHAR(20),
    actif                       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at                  TIMESTAMPTZ,
    version                     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_familles_niveau
        CHECK (niveau BETWEEN 1 AND 5),
    CONSTRAINT uq_familles_code
        UNIQUE (code),
    CONSTRAINT fk_familles_parent
        FOREIGN KEY (parent_id) REFERENCES familles_articles(id) ON DELETE SET NULL
);

CREATE INDEX idx_familles_parent
    ON familles_articles (parent_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_familles_actif
    ON familles_articles (actif) WHERE deleted_at IS NULL;

COMMENT ON TABLE familles_articles
    IS 'Familles hiérarchiques d''articles (max 5 niveaux) — V11';

-- ============================================================================
-- SECTION 2 — TABLE unites_mesure
-- ============================================================================

CREATE TABLE unites_mesure (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                        VARCHAR(10) NOT NULL,
    libelle                     VARCHAR(50) NOT NULL,
    symbole                     VARCHAR(10) NOT NULL,
    type_unite                  VARCHAR(20) NOT NULL,
    facteur_conversion_base     NUMERIC(15,6) NOT NULL DEFAULT 1,
    unite_base                  VARCHAR(10),
    est_base                    BOOLEAN NOT NULL DEFAULT FALSE,
    actif                       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at                  TIMESTAMPTZ,
    version                     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_unites_type
        CHECK (type_unite IN ('MASSE','VOLUME','LONGUEUR','SURFACE','QUANTITE','TEMPS','AUTRE')),
    CONSTRAINT chk_unites_facteur
        CHECK (facteur_conversion_base > 0),
    CONSTRAINT uq_unites_code
        UNIQUE (code)
);

CREATE INDEX idx_unites_type
    ON unites_mesure (type_unite) WHERE deleted_at IS NULL;
CREATE INDEX idx_unites_actif
    ON unites_mesure (actif) WHERE deleted_at IS NULL;

COMMENT ON TABLE unites_mesure
    IS 'Unités de mesure (kg, L, pièce, m²) — V11';

-- ============================================================================
-- SECTION 3 — TABLE marques
-- ============================================================================

CREATE TABLE marques (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                        VARCHAR(20) NOT NULL,
    nom                         VARCHAR(100) NOT NULL,
    pays_origine                VARCHAR(100),
    logo_fichier_id             UUID REFERENCES fichiers(id) ON DELETE SET NULL,
    actif                       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at                  TIMESTAMPTZ,
    version                     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT uq_marques_code
        UNIQUE (code)
);

CREATE INDEX idx_marques_actif
    ON marques (actif) WHERE deleted_at IS NULL;

COMMENT ON TABLE marques
    IS 'Marques commerciales des articles — V11';

-- ============================================================================
-- SECTION 4 — TABLE taxes
-- ============================================================================

CREATE TABLE taxes (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                        VARCHAR(20) NOT NULL,
    libelle                     VARCHAR(100) NOT NULL,
    type_taxe                   VARCHAR(20) NOT NULL,
    taux                        NUMERIC(5,2) NOT NULL DEFAULT 0,
    compte_comptable            VARCHAR(20),
    description                 TEXT,
    actif                       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at                  TIMESTAMPTZ,
    version                     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_taxes_type
        CHECK (type_taxe IN ('TVA','EXONERATION','DROIT_ACCISE','AUTRE')),
    CONSTRAINT chk_taxes_taux
        CHECK (taux BETWEEN 0 AND 100),
    CONSTRAINT uq_taxes_code
        UNIQUE (code)
);

CREATE INDEX idx_taxes_type
    ON taxes (type_taxe) WHERE deleted_at IS NULL;
CREATE INDEX idx_taxes_actif
    ON taxes (actif) WHERE deleted_at IS NULL;

COMMENT ON TABLE taxes
    IS 'Taxes applicables (TVA 18 %, exonérations, droits d''accises) — V11';

-- ============================================================================
-- SECTION 5 — TABLE articles
-- ============================================================================

CREATE TABLE articles (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                        VARCHAR(30) NOT NULL,
    code_barres_principal       VARCHAR(50),
    designation                 VARCHAR(255) NOT NULL,
    designation_courte          VARCHAR(100),
    description                 TEXT,
    type_article                VARCHAR(20) NOT NULL,
    famille_id                  UUID NOT NULL,
    marque_id                   UUID,
    unite_base_id               UUID NOT NULL,
    unite_achat_id              UUID,
    unite_vente_id              UUID,
    taxe_id                     UUID NOT NULL,
    compte_comptable_stock      VARCHAR(20),
    compte_comptable_vente      VARCHAR(20),
    compte_comptable_achat      VARCHAR(20),
    poids_kg                    NUMERIC(15,3),
    volume_m3                   NUMERIC(15,6),
    duree_vie_jours             INTEGER,
    numero_lot_obligatoire      BOOLEAN NOT NULL DEFAULT FALSE,
    numero_serie_obligatoire    BOOLEAN NOT NULL DEFAULT FALSE,
    stock_actuel                NUMERIC(15,3) NOT NULL DEFAULT 0,
    seuil_alerte                NUMERIC(15,3),
    seuil_reapprovisionnement   NUMERIC(15,3),
    stock_max                   NUMERIC(15,3),
    gerer_stock                 BOOLEAN NOT NULL DEFAULT TRUE,
    image_principale_id         UUID REFERENCES fichiers(id) ON DELETE SET NULL,
    statut                      VARCHAR(20) NOT NULL DEFAULT 'ACTIF',
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at                  TIMESTAMPTZ,
    version                     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_articles_type
        CHECK (type_article IN ('MARCHANDISE','SERVICE','PRODUIT_FINI','MATIERE_PREMIERE')),
    CONSTRAINT chk_articles_statut
        CHECK (statut IN ('ACTIF','INACTIF','ARCHIVE')),
    CONSTRAINT chk_articles_stock
        CHECK (stock_actuel >= 0),
    CONSTRAINT chk_articles_poids
        CHECK (poids_kg IS NULL OR poids_kg >= 0),
    CONSTRAINT chk_articles_volume
        CHECK (volume_m3 IS NULL OR volume_m3 >= 0),
    CONSTRAINT chk_articles_duree
        CHECK (duree_vie_jours IS NULL OR duree_vie_jours >= 0),
    CONSTRAINT chk_articles_code_format
        CHECK (code ~ '^ART-[0-9]{4}-[0-9]{6}$'),
    CONSTRAINT uq_articles_code
        UNIQUE (code),
    CONSTRAINT fk_articles_famille
        FOREIGN KEY (famille_id) REFERENCES familles_articles(id) ON DELETE RESTRICT,
    CONSTRAINT fk_articles_marque
        FOREIGN KEY (marque_id) REFERENCES marques(id) ON DELETE SET NULL,
    CONSTRAINT fk_articles_unite_base
        FOREIGN KEY (unite_base_id) REFERENCES unites_mesure(id) ON DELETE RESTRICT,
    CONSTRAINT fk_articles_unite_achat
        FOREIGN KEY (unite_achat_id) REFERENCES unites_mesure(id) ON DELETE RESTRICT,
    CONSTRAINT fk_articles_unite_vente
        FOREIGN KEY (unite_vente_id) REFERENCES unites_mesure(id) ON DELETE RESTRICT,
    CONSTRAINT fk_articles_taxe
        FOREIGN KEY (taxe_id) REFERENCES taxes(id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_articles_code_barres
    ON articles (code_barres_principal)
    WHERE code_barres_principal IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_articles_famille
    ON articles (famille_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_articles_marque
    ON articles (marque_id) WHERE marque_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_articles_unite_base
    ON articles (unite_base_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_articles_taxe
    ON articles (taxe_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_articles_statut
    ON articles (statut) WHERE deleted_at IS NULL;
CREATE INDEX idx_articles_designation
    ON articles (designation) WHERE deleted_at IS NULL;

COMMENT ON TABLE articles
    IS 'Fiche article (marchandise ou service) — V11';

-- ============================================================================
-- SECTION 6 — TABLE article_variantes
-- ============================================================================

CREATE TABLE article_variantes (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id              UUID NOT NULL,
    code_variante           VARCHAR(50) NOT NULL,
    code_barres             VARCHAR(50),
    attribut_1_nom          VARCHAR(50),
    attribut_1_valeur       VARCHAR(100),
    attribut_2_nom          VARCHAR(50),
    attribut_2_valeur       VARCHAR(100),
    attribut_3_nom          VARCHAR(50),
    attribut_3_valeur       VARCHAR(100),
    image_fichier_id        UUID REFERENCES fichiers(id) ON DELETE SET NULL,
    prix_supplement         NUMERIC(15,2) DEFAULT 0,
    stock_actuel            NUMERIC(15,3) NOT NULL DEFAULT 0,
    actif                   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at              TIMESTAMPTZ,
    version                 INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_variantes_stock
        CHECK (stock_actuel >= 0),
    CONSTRAINT chk_variantes_prix
        CHECK (prix_supplement IS NULL OR prix_supplement >= 0),
    CONSTRAINT uq_variantes_code
        UNIQUE (code_variante),
    CONSTRAINT fk_variantes_article
        FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX uq_variantes_code_barres
    ON article_variantes (code_barres)
    WHERE code_barres IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_variantes_article
    ON article_variantes (article_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_variantes_actif
    ON article_variantes (actif) WHERE deleted_at IS NULL;

COMMENT ON TABLE article_variantes
    IS 'Variantes d''article (taille, couleur, modèle) — V11';

-- ============================================================================
-- SECTION 7 — TABLE articles_fournisseurs
-- ============================================================================

CREATE TABLE articles_fournisseurs (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id                  UUID NOT NULL,
    fournisseur_id              UUID NOT NULL,
    reference_fournisseur       VARCHAR(100) NOT NULL,
    designation_fournisseur     VARCHAR(255),
    prix_achat_ht               NUMERIC(15,2) NOT NULL,
    devise                      VARCHAR(3) NOT NULL DEFAULT 'XOF',
    remise_pct                  NUMERIC(5,2) NOT NULL DEFAULT 0,
    delai_livraison_jours       INTEGER NOT NULL DEFAULT 0,
    quantite_minimum            NUMERIC(15,3),
    date_debut                  DATE NOT NULL DEFAULT CURRENT_DATE,
    date_fin                    DATE,
    actif                       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by                  UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at                  TIMESTAMPTZ,
    version                     INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_art_fourn_prix
        CHECK (prix_achat_ht >= 0),
    CONSTRAINT chk_art_fourn_remise
        CHECK (remise_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_art_fourn_delai
        CHECK (delai_livraison_jours >= 0),
    CONSTRAINT chk_art_fourn_dates
        CHECK (date_fin IS NULL OR date_fin >= date_debut),
    CONSTRAINT fk_art_fourn_article
        FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE,
    CONSTRAINT fk_art_fourn_fournisseur
        FOREIGN KEY (fournisseur_id) REFERENCES tiers(id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_art_fourn_ref_active
    ON articles_fournisseurs (article_id, fournisseur_id, reference_fournisseur)
    WHERE actif = TRUE AND deleted_at IS NULL;
CREATE INDEX idx_art_fourn_article
    ON articles_fournisseurs (article_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_art_fourn_fournisseur
    ON articles_fournisseurs (fournisseur_id) WHERE deleted_at IS NULL;

COMMENT ON TABLE articles_fournisseurs
    IS 'Liaison article ↔ fournisseur (prix d''achat) — V11';

-- ============================================================================
-- SECTION 8 — TRIGGERS STANDARD (V8)
-- ============================================================================

SELECT attacher_triggers_standard('familles_articles');
SELECT attacher_triggers_standard('unites_mesure');
SELECT attacher_triggers_standard('marques');
SELECT attacher_triggers_standard('taxes');
SELECT attacher_triggers_standard('articles');
SELECT attacher_triggers_standard('article_variantes');
SELECT attacher_triggers_standard('articles_fournisseurs');

-- ============================================================================
-- SECTION 9 — SEEDS RÉFÉRENTIELS
-- ============================================================================

-- Unités de mesure de base
INSERT INTO unites_mesure (code, libelle, symbole, type_unite, facteur_conversion_base, unite_base, est_base)
VALUES
    ('KG',    'Kilogramme',  'kg',  'MASSE',    1,          'KG',    TRUE),
    ('T',     'Tonne',       't',   'MASSE',    1000,       'KG',    FALSE),
    ('G',     'Gramme',      'g',   'MASSE',    0.001,      'KG',    FALSE),
    ('L',     'Litre',       'L',   'VOLUME',   1,          'L',     TRUE),
    ('ML',    'Millilitre',  'ml',  'VOLUME',   0.001,      'L',     FALSE),
    ('M',     'Mètre',       'm',   'LONGUEUR', 1,          'M',     TRUE),
    ('M2',    'Mètre carré', 'm²',  'SURFACE',  1,          'M2',    TRUE),
    ('M3',    'Mètre cube',  'm³',  'VOLUME',   1,          'M3',    TRUE),
    ('PCE',   'Pièce',       'pce', 'QUANTITE', 1,          'PCE',   TRUE),
    ('LOT',   'Lot',         'lot', 'QUANTITE', 1,          'PCE',   FALSE),
    ('H',     'Heure',       'h',   'TEMPS',    1,          'H',     TRUE),
    ('J',     'Jour',        'j',   'TEMPS',    24,         'H',     FALSE)
ON CONFLICT (code) DO NOTHING;

-- Taxes standard Burkina Faso
INSERT INTO taxes (code, libelle, type_taxe, taux, compte_comptable)
VALUES
    ('TVA_18',       'TVA 18 %',              'TVA',         18, '4431'),
    ('EXO_TVA',      'Exonération TVA',       'EXONERATION',  0, NULL),
    ('ACCISE_ALCOOL','Droit accises alcool',  'DROIT_ACCISE', 0, NULL),
    ('ACCISE_TABAC', 'Droit accises tabac',   'DROIT_ACCISE', 0, NULL)
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- SECTION 10 — DROITS
-- ============================================================================

GRANT SELECT, INSERT, UPDATE ON familles_articles TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON unites_mesure TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON marques TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON taxes TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON articles TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON article_variantes TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON articles_fournisseurs TO ycc_tenant_app;

-- ============================================================================
-- SECTION 11 — VÉRIFICATIONS POST-MIGRATION
-- ============================================================================

DO $$
DECLARE
    v_nb_tables    INTEGER;
    v_nb_index     INTEGER;
    v_nb_fk        INTEGER;
    v_nb_unites    INTEGER;
    v_nb_taxes     INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_nb_tables
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name IN (
        'familles_articles','unites_mesure','marques','taxes',
        'articles','article_variantes','articles_fournisseurs');

    IF v_nb_tables <> 7 THEN
        RAISE EXCEPTION 'Attendu 7 tables V11, trouve %', v_nb_tables;
    END IF;
    RAISE NOTICE '7 tables V11 verifiees';

    SELECT COUNT(*) INTO v_nb_index
    FROM pg_indexes
    WHERE tablename IN (
        'familles_articles','unites_mesure','marques','taxes',
        'articles','article_variantes','articles_fournisseurs');

    IF v_nb_index < 25 THEN
        RAISE EXCEPTION 'Index manquants V11 : %', v_nb_index;
    END IF;
    RAISE NOTICE '% index V11 verifies', v_nb_index;

    SELECT COUNT(*) INTO v_nb_fk
    FROM pg_constraint
    WHERE contype = 'f'
      AND conrelid::regclass::text IN (
        'familles_articles','unites_mesure','marques','taxes',
        'articles','article_variantes','articles_fournisseurs');

    IF v_nb_fk < 15 THEN
        RAISE EXCEPTION 'FK manquantes V11 : %', v_nb_fk;
    END IF;
    RAISE NOTICE '% FK V11 verifiees', v_nb_fk;

    SELECT COUNT(*) INTO v_nb_unites FROM unites_mesure;
    IF v_nb_unites < 12 THEN
        RAISE EXCEPTION 'Seeds unites_mesure insuffisants : %', v_nb_unites;
    END IF;
    RAISE NOTICE '% unites de mesure seedees', v_nb_unites;

    SELECT COUNT(*) INTO v_nb_taxes FROM taxes;
    IF v_nb_taxes < 4 THEN
        RAISE EXCEPTION 'Seeds taxes insuffisants : %', v_nb_taxes;
    END IF;
    RAISE NOTICE '% taxes seedees', v_nb_taxes;

    RAISE NOTICE '=============================================';
    RAISE NOTICE 'V11__articles.sql — Referentiel Articles OK';
    RAISE NOTICE '=============================================';
END;
$$;
