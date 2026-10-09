-- ============================================================================
-- V10__init_ventes.sql
-- Base : ycc_tenant_<id>
-- Objet : Module Ventes — 12 tables + ENUM + séquences + index + triggers
-- Réf.  : Bloc 1.3 (BL-102)
-- ============================================================================

SET search_path TO public;

-- SECTION 0 — CORRECTIF E11
DELETE FROM numero_sequences WHERE type_document IN ('BON_COMMANDE', 'AVOIR');

-- SECTION 1 — ENUM type_facture
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'type_facture') THEN
        CREATE TYPE type_facture AS ENUM ('NORMALE', 'ACOMPTE', 'SOLDE');
    END IF;
END $$;

-- SECTION 2 — TABLES
CREATE TABLE clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(20) NOT NULL,
    nom VARCHAR(255) NOT NULL,
    type_client VARCHAR(20) NOT NULL DEFAULT 'ENTREPRISE',
    email CITEXT,
    telephone VARCHAR(30),
    adresse adresse_complete,
    crm_compte_id UUID,
    plafond_encours NUMERIC(15,2),
    tolerance_sur_livraison_pct NUMERIC(5,2) NOT NULL DEFAULT 0,
    delai_paiement_jours INTEGER NOT NULL DEFAULT 30,
    devise_preferee VARCHAR(3) NOT NULL DEFAULT 'XOF',
    statut VARCHAR(20) NOT NULL DEFAULT 'ACTIF',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ,
    version INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_clients_type CHECK (type_client IN ('PARTICULIER','ENTREPRISE','ADMINISTRATION')),
    CONSTRAINT chk_clients_statut CHECK (statut IN ('ACTIF','INACTIF','ARCHIVE')),
    CONSTRAINT chk_clients_plafond CHECK (plafond_encours IS NULL OR plafond_encours >= 0),
    CONSTRAINT chk_clients_tolerance CHECK (tolerance_sur_livraison_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_clients_delai CHECK (delai_paiement_jours >= 0),
    CONSTRAINT chk_clients_code_format CHECK (code ~ '^CLI-[0-9]{4}-[0-9]{6}$'),
    CONSTRAINT uq_clients_code UNIQUE (code)
);
CREATE INDEX idx_clients_statut ON clients (statut) WHERE deleted_at IS NULL;
CREATE INDEX idx_clients_nom ON clients (nom) WHERE deleted_at IS NULL;
CREATE INDEX idx_clients_crm_compte ON clients (crm_compte_id) WHERE crm_compte_id IS NOT NULL AND deleted_at IS NULL;

