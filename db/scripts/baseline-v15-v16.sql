-- Baseline manuel V15/V16 (appliquées via psql en P1, non tracées Flyway)
-- Cible : ycc_tenant_demo001, ycc_tenant_demo002
-- Idempotent : ne réinsère pas si version déjà présente

INSERT INTO flyway_schema_history
  (installed_rank, version, description, type, script, checksum, installed_by, execution_time, success)
SELECT
  (SELECT COALESCE(MAX(installed_rank), 0) FROM flyway_schema_history) + 1,
  '15', 'protect audit log from truncate', 'SQL',
  'V15__protect_audit_log_from_truncate.sql', NULL, 'baseline-manual', 0, true
WHERE NOT EXISTS (SELECT 1 FROM flyway_schema_history WHERE version = '15');

INSERT INTO flyway_schema_history
  (installed_rank, version, description, type, script, checksum, installed_by, execution_time, success)
SELECT
  (SELECT COALESCE(MAX(installed_rank), 0) FROM flyway_schema_history) + 1,
  '16', 'revoke delete strict rbac', 'SQL',
  'V16__revoke_delete_strict_rbac.sql', NULL, 'baseline-manual', 0, true
WHERE NOT EXISTS (SELECT 1 FROM flyway_schema_history WHERE version = '16');
