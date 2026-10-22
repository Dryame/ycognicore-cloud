-- ============================================================================
-- V19 : Transactional Outbox et Idempotence des consommateurs
-- Ref : D-P5-2, D-P5-4
-- ============================================================================

-- 1. Table Outbox (Écriture dans la même transaction que le métier)
CREATE TABLE outbox_events (
    id UUID PRIMARY KEY,
    type VARCHAR(100) NOT NULL,
    aggregat_type VARCHAR(100) NOT NULL,
    aggregat_id UUID NOT NULL,
    payload JSONB NOT NULL,
    statut VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (statut IN ('PENDING', 'PUBLISHED', 'FAILED')),
    tentatives INT NOT NULL DEFAULT 0,
    date_creation TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    date_publication TIMESTAMP WITH TIME ZONE
);

-- Index partiel pour optimiser le polling du scheduler (ne lit que les PENDING)
CREATE INDEX idx_outbox_pending ON outbox_events(date_creation) WHERE statut = 'PENDING';

COMMENT ON TABLE outbox_events IS 'File d''attente transactionnelle des événements à publier sur RabbitMQ';
COMMENT ON COLUMN outbox_events.payload IS 'Charge utile de l''événement au format JSON (CloudEvents)';

-- 2. Table d'idempotence (Empêche le traitement en double d'un même événement)
CREATE TABLE evenements_traites (
    event_id UUID NOT NULL,
    consommateur VARCHAR(100) NOT NULL,
    date_traitement TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (event_id, consommateur)
);

COMMENT ON TABLE evenements_traites IS 'Registre des événements déjà traités par chaque consommateur (At-least-once delivery)';
