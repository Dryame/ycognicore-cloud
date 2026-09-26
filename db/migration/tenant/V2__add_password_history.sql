-- =====================================================================
-- V2__add_password_history.sql
-- Base : ycc_tenant_<id>
-- Objet : Historique des mots de passe (NFR-SEC-09 : 5 derniers mots de passe)
-- Réf. rapport 04-78 : section 2.2
-- =====================================================================

CREATE TABLE password_history (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    hash                TEXT NOT NULL,
    date_changement     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_password_history_user ON password_history (user_id, date_changement DESC);
COMMENT ON TABLE password_history IS 'Historique des 5 derniers mots de passe (NFR-SEC-09), vérifié côté application avant tout changement.';

-- Note applicative : lors d'un changement de mot de passe, l'application
-- doit vérifier que le nouveau hash ne figure pas parmi les 5 derniers
-- enregistrements de cet utilisateur avant d'autoriser le changement.

GRANT SELECT, INSERT ON password_history TO ycc_tenant_app;   -- append-only en pratique
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ycc_tenant_app;
