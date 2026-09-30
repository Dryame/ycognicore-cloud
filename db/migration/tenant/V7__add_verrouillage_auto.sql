-- =====================================================================
-- V7__add_verrouillage_auto.sql
-- Base : ycc_tenant_<id>
-- Objet : Trigger de verrouillage automatique + enrichissements
-- Réf.  : ADR-003, NFR-SEC-10
-- =====================================================================

ALTER TABLE login_attempts
    ADD COLUMN IF NOT EXISTS user_agent   TEXT,
    ADD COLUMN IF NOT EXISTS raison_echec VARCHAR(50),
    ADD COLUMN IF NOT EXISTS pays         VARCHAR(100);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_login_raison_echec') THEN
        ALTER TABLE login_attempts ADD CONSTRAINT chk_login_raison_echec
        CHECK (raison_echec IS NULL OR raison_echec IN ('MOT_DE_PASSE','MFA','COMPTE_VERROUILLE','COMPTE_INEXISTANT'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_login_attempts_email_ts ON login_attempts (email, timestamp DESC);

CREATE OR REPLACE FUNCTION verrouiller_compte_apres_echecs()
RETURNS TRIGGER AS $$
DECLARE
    v_echecs INTEGER;
BEGIN
    IF NEW.succes = FALSE THEN
        SELECT COUNT(*) INTO v_echecs
        FROM (
            SELECT succes FROM login_attempts
            WHERE email = NEW.email
            ORDER BY timestamp DESC LIMIT 5
        ) sub WHERE succes = FALSE;

        IF v_echecs >= 5 THEN
            UPDATE users
            SET statut = 'VERROUILLE',
                date_verrouillage = now(),
                motif_verrouillage = 'Echecs repetes'
            WHERE email = NEW.email AND statut = 'ACTIF';

            INSERT INTO audit_log (
                user_id, action, entite, niveau, succes, details, ip, timestamp
            ) VALUES (
                NEW.user_id, 'VERROUILLAGE_AUTO', 'users', 'SECURITE', TRUE,
                jsonb_build_object('email', NEW.email, 'nb_echecs', v_echecs),
                NEW.ip, now()
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_verrouillage_auto ON login_attempts;
CREATE TRIGGER trg_verrouillage_auto
AFTER INSERT ON login_attempts
FOR EACH ROW EXECUTE FUNCTION verrouiller_compte_apres_echecs();

CREATE OR REPLACE FUNCTION creer_partition_mensuelle_login_attempts(p_mois DATE)
RETURNS VOID AS $$
DECLARE
    v_nom   TEXT := 'login_attempts_' || to_char(p_mois, 'YYYY_MM');
    v_debut DATE := date_trunc('month', p_mois)::DATE;
    v_fin   DATE := (date_trunc('month', p_mois) + INTERVAL '1 month')::DATE;
BEGIN
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF login_attempts FOR VALUES FROM (%L) TO (%L)',
        v_nom, v_debut, v_fin
    );
END;
$$ LANGUAGE plpgsql;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ycc_tenant_app;
GRANT EXECUTE ON FUNCTION creer_partition_mensuelle_login_attempts(DATE) TO ycc_tenant_app;
