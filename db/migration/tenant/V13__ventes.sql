-- ============================================================================
-- V13__ventes.sql
-- Base : ycc_tenant_<id>
-- Objet : Module Ventes refondu (13 tables : documents unifiés, tarifs, workflow, encaissement)
-- Réf.  : Design Bible Phase 2 — Bloc V13
-- ============================================================================

SET search_path TO public;

-- ============================================================================
-- SECTION 1 — NUMÉROTATION
-- ============================================================================

CREATE TABLE sequences_documents (
    id                  BIGSERIAL PRIMARY KEY,
    type_document       VARCHAR(30) NOT NULL,
    prefixe             VARCHAR(10) NOT NULL,
    annee               INTEGER NOT NULL,
    dernier_numero      INTEGER NOT NULL DEFAULT 0,
    format              VARCHAR(100) NOT NULL DEFAULT '{PREFIXE}-{ANNEE}-{NUMERO:06d}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_seq_doc_type
        CHECK (type_document IN ('DEVIS','COMMANDE','BL','FACTURE','AVOIR','RETOUR')),
    CONSTRAINT chk_seq_doc_dernier
        CHECK (dernier_numero >= 0),
    CONSTRAINT uq_seq_doc UNIQUE (type_document, annee)
);

CREATE OR REPLACE FUNCTION prochain_numero_document(
    p_type_document VARCHAR,
    p_annee INTEGER
) RETURNS VARCHAR AS $$
DECLARE
    v_prefixe VARCHAR(10);
    v_format  VARCHAR(100);
    v_numero  INTEGER;
