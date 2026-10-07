-- ============================================================================
-- V8__init_phase2_socle.sql — Socle Phase 2 (Bloc 1.1)
-- Base : ycc_tenant_<id>
-- ============================================================================
SET search_path TO public;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- SECTION 1 — 27 TYPES ENUM

-- CRM (4)
CREATE TYPE statut_piste AS ENUM ('NOUVEAU','CONTACTE','QUALIFIE','CONVERTI','PERDU');
CREATE TYPE statut_opportunite AS ENUM ('OUVERTE','EN_NEGOCIATION','GAGNEE','PERDUE','ABANDONNEE');
CREATE TYPE type_activite AS ENUM ('APPEL','EMAIL','RDV','VISITE','TACHE','NOTE');
CREATE TYPE etape_pipeline AS ENUM ('PROSPECTION','QUALIFICATION','PROPOSITION','NEGOCIATION','CLOTURE');

-- Ventes (6)
CREATE TYPE statut_devis AS ENUM ('BROUILLON','ENVOYE','ACCEPTE','REFUSE','EXPIRE','CONVERTI');
CREATE TYPE statut_commande AS ENUM ('BROUILLON','CONFIRMEE','EN_PREPARATION','EXPEDIEE','LIVREE','ANNULEE');
CREATE TYPE statut_livraison AS ENUM ('PREPARATION','EXPEDITION','LIVREE','RETOURNEE');
CREATE TYPE statut_facture AS ENUM ('BROUILLON','EMISE','PARTIELLEMENT_PAYEE','PAYEE','IMPAYEE','ANNULEE');
CREATE TYPE mode_paiement AS ENUM ('ESPECES','CHEQUE','VIREMENT','MOBILE_MONEY','CARTE_BANCAIRE','TRAITE','COMPENSATION');
CREATE TYPE statut_paiement AS ENUM ('EN_ATTENTE','VALIDE','REJETE','REMBOURSE');

-- Achats (4)
CREATE TYPE statut_demande_achat AS ENUM ('BROUILLON','SOUMISE','VALIDEE','REFUSEE','CONVERTIE');
CREATE TYPE statut_commande_fournisseur AS ENUM ('BROUILLON','ENVOYEE','CONFIRMEE','RECUE_PARTIELLE','RECUE','ANNULEE');
CREATE TYPE statut_reception AS ENUM ('ATTENDUE','PARTIELLE','COMPLETE','REJETEE');
CREATE TYPE statut_facture_fournisseur AS ENUM ('RECUE','VERIFIEE','VALIDEE','PAYEE','LITIGE');

-- Stocks (3)
CREATE TYPE type_mouvement AS ENUM ('ENTREE','SORTIE','TRANSFERT','AJUSTEMENT','INVENTAIRE');
CREATE TYPE type_inventaire AS ENUM ('TOURNANT','PARTIEL','SPOT','ANNUEL');
CREATE TYPE statut_inventaire AS ENUM ('EN_COURS','TERMINE','VALIDE','ANNULE');

-- Comptabilité (4)
CREATE TYPE type_journal AS ENUM ('ACHAT','VENTE','BANQUE','CAISSE','OD','ANOUVEAU','STOCK','PAIE');
CREATE TYPE sens_ecriture AS ENUM ('DEBIT','CREDIT');
CREATE TYPE statut_lettrage AS ENUM ('NON_LETTRE','PARTIELLEMENT_LETTRE','LETTRE');
CREATE TYPE type_declaration AS ENUM ('TVA','IS','CNSS','IRPP','RTS','PATENTE');

-- Trésorerie (3)
CREATE TYPE type_compte AS ENUM ('BANQUE','CAISSE','MOBILE_MONEY');
CREATE TYPE type_mouvement_tresorerie AS ENUM ('ENCAISSEMENT','DECAISSEMENT','VIREMENT_INTERNE');
CREATE TYPE statut_cheque AS ENUM ('EMIS','RECU','ENCAISSE','REJETE','ANNULE');

-- Projets (3)
CREATE TYPE statut_projet AS ENUM ('PLANIFIE','EN_COURS','SUSPENDU','TERMINE','ANNULE');
CREATE TYPE statut_tache AS ENUM ('A_FAIRE','EN_COURS','EN_REVISION','TERMINEE','BLOQUEE');
CREATE TYPE priorite_tache AS ENUM ('BASSE','NORMALE','HAUTE','CRITIQUE');

-- SECTION 2 — TYPES COMPOSITES JSONB
CREATE TYPE adresse_complete AS (
    rue TEXT, ville VARCHAR(100), region VARCHAR(100),
    pays VARCHAR(100), code_postal VARCHAR(20)
);
CREATE TYPE coordonnees_bancaires AS (
    banque VARCHAR(100), agence VARCHAR(100), rib VARCHAR(50),
    iban VARCHAR(50), swift VARCHAR(20), titulaire VARCHAR(255)
);

