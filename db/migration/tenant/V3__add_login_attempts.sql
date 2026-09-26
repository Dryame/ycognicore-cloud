-- =====================================================================
-- V3__add_login_attempts.sql
-- Base : ycc_tenant_<id>
-- Objet : Tentatives de connexion, partitionnées par mois
--         (NFR-SEC-10 : verrouillage après 5 échecs consécutifs)
-- Réf. rapport 04-78 : section 2.2
-- =====================================================================

-- user_id est NULLABLE : si l'email saisi ne correspond à aucun compte,
-- la tentative est quand même journalisée (email seul, sans user_id) —
-- utile pour détecter les attaques par énumération d'emails.
-- Partitionnée comme audit_log : volume potentiellement élevé en cas
-- d'attaque par force brute, requêtes récentes doivent rester rapides.
CREATE TABLE login_attempts (
    id          BIGSERIAL,
    email       CITEXT NOT NULL,
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    timestamp   TIMESTAMPTZ NOT NULL DEFAULT now(),
    succes      BOOLEAN NOT NULL,
    ip          INET NOT NULL,
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

CREATE TABLE login_attempts_2026_09 PARTITION OF login_attempts
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE login_attempts_2026_10 PARTITION OF login_attempts
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE login_attempts_2026_11 PARTITION OF login_attempts
    FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE login_attempts_default PARTITION OF login_attempts DEFAULT;

CREATE INDEX idx_login_attempts_user_ts ON login_attempts (user_id, timestamp DESC);
CREATE INDEX idx_login_attempts_email_ts ON login_attempts (email, timestamp DESC);

COMMENT ON TABLE login_attempts IS 'Tentatives de connexion, partitionnées par mois (NFR-SEC-10).';
COMMENT ON COLUMN login_attempts.email IS 'Email tel que saisi, même si inconnu — permet de détecter une énumération d''emails.';
COMMENT ON COLUMN login_attempts.user_id IS 'NULL si l''email saisi ne correspond à aucun compte existant.';

-- Note applicative : compter les échecs consécutifs (succes = FALSE) des
-- 5 dernières tentatives pour cet utilisateur (via user_id si connu,
-- sinon via email). Si 5 échecs consécutifs, passer users.statut à
-- 'VERROUILLE' (déblocage manuel Admin ou délai automatique).

CREATE OR REPLACE FUNCTION creer_partition_mensuelle_login_attempts(p_mois DATE)
RETURNS VOID AS $$
DECLARE
    v_nom_partition TEXT := 'login_attempts_' || to_char(p_mois, 'YYYY_MM');
    v_debut         DATE := date_trunc('month', p_mois)::DATE;
    v_fin           DATE := (date_trunc('month', p_mois) + INTERVAL '1 month')::DATE;
BEGIN
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF login_attempts FOR VALUES FROM (%L) TO (%L)',
        v_nom_partition, v_debut, v_fin
    );
END;
$$ LANGUAGE plpgsql;

GRANT SELECT, INSERT ON login_attempts TO ycc_tenant_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ycc_tenant_app;
GRANT EXECUTE ON FUNCTION creer_partition_mensuelle_login_attempts(DATE) TO ycc_tenant_app;