BEGIN
    UPDATE sequences_documents
    SET dernier_numero = dernier_numero + 1,
        updated_at = now()
    WHERE type_document = p_type_document AND annee = p_annee
    RETURNING prefixe, format, dernier_numero
    INTO v_prefixe, v_format, v_numero;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sequence introuvable : % / %', p_type_document, p_annee;
    END IF;

    RETURN replace(
        replace(
            replace(v_format, '{PREFIXE}', v_prefixe),
            '{ANNEE}', p_annee::TEXT
        ),
        '{NUMERO:06d}', lpad(v_numero::TEXT, 6, '0')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION prochain_numero_document(VARCHAR, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION prochain_numero_document(VARCHAR, INTEGER) TO ycc_tenant_app;

-- Seeds séquences
INSERT INTO sequences_documents (type_document, prefixe, annee)
VALUES
    ('DEVIS',    'DEV', EXTRACT(YEAR FROM CURRENT_DATE)::INT),
    ('COMMANDE', 'BC',  EXTRACT(YEAR FROM CURRENT_DATE)::INT),
    ('BL',       'BL',  EXTRACT(YEAR FROM CURRENT_DATE)::INT),
    ('FACTURE',  'FAC', EXTRACT(YEAR FROM CURRENT_DATE)::INT),
    ('AVOIR',    'AV',  EXTRACT(YEAR FROM CURRENT_DATE)::INT),
    ('RETOUR',   'RET', EXTRACT(YEAR FROM CURRENT_DATE)::INT)
ON CONFLICT (type_document, annee) DO NOTHING;

-- ============================================================================
-- SECTION 2 — DOCUMENTS UNIFIÉS
-- ============================================================================

CREATE TABLE documents_vente (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type_document           VARCHAR(30) NOT NULL,
    numero                  VARCHAR(50) NOT NULL,
    tiers_id                UUID NOT NULL,
    date_document           DATE NOT NULL DEFAULT CURRENT_DATE,
    date_validite           DATE,
    date_echeance           DATE,
    statut                  VARCHAR(30) NOT NULL DEFAULT 'BROUILLON',
    reference_externe       VARCHAR(100),
    remise_globale_pct      NUMERIC(5,2) NOT NULL DEFAULT 0,
    total_ht                NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_tva               NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_ttc               NUMERIC(15,2) NOT NULL DEFAULT 0,
    devise                  VARCHAR(3) NOT NULL DEFAULT 'XOF',
    taux_change             NUMERIC(15,6) NOT NULL DEFAULT 1,
    adresse_livraison_id    UUID REFERENCES adresse_tiers(id) ON DELETE SET NULL,
    projet_id               UUID,
    conditions_paiement     TEXT,
    notes                   TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at              TIMESTAMPTZ,
    version                 INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_doc_type
        CHECK (type_document IN ('DEVIS','COMMANDE','BL','FACTURE','AVOIR','RETOUR')),
    CONSTRAINT chk_doc_statut
        CHECK (statut IN (
            'BROUILLON','ENVOYE','ACCEPTE','REFUSE','EXPIRE','CONVERTI',
            'CONFIRMEE','EN_PREPARATION','EXPEDIEE','LIVREE','ANNULEE',
            'PREPARATION','EXPEDITION','RETOURNEE',
            'EMISE','PARTIELLEMENT_PAYEE','PAYEE','IMPAYEE',
            'EMIS','REMBOURSE','ANNULE'
        )),
    CONSTRAINT chk_doc_remise
        CHECK (remise_globale_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_doc_totaux
        CHECK (total_ttc = total_ht + total_tva AND total_ht >= 0 AND total_tva >= 0),
    CONSTRAINT chk_doc_dates
        CHECK (date_validite IS NULL OR date_validite >= date_document),
    CONSTRAINT chk_doc_echeance
        CHECK (date_echeance IS NULL OR date_echeance >= date_document),
    CONSTRAINT uq_doc_numero
        UNIQUE (type_document, numero),
    CONSTRAINT fk_doc_tiers
        FOREIGN KEY (tiers_id) REFERENCES tiers(id) ON DELETE RESTRICT
);

CREATE INDEX idx_doc_tiers ON documents_vente (tiers_id, date_document DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_doc_type ON documents_vente (type_document) WHERE deleted_at IS NULL;
CREATE INDEX idx_doc_statut ON documents_vente (statut) WHERE deleted_at IS NULL;
CREATE INDEX idx_doc_date ON documents_vente (date_document DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_doc_echeance
    ON documents_vente (date_echeance)
    WHERE statut IN ('EMISE','PARTIELLEMENT_PAYEE','IMPAYEE') AND deleted_at IS NULL;
CREATE INDEX idx_doc_projet ON documents_vente (projet_id) WHERE projet_id IS NOT NULL AND deleted_at IS NULL;

CREATE TABLE documents_vente_lignes (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id             UUID NOT NULL,
    article_id              UUID,
    designation             VARCHAR(255) NOT NULL,
    quantite                NUMERIC(15,3) NOT NULL,
    prix_unitaire           NUMERIC(15,2) NOT NULL,
    remise_pct              NUMERIC(5,2) NOT NULL DEFAULT 0,
    taux_tva                NUMERIC(5,2) NOT NULL DEFAULT 18,
    montant_ht              NUMERIC(15,2) NOT NULL,
    montant_tva             NUMERIC(15,2) NOT NULL,
    montant_ttc             NUMERIC(15,2) NOT NULL,
    ordre                   SMALLINT NOT NULL DEFAULT 0,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at              TIMESTAMPTZ,
    version                 INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_doc_lignes_quantite CHECK (quantite > 0),
    CONSTRAINT chk_doc_lignes_prix CHECK (prix_unitaire >= 0),
    CONSTRAINT chk_doc_lignes_remise CHECK (remise_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_doc_lignes_tva CHECK (taux_tva BETWEEN 0 AND 100),
    CONSTRAINT chk_doc_lignes_montants
        CHECK (montant_ttc = montant_ht + montant_tva AND montant_ht >= 0 AND montant_tva >= 0),
    CONSTRAINT fk_doc_lignes_doc
        FOREIGN KEY (document_id) REFERENCES documents_vente(id) ON DELETE CASCADE,
    CONSTRAINT fk_doc_lignes_article
        FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE RESTRICT
);

CREATE INDEX idx_doc_lignes_doc ON documents_vente_lignes (document_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_doc_lignes_article ON documents_vente_lignes (article_id) WHERE article_id IS NOT NULL AND deleted_at IS NULL;

CREATE TABLE documents_vente_liens (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_source_id      UUID NOT NULL,
    document_cible_id       UUID NOT NULL,
    type_lien               VARCHAR(30) NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT chk_doc_liens_type
        CHECK (type_lien IN ('CONVERSION','LIVRAISON_PARTIELLE','FACTURATION','AVOIR','RETOUR')),
    CONSTRAINT chk_doc_liens_different
        CHECK (document_source_id <> document_cible_id),
    CONSTRAINT fk_doc_liens_source
        FOREIGN KEY (document_source_id) REFERENCES documents_vente(id) ON DELETE CASCADE,
    CONSTRAINT fk_doc_liens_cible
        FOREIGN KEY (document_cible_id) REFERENCES documents_vente(id) ON DELETE CASCADE
);

CREATE INDEX idx_doc_liens_source ON documents_vente_liens (document_source_id);
CREATE INDEX idx_doc_liens_cible ON documents_vente_liens (document_cible_id);

CREATE TABLE documents_vente_historique_statuts (
    id                      BIGSERIAL PRIMARY KEY,
    document_id             UUID NOT NULL,
    statut_precedent        VARCHAR(30),
    statut_nouveau          VARCHAR(30) NOT NULL,
    date_transition         TIMESTAMPTZ NOT NULL DEFAULT now(),
    change_par              UUID REFERENCES users(id) ON DELETE SET NULL,
    commentaire             TEXT,
    CONSTRAINT fk_doc_hist_doc
        FOREIGN KEY (document_id) REFERENCES documents_vente(id) ON DELETE CASCADE
);

CREATE INDEX idx_doc_hist_doc ON documents_vente_historique_statuts (document_id, date_transition DESC);

-- ============================================================================
-- SECTION 3 — TARIFS
-- ============================================================================

CREATE TABLE listes_prix (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                    VARCHAR(30) NOT NULL,
    nom                     VARCHAR(100) NOT NULL,
    description             TEXT,
    tiers_id                UUID,
    date_debut              DATE NOT NULL DEFAULT CURRENT_DATE,
    date_fin                DATE,
    devise                  VARCHAR(3) NOT NULL DEFAULT 'XOF',
    actif                   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at              TIMESTAMPTZ,
    version                 INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_listes_prix_dates
        CHECK (date_fin IS NULL OR date_fin >= date_debut),
    CONSTRAINT uq_listes_prix_code UNIQUE (code),
    CONSTRAINT fk_listes_prix_tiers
        FOREIGN KEY (tiers_id) REFERENCES tiers(id) ON DELETE SET NULL
);

CREATE INDEX idx_listes_prix_tiers ON listes_prix (tiers_id) WHERE tiers_id IS NOT NULL AND deleted_at IS NULL;

CREATE TABLE lignes_tarif (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    liste_prix_id           UUID NOT NULL,
    article_id              UUID NOT NULL,
    prix_unitaire           NUMERIC(15,2) NOT NULL,
    quantite_minimum        NUMERIC(15,3),
    remise_pct              NUMERIC(5,2) NOT NULL DEFAULT 0,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at              TIMESTAMPTZ,
    version                 INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_lignes_tarif_prix CHECK (prix_unitaire >= 0),
    CONSTRAINT chk_lignes_tarif_remise CHECK (remise_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_lignes_tarif_qte CHECK (quantite_minimum IS NULL OR quantite_minimum > 0),
    CONSTRAINT uq_lignes_tarif UNIQUE (liste_prix_id, article_id),
    CONSTRAINT fk_lignes_tarif_liste
        FOREIGN KEY (liste_prix_id) REFERENCES listes_prix(id) ON DELETE CASCADE,
    CONSTRAINT fk_lignes_tarif_article
        FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE RESTRICT
);

CREATE INDEX idx_lignes_tarif_liste ON lignes_tarif (liste_prix_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_lignes_tarif_article ON lignes_tarif (article_id) WHERE deleted_at IS NULL;

CREATE TABLE promotions (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                    VARCHAR(30) NOT NULL,
    nom                     VARCHAR(255) NOT NULL,
    description             TEXT,
    type_promotion          VARCHAR(30) NOT NULL,
    valeur                  NUMERIC(15,2) NOT NULL,
    date_debut              DATE NOT NULL,
    date_fin                DATE NOT NULL,
    article_id              UUID,
    famille_id              UUID,
    actif                   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at              TIMESTAMPTZ,
    version                 INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_promo_type
        CHECK (type_promotion IN ('REMISE_PCT','REMISE_MONTANT','PRIX_FIXE','LOT_GRATUIT')),
    CONSTRAINT chk_promo_valeur CHECK (valeur >= 0),
    CONSTRAINT chk_promo_dates CHECK (date_fin >= date_debut),
    CONSTRAINT uq_promo_code UNIQUE (code),
    CONSTRAINT fk_promo_article
        FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE,
    CONSTRAINT fk_promo_famille
        FOREIGN KEY (famille_id) REFERENCES familles_articles(id) ON DELETE CASCADE
);

CREATE INDEX idx_promo_dates ON promotions (date_debut, date_fin) WHERE actif AND deleted_at IS NULL;

-- ============================================================================
-- SECTION 4 — WORKFLOW
-- ============================================================================

CREATE TABLE circuits_validation (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                    VARCHAR(30) NOT NULL,
    nom                     VARCHAR(255) NOT NULL,
    type_document           VARCHAR(30) NOT NULL,
    seuil_montant           NUMERIC(15,2),
    ordre                   SMALLINT NOT NULL DEFAULT 1,
    actif                   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at              TIMESTAMPTZ,
    version                 INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_circuits_type
        CHECK (type_document IN ('DEVIS','COMMANDE','BL','FACTURE','AVOIR','RETOUR')),
    CONSTRAINT chk_circuits_seuil
        CHECK (seuil_montant IS NULL OR seuil_montant >= 0),
    CONSTRAINT uq_circuits_code UNIQUE (code)
);

CREATE TABLE validations_documents (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    circuit_id              UUID NOT NULL,
    document_id             UUID NOT NULL,
    valideur_id             UUID,
    statut                  VARCHAR(20) NOT NULL DEFAULT 'EN_ATTENTE',
    date_demande            TIMESTAMPTZ NOT NULL DEFAULT now(),
    date_validation         TIMESTAMPTZ,
    commentaire             TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_validations_statut
        CHECK (statut IN ('EN_ATTENTE','VALIDEE','REJETEE')),
    CONSTRAINT fk_validations_circuit
        FOREIGN KEY (circuit_id) REFERENCES circuits_validation(id) ON DELETE CASCADE,
    CONSTRAINT fk_validations_doc
        FOREIGN KEY (document_id) REFERENCES documents_vente(id) ON DELETE CASCADE,
    CONSTRAINT fk_validations_valideur
        FOREIGN KEY (valideur_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX idx_validations_doc ON validations_documents (document_id);
CREATE INDEX idx_validations_statut ON validations_documents (statut) WHERE statut = 'EN_ATTENTE';

-- ============================================================================
-- SECTION 5 — ENCAISSEMENT
-- ============================================================================

CREATE TABLE paiements (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero                  VARCHAR(50) NOT NULL,
    tiers_id                UUID NOT NULL,
    date_paiement           DATE NOT NULL DEFAULT CURRENT_DATE,
    mode_paiement           VARCHAR(30) NOT NULL,
    montant                 NUMERIC(15,2) NOT NULL,
    devise                  VARCHAR(3) NOT NULL DEFAULT 'XOF',
    taux_change             NUMERIC(15,6) NOT NULL DEFAULT 1,
    reference_externe       VARCHAR(100),
    operateur               VARCHAR(50),
    statut                  VARCHAR(20) NOT NULL DEFAULT 'EN_ATTENTE',
    notes                   TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at              TIMESTAMPTZ,
    version                 INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_paiements_mode
        CHECK (mode_paiement IN ('ESPECES','CHEQUE','VIREMENT','MOBILE_MONEY','CARTE_BANCAIRE','TRAITE','COMPENSATION')),
    CONSTRAINT chk_paiements_statut
        CHECK (statut IN ('EN_ATTENTE','VALIDE','REJETE','REMBOURSE')),
    CONSTRAINT chk_paiements_montant CHECK (montant > 0),
    CONSTRAINT uq_paiements_numero UNIQUE (numero),
    CONSTRAINT fk_paiements_tiers
        FOREIGN KEY (tiers_id) REFERENCES tiers(id) ON DELETE RESTRICT
);

CREATE INDEX idx_paiements_tiers ON paiements (tiers_id, date_paiement DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_paiements_statut ON paiements (statut) WHERE deleted_at IS NULL;

CREATE TABLE paiements_allocations (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    paiement_id             UUID NOT NULL,
    document_id             UUID NOT NULL,
    montant_alloue          NUMERIC(15,2) NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT chk_alloc_montant CHECK (montant_alloue > 0),
    CONSTRAINT uq_alloc UNIQUE (paiement_id, document_id),
    CONSTRAINT fk_alloc_paiement
        FOREIGN KEY (paiement_id) REFERENCES paiements(id) ON DELETE CASCADE,
    CONSTRAINT fk_alloc_document
        FOREIGN KEY (document_id) REFERENCES documents_vente(id) ON DELETE RESTRICT
);

CREATE INDEX idx_alloc_paiement ON paiements_allocations (paiement_id);
CREATE INDEX idx_alloc_document ON paiements_allocations (document_id);

CREATE TABLE relances_factures (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id             UUID NOT NULL,
    niveau                  SMALLINT NOT NULL,
    date_relance            TIMESTAMPTZ NOT NULL DEFAULT now(),
    canal                   VARCHAR(20) NOT NULL,
    statut                  VARCHAR(20) NOT NULL DEFAULT 'EN_ATTENTE',
    contenu                 TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by              UUID REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT chk_relances_niveau CHECK (niveau BETWEEN 1 AND 3),
    CONSTRAINT chk_relances_canal
        CHECK (canal IN ('EMAIL','SMS','WHATSAPP','APPEL','COURRIER')),
    CONSTRAINT chk_relances_statut
        CHECK (statut IN ('EN_ATTENTE','ENVOYEE','ECHOUEE','PAYEE')),
    CONSTRAINT fk_relances_doc
        FOREIGN KEY (document_id) REFERENCES documents_vente(id) ON DELETE RESTRICT
);

CREATE INDEX idx_relances_doc ON relances_factures (document_id, date_relance DESC);

-- ============================================================================
-- SECTION 6 — TRIGGERS
-- ============================================================================

SELECT attacher_triggers_standard('sequences_documents');
SELECT attacher_triggers_standard('documents_vente');
SELECT attacher_triggers_standard('documents_vente_lignes');
SELECT attacher_triggers_standard('listes_prix');
SELECT attacher_triggers_standard('lignes_tarif');
SELECT attacher_triggers_standard('promotions');
SELECT attacher_triggers_standard('circuits_validation');
SELECT attacher_triggers_standard('paiements');

-- Historique append-only
CREATE OR REPLACE FUNCTION empecher_modification_doc_hist()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Table documents_vente_historique_statuts append-only';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_doc_hist_append_only
BEFORE UPDATE OR DELETE ON documents_vente_historique_statuts
FOR EACH ROW EXECUTE FUNCTION empecher_modification_doc_hist();

-- Trigger historique automatique sur changement statut
CREATE OR REPLACE FUNCTION tracer_changement_statut_document()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.statut <> OLD.statut THEN
        INSERT INTO documents_vente_historique_statuts
            (document_id, statut_precedent, statut_nouveau, change_par)
        VALUES
            (NEW.id, OLD.statut, NEW.statut, current_user_id());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_doc_statut_historique
AFTER UPDATE OF statut ON documents_vente
FOR EACH ROW EXECUTE FUNCTION tracer_changement_statut_document();

-- ============================================================================
-- SECTION 7 — DROITS
-- ============================================================================

GRANT SELECT, INSERT, UPDATE ON sequences_documents TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON documents_vente TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON documents_vente_lignes TO ycc_tenant_app;
GRANT SELECT, INSERT ON documents_vente_liens TO ycc_tenant_app;
GRANT SELECT, INSERT ON documents_vente_historique_statuts TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON listes_prix TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON lignes_tarif TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON promotions TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON circuits_validation TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON validations_documents TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON paiements TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON paiements_allocations TO ycc_tenant_app;
GRANT SELECT, INSERT, UPDATE ON relances_factures TO ycc_tenant_app;
GRANT USAGE, SELECT ON SEQUENCE sequences_documents_id_seq TO ycc_tenant_app;
GRANT USAGE, SELECT ON SEQUENCE documents_vente_historique_statuts_id_seq TO ycc_tenant_app;

-- ============================================================================
-- SECTION 8 — VÉRIFICATIONS
-- ============================================================================

DO $$
DECLARE
    v_nb_tables INTEGER;
    v_nb_seqs   INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_nb_tables
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name IN (
        'sequences_documents',
        'documents_vente','documents_vente_lignes','documents_vente_liens','documents_vente_historique_statuts',
        'listes_prix','lignes_tarif','promotions',
        'circuits_validation','validations_documents',
        'paiements','paiements_allocations','relances_factures');

    IF v_nb_tables <> 13 THEN
        RAISE EXCEPTION 'Attendu 13 tables V13, trouve %', v_nb_tables;
    END IF;
    RAISE NOTICE '13 tables V13 verifiees';

    SELECT COUNT(*) INTO v_nb_seqs FROM sequences_documents;
    IF v_nb_seqs < 6 THEN
        RAISE EXCEPTION 'Seeds sequences insuffisants : %', v_nb_seqs;
    END IF;
    RAISE NOTICE '% sequences seedees', v_nb_seqs;

    RAISE NOTICE '=============================================';
    RAISE NOTICE 'V13__ventes.sql — Module Ventes OK';
    RAISE NOTICE '=============================================';
END;
$$;
