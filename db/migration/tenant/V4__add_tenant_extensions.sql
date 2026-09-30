-- =====================================================================
-- V4__add_tenant_extensions.sql
-- Base : ycc_tenant_<id>
-- Objet : Extensions tenant (numérotation, paiements, invitations)
-- Réf.  : P2, P3, P9, ADR-001, NFR-CONF-01, NFR-SEC-26
-- =====================================================================

CREATE TABLE IF NOT EXISTS numero_sequences (
    id              SERIAL PRIMARY KEY,
    type_document   VARCHAR(50) NOT NULL,
    prefixe         VARCHAR(20) NOT NULL,
    annee           INTEGER NOT NULL,
    dernier_numero  INTEGER NOT NULL DEFAULT 0 CHECK (dernier_numero >= 0),
    format          VARCHAR(100) NOT NULL DEFAULT '{PREFIXE}-{ANNEE}-{NUMERO:06d}',
    date_maj        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_tenant_numero_seq UNIQUE (type_document, annee)
);

INSERT INTO numero_sequences (type_document, prefixe, annee) VALUES
    ('DEVIS',          'DEV', EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER),
    ('BON_COMMANDE',   'BC',  EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER),
    ('BON_LIVRAISON',  'BL',  EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER),
    ('FACTURE_CLIENT', 'FAC', EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER),
    ('AVOIR',          'AV',  EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER)
ON CONFLICT (type_document, annee) DO NOTHING;

CREATE OR REPLACE FUNCTION prochain_numero(p_type_document VARCHAR, p_annee INTEGER)
RETURNS VARCHAR AS $$
DECLARE
    v_prefixe VARCHAR(20);
    v_format  VARCHAR(100);
    v_numero  INTEGER;
BEGIN
    UPDATE numero_sequences
    SET dernier_numero = dernier_numero + 1, date_maj = now()
    WHERE type_document = p_type_document AND annee = p_annee
    RETURNING prefixe, format, dernier_numero INTO v_prefixe, v_format, v_numero;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Séquence introuvable : % / %', p_type_document, p_annee;
    END IF;

    RETURN replace(
        replace(replace(v_format, '{PREFIXE}', v_prefixe), '{ANNEE}', p_annee::TEXT),
        '{NUMERO:06d}', lpad(v_numero::TEXT, 6, '0')
    );
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS payment_transactions (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregateur       VARCHAR(30) NOT NULL CHECK (aggregateur IN ('PAYDUNYA','LIGDICASH')),
    reference_externe VARCHAR(150) NOT NULL UNIQUE,
    montant           NUMERIC(12,2) NOT NULL CHECK (montant >= 0),
    devise            VARCHAR(3) NOT NULL DEFAULT 'XOF',
    mode_paiement     VARCHAR(30) NOT NULL CHECK (mode_paiement IN ('MOBILE_MONEY','CARTE_BANCAIRE')),
    operateur         VARCHAR(30),
    facture_source    VARCHAR(50),
    statut            VARCHAR(30) NOT NULL DEFAULT 'INITIEE'
        CHECK (statut IN ('INITIEE','EN_ATTENTE','REUSSIE','ECHOUEE','ANNULEE','REMBOURSEE')),
    date_initiation   TIMESTAMPTZ NOT NULL DEFAULT now(),
    date_confirmation TIMESTAMPTZ,
    payload_retour    JSONB
);

CREATE INDEX IF NOT EXISTS idx_tenant_payment_statut ON payment_transactions (statut, date_initiation DESC);

CREATE TABLE IF NOT EXISTS webhook_events (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregateur       VARCHAR(30) NOT NULL,
    event_id_externe  VARCHAR(150) NOT NULL,
    signature         VARCHAR(500),
    payload_brut      JSONB NOT NULL,
    statut_traitement VARCHAR(30) NOT NULL DEFAULT 'RECU'
        CHECK (statut_traitement IN ('RECU','TRAITE','REJETE','DOUBLON')),
    date_reception    TIMESTAMPTZ NOT NULL DEFAULT now(),
    date_traitement   TIMESTAMPTZ,
    erreur            TEXT,
    CONSTRAINT uq_tenant_webhook UNIQUE (aggregateur, event_id_externe)
);

CREATE TABLE IF NOT EXISTS user_invitations (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email            CITEXT NOT NULL,
    token_hash       TEXT NOT NULL UNIQUE,
    role_id          UUID REFERENCES roles(id) ON DELETE SET NULL,
    invite_par       UUID NOT NULL REFERENCES users(id),
    date_expiration  TIMESTAMPTZ NOT NULL,
    statut           VARCHAR(20) NOT NULL DEFAULT 'EN_ATTENTE'
        CHECK (statut IN ('EN_ATTENTE','ACCEPTEE','EXPIREE','REVOQUEE')),
    date_creation    TIMESTAMPTZ NOT NULL DEFAULT now(),
    date_acceptation TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_invitations_email ON user_invitations (email, statut);
CREATE INDEX IF NOT EXISTS idx_invitations_expiration ON user_invitations (date_expiration) WHERE statut = 'EN_ATTENTE';

GRANT SELECT, INSERT, UPDATE, DELETE ON numero_sequences, user_invitations TO ycc_tenant_app;
GRANT SELECT, INSERT ON payment_transactions, webhook_events TO ycc_tenant_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ycc_tenant_app;
GRANT EXECUTE ON FUNCTION prochain_numero(VARCHAR, INTEGER) TO ycc_tenant_app;
