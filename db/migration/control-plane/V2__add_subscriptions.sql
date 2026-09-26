-- =====================================================================
-- V2__add_subscriptions.sql
-- Base : ycc_control_plane
-- Objet : Gestion des abonnements SaaS et facturation
-- Réf. rapport 04-78 : section 3.1.3
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table : subscriptions
-- Historique des formules d'abonnement d'un tenant
-- Utilise le type formule_abonnement défini en V1 (pas de duplication)
-- ---------------------------------------------------------------------
CREATE TABLE subscriptions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    formule             formule_abonnement NOT NULL,
    montant             NUMERIC(12, 2) NOT NULL CHECK (montant >= 0),
    devise              VARCHAR(3) NOT NULL DEFAULT 'XOF',
    renouvellement_auto BOOLEAN NOT NULL DEFAULT TRUE,
    date_debut          DATE NOT NULL,
    date_fin            DATE,
    statut              VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
                            CHECK (statut IN ('ACTIVE', 'EXPIREE', 'RESILIEE')),

    CONSTRAINT chk_dates_coherentes CHECK (date_fin IS NULL OR date_fin >= date_debut)
);

CREATE INDEX idx_subscriptions_tenant ON subscriptions (tenant_id);
COMMENT ON TABLE subscriptions IS 'Historique des formules d''abonnement souscrites par un tenant.';
COMMENT ON COLUMN subscriptions.devise IS 'Code ISO 4217 (XOF = franc CFA par défaut, contexte burkinabè).';

-- ---------------------------------------------------------------------
-- Table : subscription_invoices
-- Factures d'abonnement SaaS (paiement de la plateforme elle-même,
-- distinct des factures clientes émises DANS chaque tenant)
-- ---------------------------------------------------------------------
CREATE TABLE subscription_invoices (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    subscription_id     UUID REFERENCES subscriptions(id),
    montant_ht          NUMERIC(12, 2) NOT NULL CHECK (montant_ht >= 0),
    montant_tva         NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (montant_tva >= 0),
    montant_ttc         NUMERIC(12, 2) NOT NULL CHECK (montant_ttc >= 0),
    statut              VARCHAR(20) NOT NULL DEFAULT 'EN_ATTENTE'
                            CHECK (statut IN ('EN_ATTENTE', 'PAYEE', 'IMPAYEE', 'ANNULEE')),
    date_emission       DATE NOT NULL DEFAULT CURRENT_DATE,
    date_echeance       DATE NOT NULL,
    date_paiement       DATE,
    date_creation       TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_ttc_coherent CHECK (montant_ttc = montant_ht + montant_tva)
);

CREATE INDEX idx_subscription_invoices_tenant ON subscription_invoices (tenant_id);
CREATE INDEX idx_subscription_invoices_statut ON subscription_invoices (statut);
COMMENT ON TABLE subscription_invoices IS 'Factures d''abonnement SaaS (règlement de la plateforme elle-même).';

GRANT SELECT, INSERT, UPDATE ON subscriptions, subscription_invoices TO ycc_control_plane_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ycc_control_plane_app;