-- SECTION 3 — CONTEXTE UTILISATEUR
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS UUID AS $$
DECLARE v_user_id TEXT;
BEGIN
    v_user_id := current_setting('app.current_user_id', true);
    IF v_user_id IS NULL OR v_user_id = '' THEN RETURN NULL; END IF;
    RETURN v_user_id::UUID;
EXCEPTION WHEN OTHERS THEN RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION set_current_user(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user_id', p_user_id::TEXT, true);
END;
$$ LANGUAGE plpgsql;

-- SECTION 4 — FONCTIONS UTILITAIRES
CREATE OR REPLACE FUNCTION maj_date_maj()
RETURNS TRIGGER AS $$
BEGIN NEW.date_maj := now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION empecher_suppression_physique()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Suppression physique interdite sur %. Utilisez le soft delete.', TG_TABLE_NAME;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger_audit_temporel()
RETURNS TRIGGER AS $$
BEGIN
    NEW.date_maj := now();
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name = TG_TABLE_NAME AND column_name = 'updated_by') THEN
        IF current_user_id() IS NOT NULL THEN NEW.updated_by := current_user_id(); END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION restaurer_element_supprime(p_table_name TEXT, p_id UUID)
RETURNS VOID AS $$
DECLARE v_sql TEXT;
BEGIN
    v_sql := format('UPDATE %I SET date_suppression = NULL, date_maj = now() WHERE id = $1', p_table_name);
    EXECUTE v_sql USING p_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION soft_delete_element(p_table_name TEXT, p_id UUID)
RETURNS VOID AS $$
DECLARE v_sql TEXT;
BEGIN
    v_sql := format('UPDATE %I SET date_suppression = now(), date_maj = now() WHERE id = $1', p_table_name);
    EXECUTE v_sql USING p_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION attacher_triggers_standard(p_table_name TEXT)
RETURNS VOID AS $$
DECLARE v_has_date_maj BOOLEAN; v_has_date_suppr BOOLEAN;
BEGIN
    SELECT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = p_table_name AND column_name = 'date_maj') INTO v_has_date_maj;
    SELECT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = p_table_name AND column_name = 'date_suppression') INTO v_has_date_suppr;

    IF v_has_date_maj THEN
        EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_audit_temporel ON %I; ' ||
                       'CREATE TRIGGER trg_%s_audit_temporel BEFORE UPDATE ON %I ' ||
                       'FOR EACH ROW EXECUTE FUNCTION trigger_audit_temporel();',
                       p_table_name, p_table_name, p_table_name, p_table_name);
    END IF;

    IF v_has_date_suppr THEN
        EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_no_hard_delete ON %I; ' ||
                       'CREATE TRIGGER trg_%s_no_hard_delete BEFORE DELETE ON %I ' ||
                       'FOR EACH ROW EXECUTE FUNCTION empecher_suppression_physique();',
                       p_table_name, p_table_name, p_table_name, p_table_name);
    END IF;
END;
$$ LANGUAGE plpgsql;

-- SECTION 5 — SÉQUENCES DE NUMÉROTATION (15 types)
INSERT INTO numero_sequences (type_document, prefixe, annee, dernier_numero, format)
VALUES
    ('DEVIS',                'DEV', EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}'),
    ('COMMANDE_CLIENT',      'BC',  EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}'),
    ('BON_LIVRAISON',        'BL',  EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}'),
    ('FACTURE_CLIENT',       'FAC', EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}'),
    ('AVOIR_CLIENT',         'AV',  EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}'),
    ('DEMANDE_ACHAT',        'DA',  EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}'),
    ('COMMANDE_FOURNISSEUR', 'CF',  EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}'),
    ('RECEPTION',            'REC', EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}'),
    ('FACTURE_FOURNISSEUR',  'FF',  EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}'),
    ('AVOIR_FOURNISSEUR',    'AF',  EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}'),
    ('MOUVEMENT_STOCK',      'MVT', EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}'),
    ('INVENTAIRE',           'INV', EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}'),
    ('ECRITURE_COMPTABLE',   'EC',  EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}'),
    ('BON_CAISSE',           'BCS', EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}'),
    ('PROJET',               'PRJ', EXTRACT(YEAR FROM CURRENT_DATE)::INT, 0, '{PREFIXE}-{ANNEE}-{NUMERO:06d}')
ON CONFLICT (type_document, annee) DO NOTHING;

-- SECTION 6 — PERMISSIONS
GRANT USAGE ON SCHEMA public TO ycc_tenant_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO ycc_tenant_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO ycc_tenant_app;
GRANT EXECUTE ON FUNCTION current_user_id() TO ycc_tenant_app;
GRANT EXECUTE ON FUNCTION set_current_user(UUID) TO ycc_tenant_app;
GRANT EXECUTE ON FUNCTION restaurer_element_supprime(TEXT, UUID) TO ycc_tenant_app;
GRANT EXECUTE ON FUNCTION soft_delete_element(TEXT, UUID) TO ycc_tenant_app;
GRANT EXECUTE ON FUNCTION attacher_triggers_standard(TEXT) TO ycc_tenant_app;
