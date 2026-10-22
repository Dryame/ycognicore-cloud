-- ============================================================================
-- V20 : Moteur de Workflow déclaratif
-- Ref : D-P5-5, D-P5-6
-- ============================================================================

-- 1. Définition des Workflows (Déclencheurs, conditions, actions)
CREATE TABLE workflow_definitions (
    id UUID PRIMARY KEY,
    nom VARCHAR(100) NOT NULL,
    type_evenement VARCHAR(100) NOT NULL,
    conditions JSONB,
    actions JSONB NOT NULL,
    actif BOOLEAN NOT NULL DEFAULT true,
    date_creation TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    date_maj TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_workflow_type ON workflow_definitions(type_evenement) WHERE actif = true;

COMMENT ON TABLE workflow_definitions IS 'Définitions des règles de workflow (JSON déclaratif)';
COMMENT ON COLUMN workflow_definitions.conditions IS 'Conditions logiques d''évaluation (ex: data.montant > 100000)';
COMMENT ON COLUMN workflow_definitions.actions IS 'Liste des actions à exécuter (catalogue fermé)';

-- 2. Journal d'exécution des Workflows
CREATE TABLE workflow_executions (
    id UUID PRIMARY KEY,
    workflow_id UUID NOT NULL REFERENCES workflow_definitions(id) ON DELETE RESTRICT,
    event_id UUID NOT NULL,
    statut VARCHAR(20) NOT NULL CHECK (statut IN ('SUCCES', 'ECHEC', 'BOUCLE_INTERROMPUE')),
    journal JSONB,
    date_execution TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_workflow_exec_event ON workflow_executions(event_id);
CREATE INDEX idx_workflow_exec_date ON workflow_executions(date_execution);

COMMENT ON TABLE workflow_executions IS 'Historique et journal des exécutions de workflows';
COMMENT ON COLUMN workflow_executions.statut IS 'SUCCES, ECHEC ou BOUCLE_INTERROMPUE (garde anti-boucle)';
