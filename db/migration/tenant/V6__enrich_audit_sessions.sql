-- =====================================================================
-- V6__enrich_audit_sessions.sql
-- Base : ycc_tenant_<id>
-- Objet : Enrichissements sessions_history, audit_log, password_history
-- Réf.  : P8, ADR-001, NFR-SEC-16, NFR-SEC-11, NFR-SEC-09
-- =====================================================================

ALTER TABLE sessions_history
    ADD COLUMN IF NOT EXISTS refresh_token_hash TEXT,
    ADD COLUMN IF NOT EXISTS mfa_verifie        BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS device_id          VARCHAR(255),
    ADD COLUMN IF NOT EXISTS device_name        VARCHAR(100);

ALTER TABLE audit_log
    ADD COLUMN IF NOT EXISTS session_id UUID REFERENCES sessions_history(id),
    ADD COLUMN IF NOT EXISTS module_id  INTEGER REFERENCES modules(id),
    ADD COLUMN IF NOT EXISTS user_agent TEXT,
    ADD COLUMN IF NOT EXISTS niveau     VARCHAR(20) NOT NULL DEFAULT 'INFO',
    ADD COLUMN IF NOT EXISTS succes     BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS avant      JSONB,
    ADD COLUMN IF NOT EXISTS apres      JSONB;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_audit_niveau') THEN
        ALTER TABLE audit_log ADD CONSTRAINT chk_audit_niveau
        CHECK (niveau IN ('INFO','WARN','ERROR','SECURITE'));
    END IF;
END $$;

COMMENT ON COLUMN audit_log.module_id IS 'Nullable : NULL pour les actions transversales.';

CREATE INDEX IF NOT EXISTS idx_audit_module_ts ON audit_log (module_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_niveau_ts ON audit_log (niveau, timestamp DESC) WHERE niveau != 'INFO';

ALTER TABLE password_history
    ADD COLUMN IF NOT EXISTS change_par UUID REFERENCES users(id),
    ADD COLUMN IF NOT EXISTS motif      VARCHAR(50);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_pwd_history_motif') THEN
        ALTER TABLE password_history ADD CONSTRAINT chk_pwd_history_motif
        CHECK (motif IS NULL OR motif IN ('VOLONTAIRE','FORCE','EXPIRATION'));
    END IF;
END $$;

CREATE OR REPLACE FUNCTION empecher_modification_pwd_history()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Table password_history : append-only';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_password_history_append_only ON password_history;
CREATE TRIGGER trg_password_history_append_only
BEFORE UPDATE OR DELETE ON password_history
FOR EACH ROW EXECUTE FUNCTION empecher_modification_pwd_history();

GRANT SELECT, INSERT, UPDATE ON sessions_history TO ycc_tenant_app;
GRANT SELECT, INSERT ON audit_log, password_history TO ycc_tenant_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ycc_tenant_app;
