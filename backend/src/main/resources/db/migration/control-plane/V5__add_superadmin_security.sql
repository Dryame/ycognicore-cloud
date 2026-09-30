-- =====================================================================
-- V5__add_superadmin_security.sql
-- Base : ycc_control_plane
-- Objet : Sécurité Superadmin (4 tables + trigger verrouillage)
-- Réf.  : ADR-003, NFR-SEC-09, NFR-SEC-10, NFR-SEC-11, NFR-SEC-16
-- =====================================================================

CREATE TABLE IF NOT EXISTS superadmin_password_history (
    id              BIGSERIAL PRIMARY KEY,
    superadmin_id   UUID NOT NULL REFERENCES superadmin_users(id) ON DELETE CASCADE,
    hash            TEXT NOT NULL,
    date_changement TIMESTAMPTZ NOT NULL DEFAULT now(),
    change_par      UUID REFERENCES superadmin_users(id)
);

CREATE INDEX IF NOT EXISTS idx_sa_pwd_history ON superadmin_password_history (superadmin_id, date_changement DESC);

CREATE OR REPLACE FUNCTION empecher_modification_sa_pwd_history()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Table superadmin_password_history : append-only';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sa_pwd_history_append_only ON superadmin_password_history;
CREATE TRIGGER trg_sa_pwd_history_append_only
BEFORE UPDATE OR DELETE ON superadmin_password_history
FOR EACH ROW EXECUTE FUNCTION empecher_modification_sa_pwd_history();

CREATE TABLE IF NOT EXISTS superadmin_login_attempts (
    id              BIGSERIAL,
    email           CITEXT NOT NULL,
    superadmin_id   UUID REFERENCES superadmin_users(id) ON DELETE CASCADE,
    timestamp       TIMESTAMPTZ NOT NULL DEFAULT now(),
    succes          BOOLEAN NOT NULL,
    ip              INET NOT NULL,
    user_agent      TEXT,
    raison_echec    VARCHAR(50)
        CHECK (raison_echec IN ('MOT_DE_PASSE','MFA','COMPTE_VERROUILLE','COMPTE_INEXISTANT')),
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

CREATE TABLE IF NOT EXISTS superadmin_login_attempts_default
    PARTITION OF superadmin_login_attempts DEFAULT;

CREATE INDEX IF NOT EXISTS idx_sa_login_email_ts ON superadmin_login_attempts (email, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_sa_login_sa_ts ON superadmin_login_attempts (superadmin_id, timestamp DESC);

CREATE TABLE IF NOT EXISTS superadmin_sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    superadmin_id       UUID NOT NULL REFERENCES superadmin_users(id) ON DELETE CASCADE,
    token_hash          TEXT NOT NULL,
    refresh_token_hash  TEXT,
    mfa_verifie         BOOLEAN NOT NULL DEFAULT FALSE,
    ip                  INET NOT NULL,
    user_agent          TEXT,
    device_id           VARCHAR(255),
    device_name         VARCHAR(100),
    date_ouverture      TIMESTAMPTZ NOT NULL DEFAULT now(),
    date_fermeture      TIMESTAMPTZ,
    motif_fermeture     VARCHAR(30)
        CHECK (motif_fermeture IN ('LOGOUT','EXPIRATION','REVOCATION_ADMIN'))
);

CREATE INDEX IF NOT EXISTS idx_sa_sessions ON superadmin_sessions (superadmin_id, date_ouverture DESC);

CREATE TABLE IF NOT EXISTS superadmin_audit_log (
    id              BIGSERIAL,
    superadmin_id   UUID REFERENCES superadmin_users(id),
    session_id      UUID REFERENCES superadmin_sessions(id),
    action          VARCHAR(100) NOT NULL,
    entite          VARCHAR(100) NOT NULL,
    entite_id       UUID,
    timestamp       TIMESTAMPTZ NOT NULL DEFAULT now(),
    ip              INET NOT NULL,
    user_agent      TEXT,
    niveau          VARCHAR(20) NOT NULL DEFAULT 'INFO'
        CHECK (niveau IN ('INFO','WARN','ERROR','SECURITE')),
    succes          BOOLEAN NOT NULL DEFAULT TRUE,
    avant           JSONB,
    apres           JSONB,
    details         JSONB,
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

CREATE TABLE IF NOT EXISTS superadmin_audit_log_default
    PARTITION OF superadmin_audit_log DEFAULT;

CREATE INDEX IF NOT EXISTS idx_sa_audit_sa ON superadmin_audit_log (superadmin_id);
CREATE INDEX IF NOT EXISTS idx_sa_audit_niveau ON superadmin_audit_log (niveau, timestamp DESC);

CREATE OR REPLACE FUNCTION empecher_modification_sa_audit()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Table superadmin_audit_log : append-only';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sa_audit_immuable ON superadmin_audit_log;
CREATE TRIGGER trg_sa_audit_immuable
BEFORE UPDATE OR DELETE ON superadmin_audit_log
FOR EACH ROW EXECUTE FUNCTION empecher_modification_sa_audit();

CREATE OR REPLACE FUNCTION verrouiller_superadmin_apres_echecs()
RETURNS TRIGGER AS $$
DECLARE
    v_echecs INTEGER;
BEGIN
    IF NEW.succes = FALSE AND NEW.superadmin_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_echecs
        FROM (
            SELECT succes FROM superadmin_login_attempts
            WHERE superadmin_id = NEW.superadmin_id
            ORDER BY timestamp DESC LIMIT 5
        ) sub WHERE succes = FALSE;

        IF v_echecs >= 5 THEN
            UPDATE superadmin_users
            SET statut = 'VERROUILLE', date_maj = now()
            WHERE id = NEW.superadmin_id AND statut = 'ACTIF';

            INSERT INTO alertes_securite (
                type_alerte, severite, description, ip, user_id
            ) VALUES (
                'ECHEC_AUTH_REPETE_SUPERADMIN', 'CRITIQUE',
                format('Superadmin %s verrouille apres 5 echecs', NEW.email),
                NEW.ip, NEW.superadmin_id
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_verrouillage_sa ON superadmin_login_attempts;
CREATE TRIGGER trg_verrouillage_sa
AFTER INSERT ON superadmin_login_attempts
FOR EACH ROW EXECUTE FUNCTION verrouiller_superadmin_apres_echecs();

GRANT SELECT, INSERT, UPDATE, DELETE ON superadmin_password_history, superadmin_sessions TO ycc_control_plane_app;
GRANT SELECT, INSERT ON superadmin_login_attempts, superadmin_audit_log TO ycc_control_plane_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ycc_control_plane_app;