CREATE TABLE tarifs_clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL,
    article_id UUID,
    prix_unitaire NUMERIC(15,2) NOT NULL,
    devise VARCHAR(3) NOT NULL DEFAULT 'XOF',
    date_debut DATE NOT NULL,
    date_fin DATE,
    actif BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ,
    version INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_tarifs_prix CHECK (prix_unitaire >= 0),
    CONSTRAINT chk_tarifs_dates CHECK (date_fin IS NULL OR date_fin >= date_debut),
    CONSTRAINT fk_tarifs_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT
);
CREATE INDEX idx_tarifs_client ON tarifs_clients (client_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_tarifs_article ON tarifs_clients (article_id) WHERE article_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_tarifs_periode ON tarifs_clients (client_id, date_debut, date_fin) WHERE actif AND deleted_at IS NULL;

CREATE TABLE devis (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero VARCHAR(30) NOT NULL,
    client_id UUID NOT NULL,
    date_devis DATE NOT NULL DEFAULT CURRENT_DATE,
    date_validite DATE NOT NULL,
    statut statut_devis NOT NULL DEFAULT 'BROUILLON',
    remise_globale_pct NUMERIC(5,2) NOT NULL DEFAULT 0,
    total_ht NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_tva NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_ttc NUMERIC(15,2) NOT NULL DEFAULT 0,
    devise VARCHAR(3) NOT NULL DEFAULT 'XOF',
    taux_change NUMERIC(15,6) NOT NULL DEFAULT 1,
    conditions_paiement TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ,
    version INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_devis_totaux CHECK (total_ttc = total_ht + total_tva AND total_ht >= 0 AND total_tva >= 0),
    CONSTRAINT chk_devis_remise CHECK (remise_globale_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_devis_validite CHECK (date_validite >= date_devis),
    CONSTRAINT uq_devis_numero UNIQUE (numero),
    CONSTRAINT fk_devis_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT
);
CREATE INDEX idx_devis_client ON devis (client_id, date_devis DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_devis_statut ON devis (statut) WHERE deleted_at IS NULL;
CREATE INDEX idx_devis_validite ON devis (date_validite) WHERE statut IN ('ENVOYE','ACCEPTE') AND deleted_at IS NULL;

CREATE TABLE devis_lignes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    devis_id UUID NOT NULL,
    article_id UUID,
    designation VARCHAR(255) NOT NULL,
    quantite NUMERIC(15,3) NOT NULL,
    prix_unitaire NUMERIC(15,2) NOT NULL,
    remise_pct NUMERIC(5,2) NOT NULL DEFAULT 0,
    taux_tva NUMERIC(5,2) NOT NULL DEFAULT 0,
    montant_ht NUMERIC(15,2) NOT NULL,
    montant_tva NUMERIC(15,2) NOT NULL,
    montant_ttc NUMERIC(15,2) NOT NULL,
    ordre SMALLINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ,
    version INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_devis_lignes_quantite CHECK (quantite > 0),
    CONSTRAINT chk_devis_lignes_prix CHECK (prix_unitaire >= 0),
    CONSTRAINT chk_devis_lignes_remise CHECK (remise_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_devis_lignes_tva CHECK (taux_tva BETWEEN 0 AND 100),
    CONSTRAINT chk_devis_lignes_montants CHECK (montant_ttc = montant_ht + montant_tva AND montant_ht >= 0 AND montant_tva >= 0),
    CONSTRAINT fk_devis_lignes_devis FOREIGN KEY (devis_id) REFERENCES devis(id) ON DELETE CASCADE
);
CREATE INDEX idx_devis_lignes_devis ON devis_lignes (devis_id) WHERE deleted_at IS NULL;

CREATE TABLE commandes_clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero VARCHAR(30) NOT NULL,
    devis_id UUID,
    client_id UUID NOT NULL,
    date_commande DATE NOT NULL DEFAULT CURRENT_DATE,
    date_livraison_prevue DATE,
    statut statut_commande NOT NULL DEFAULT 'BROUILLON',
    remise_globale_pct NUMERIC(5,2) NOT NULL DEFAULT 0,
    total_ht NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_tva NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_ttc NUMERIC(15,2) NOT NULL DEFAULT 0,
    devise VARCHAR(3) NOT NULL DEFAULT 'XOF',
    taux_change NUMERIC(15,6) NOT NULL DEFAULT 1,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ,
    version INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_cc_totaux CHECK (total_ttc = total_ht + total_tva AND total_ht >= 0 AND total_tva >= 0),
    CONSTRAINT chk_cc_remise CHECK (remise_globale_pct BETWEEN 0 AND 100),
    CONSTRAINT uq_cc_numero UNIQUE (numero),
    CONSTRAINT fk_cc_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT,
    CONSTRAINT fk_cc_devis FOREIGN KEY (devis_id) REFERENCES devis(id) ON DELETE SET NULL
);
CREATE INDEX idx_cc_client ON commandes_clients (client_id, date_commande DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_cc_statut ON commandes_clients (statut) WHERE deleted_at IS NULL;
CREATE INDEX idx_cc_devis ON commandes_clients (devis_id) WHERE devis_id IS NOT NULL AND deleted_at IS NULL;

CREATE TABLE commande_lignes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    commande_id UUID NOT NULL,
    article_id UUID,
    designation VARCHAR(255) NOT NULL,
    quantite NUMERIC(15,3) NOT NULL,
    quantite_livree NUMERIC(15,3) NOT NULL DEFAULT 0,
    prix_unitaire NUMERIC(15,2) NOT NULL,
    remise_pct NUMERIC(5,2) NOT NULL DEFAULT 0,
    taux_tva NUMERIC(5,2) NOT NULL DEFAULT 0,
    montant_ht NUMERIC(15,2) NOT NULL,
    montant_tva NUMERIC(15,2) NOT NULL,
    montant_ttc NUMERIC(15,2) NOT NULL,
    ordre SMALLINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ,
    version INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_cl_quantite CHECK (quantite > 0),
    CONSTRAINT chk_cl_quantite_livree CHECK (quantite_livree >= 0 AND quantite_livree <= quantite),
    CONSTRAINT chk_cl_prix CHECK (prix_unitaire >= 0),
    CONSTRAINT chk_cl_remise CHECK (remise_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_cl_tva CHECK (taux_tva BETWEEN 0 AND 100),
    CONSTRAINT chk_cl_montants CHECK (montant_ttc = montant_ht + montant_tva AND montant_ht >= 0 AND montant_tva >= 0),
    CONSTRAINT fk_cl_commande FOREIGN KEY (commande_id) REFERENCES commandes_clients(id) ON DELETE CASCADE
);
CREATE INDEX idx_cl_commande ON commande_lignes (commande_id) WHERE deleted_at IS NULL;

CREATE TABLE bons_livraison (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero VARCHAR(30) NOT NULL,
    commande_id UUID,
    client_id UUID NOT NULL,
    date_livraison DATE NOT NULL DEFAULT CURRENT_DATE,
    statut statut_livraison NOT NULL DEFAULT 'PREPARATION',
    transporteur VARCHAR(100),
    adresse_livraison adresse_complete,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ,
    version INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT uq_bl_numero UNIQUE (numero),
    CONSTRAINT fk_bl_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT,
    CONSTRAINT fk_bl_commande FOREIGN KEY (commande_id) REFERENCES commandes_clients(id) ON DELETE RESTRICT
);
CREATE INDEX idx_bl_client ON bons_livraison (client_id, date_livraison DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_bl_commande ON bons_livraison (commande_id) WHERE commande_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_bl_statut ON bons_livraison (statut) WHERE deleted_at IS NULL;

CREATE TABLE bon_livraison_lignes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bl_id UUID NOT NULL,
    commande_ligne_id UUID,
    article_id UUID,
    designation VARCHAR(255) NOT NULL,
    quantite_livree NUMERIC(15,3) NOT NULL,
    ordre SMALLINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ,
    version INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_bll_quantite CHECK (quantite_livree > 0),
    CONSTRAINT fk_bll_bl FOREIGN KEY (bl_id) REFERENCES bons_livraison(id) ON DELETE CASCADE,
    CONSTRAINT fk_bll_commande_ligne FOREIGN KEY (commande_ligne_id) REFERENCES commande_lignes(id) ON DELETE SET NULL
);
CREATE INDEX idx_bll_bl ON bon_livraison_lignes (bl_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_bll_commande_ligne ON bon_livraison_lignes (commande_ligne_id) WHERE commande_ligne_id IS NOT NULL AND deleted_at IS NULL;

CREATE TABLE factures_clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero VARCHAR(30) NOT NULL,
    type_facture type_facture NOT NULL DEFAULT 'NORMALE',
    facture_parent_id UUID,
    client_id UUID NOT NULL,
    commande_id UUID,
    bl_id UUID,
    projet_id UUID,
    date_emission DATE NOT NULL DEFAULT CURRENT_DATE,
    date_echeance DATE NOT NULL,
    statut statut_facture NOT NULL DEFAULT 'BROUILLON',
    remise_globale_pct NUMERIC(5,2) NOT NULL DEFAULT 0,
    total_ht NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_tva NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_ttc NUMERIC(15,2) NOT NULL DEFAULT 0,
    montant_acompte_deduit NUMERIC(15,2) NOT NULL DEFAULT 0,
    devise VARCHAR(3) NOT NULL DEFAULT 'XOF',
    taux_change NUMERIC(15,6) NOT NULL DEFAULT 1,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ,
    version INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_fc_totaux CHECK (total_ttc = total_ht + total_tva AND total_ht >= 0 AND total_tva >= 0),
    CONSTRAINT chk_fc_remise CHECK (remise_globale_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_fc_acompte CHECK (montant_acompte_deduit >= 0),
    CONSTRAINT chk_fc_echeance CHECK (date_echeance >= date_emission),
    CONSTRAINT chk_fc_type_parent CHECK ((type_facture = 'SOLDE' AND facture_parent_id IS NOT NULL) OR (type_facture <> 'SOLDE' AND facture_parent_id IS NULL)),
    CONSTRAINT uq_fc_numero UNIQUE (numero),
    CONSTRAINT fk_fc_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT,
    CONSTRAINT fk_fc_commande FOREIGN KEY (commande_id) REFERENCES commandes_clients(id) ON DELETE SET NULL,
    CONSTRAINT fk_fc_bl FOREIGN KEY (bl_id) REFERENCES bons_livraison(id) ON DELETE SET NULL,
    CONSTRAINT fk_fc_parent FOREIGN KEY (facture_parent_id) REFERENCES factures_clients(id) ON DELETE SET NULL
);
CREATE INDEX idx_fc_client ON factures_clients (client_id, date_emission DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_fc_statut ON factures_clients (statut) WHERE deleted_at IS NULL;
CREATE INDEX idx_fc_echeance ON factures_clients (date_echeance) WHERE statut IN ('EMISE','PARTIELLEMENT_PAYEE','IMPAYEE') AND deleted_at IS NULL;
CREATE INDEX idx_fc_commande ON factures_clients (commande_id) WHERE commande_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_fc_parent ON factures_clients (facture_parent_id) WHERE facture_parent_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_fc_projet ON factures_clients (projet_id) WHERE projet_id IS NOT NULL AND deleted_at IS NULL;

CREATE TABLE facture_lignes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facture_id UUID NOT NULL,
    article_id UUID,
    designation VARCHAR(255) NOT NULL,
    quantite NUMERIC(15,3) NOT NULL,
    prix_unitaire NUMERIC(15,2) NOT NULL,
    remise_pct NUMERIC(5,2) NOT NULL DEFAULT 0,
    taux_tva NUMERIC(5,2) NOT NULL DEFAULT 0,
    montant_ht NUMERIC(15,2) NOT NULL,
    montant_tva NUMERIC(15,2) NOT NULL,
    montant_ttc NUMERIC(15,2) NOT NULL,
    ordre SMALLINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ,
    version INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_fl_quantite CHECK (quantite > 0),
    CONSTRAINT chk_fl_prix CHECK (prix_unitaire >= 0),
    CONSTRAINT chk_fl_remise CHECK (remise_pct BETWEEN 0 AND 100),
    CONSTRAINT chk_fl_tva CHECK (taux_tva BETWEEN 0 AND 100),
    CONSTRAINT chk_fl_montants CHECK (montant_ttc = montant_ht + montant_tva AND montant_ht >= 0 AND montant_tva >= 0),
    CONSTRAINT fk_fl_facture FOREIGN KEY (facture_id) REFERENCES factures_clients(id) ON DELETE CASCADE
);
CREATE INDEX idx_fl_facture ON facture_lignes (facture_id) WHERE deleted_at IS NULL;

CREATE TABLE avoirs_clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero VARCHAR(30) NOT NULL,
    facture_id UUID NOT NULL,
    client_id UUID NOT NULL,
    date_avoir DATE NOT NULL DEFAULT CURRENT_DATE,
    motif VARCHAR(255) NOT NULL,
    montant_ht NUMERIC(15,2) NOT NULL,
    montant_tva NUMERIC(15,2) NOT NULL,
    montant_ttc NUMERIC(15,2) NOT NULL,
    statut VARCHAR(20) NOT NULL DEFAULT 'BROUILLON',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ,
    version INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_av_statut CHECK (statut IN ('BROUILLON','EMIS','REMBOURSE','ANNULE')),
    CONSTRAINT chk_av_montants CHECK (montant_ttc = montant_ht + montant_tva AND montant_ht >= 0 AND montant_tva >= 0),
    CONSTRAINT uq_av_numero UNIQUE (numero),
    CONSTRAINT fk_av_facture FOREIGN KEY (facture_id) REFERENCES factures_clients(id) ON DELETE RESTRICT,
    CONSTRAINT fk_av_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT
);
CREATE INDEX idx_av_facture ON avoirs_clients (facture_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_av_client ON avoirs_clients (client_id, date_avoir DESC) WHERE deleted_at IS NULL;

CREATE TABLE paiements_clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero VARCHAR(30) NOT NULL,
    facture_id UUID NOT NULL,
    client_id UUID NOT NULL,
    date_paiement DATE NOT NULL DEFAULT CURRENT_DATE,
    mode_paiement mode_paiement NOT NULL,
    montant NUMERIC(15,2) NOT NULL,
    devise VARCHAR(3) NOT NULL DEFAULT 'XOF',
    taux_change NUMERIC(15,6) NOT NULL DEFAULT 1,
    reference_externe VARCHAR(100),
    statut statut_paiement NOT NULL DEFAULT 'EN_ATTENTE',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at TIMESTAMPTZ,
    version INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT chk_pay_montant CHECK (montant > 0),
    CONSTRAINT uq_pay_numero UNIQUE (numero),
    CONSTRAINT fk_pay_facture FOREIGN KEY (facture_id) REFERENCES factures_clients(id) ON DELETE RESTRICT,
    CONSTRAINT fk_pay_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT
);
CREATE INDEX idx_pay_facture ON paiements_clients (facture_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_pay_client ON paiements_clients (client_id, date_paiement DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_pay_statut ON paiements_clients (statut) WHERE deleted_at IS NULL;

-- SECTION 3 — SÉQUENCES
INSERT INTO numero_sequences (type_document, prefixe, annee, dernier_numero, format)
VALUES
    ('CLIENT', 'CLI', EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}'),
    ('PAIEMENT_CLIENT', 'PAY', EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}')
ON CONFLICT (type_document, annee) DO NOTHING;

-- SECTION 4 — TRIGGERS
SELECT attacher_triggers_standard('clients');
SELECT attacher_triggers_standard('tarifs_clients');
SELECT attacher_triggers_standard('devis');
SELECT attacher_triggers_standard('devis_lignes');
SELECT attacher_triggers_standard('commandes_clients');
SELECT attacher_triggers_standard('commande_lignes');
SELECT attacher_triggers_standard('bons_livraison');
SELECT attacher_triggers_standard('bon_livraison_lignes');
SELECT attacher_triggers_standard('factures_clients');
SELECT attacher_triggers_standard('facture_lignes');
SELECT attacher_triggers_standard('avoirs_clients');
SELECT attacher_triggers_standard('paiements_clients');

-- SECTION 5 — VÉRIFICATION
DO $$
DECLARE
    v_nb_tables INTEGER;
    v_nb_sequences INTEGER;
    v_nb_fk INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_nb_tables FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name IN ('clients','tarifs_clients','devis','devis_lignes',
        'commandes_clients','commande_lignes','bons_livraison','bon_livraison_lignes',
        'factures_clients','facture_lignes','avoirs_clients','paiements_clients');
    IF v_nb_tables <> 12 THEN RAISE EXCEPTION 'Attendu 12 tables, trouve %', v_nb_tables; END IF;
    RAISE NOTICE '12 tables Ventes verifiees';

    SELECT COUNT(*) INTO v_nb_sequences FROM numero_sequences
    WHERE type_document IN ('DEVIS','COMMANDE_CLIENT','BON_LIVRAISON','FACTURE_CLIENT','AVOIR_CLIENT','CLIENT','PAIEMENT_CLIENT');
    IF v_nb_sequences <> 7 THEN RAISE EXCEPTION 'Attendu 7 sequences, trouve %', v_nb_sequences; END IF;
    RAISE NOTICE '7 sequences Ventes verifiees';

    SELECT COUNT(*) INTO v_nb_fk FROM pg_constraint WHERE contype = 'f'
      AND conrelid::regclass::text IN ('clients','tarifs_clients','devis','devis_lignes',
        'commandes_clients','commande_lignes','bons_livraison','bon_livraison_lignes',
        'factures_clients','facture_lignes','avoirs_clients','paiements_clients');
    IF v_nb_fk < 19 THEN RAISE EXCEPTION 'Attendu au moins 19 FK, trouve %', v_nb_fk; END IF;
    RAISE NOTICE '% FK verifiees', v_nb_fk;

    RAISE NOTICE '=============================================';
    RAISE NOTICE 'V10__init_ventes.sql — Module Ventes OK';
    RAISE NOTICE '=============================================';
END;
$$;