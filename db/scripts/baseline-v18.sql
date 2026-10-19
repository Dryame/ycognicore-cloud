-- Baseline manuel V18 (control plane V9 + tenant V18)
-- Cible : tenants existants (demo001, demo002)
-- Idempotent : ne reinsere pas si version deja presente

-- V9 control plane
INSERT INTO flyway_schema_history
  (installed_rank, version, description, type, script, checksum,
   installed_by, execution_time, success)
SELECT
  (SELECT COALESCE(MAX(installed_rank), 0) FROM flyway_schema_history) + 1,
  '9', 'cles tenant', 'SQL',
  'V9__cles_tenant.sql', NULL, 'baseline-manual', 0, true
WHERE NOT EXISTS (SELECT 1 FROM flyway_schema_history WHERE version = '9');

-- V18 tenant (a executer sur chaque base tenant)
INSERT INTO flyway_schema_history
  (installed_rank, version, description, type, script, checksum,
   installed_by, execution_time, success)
SELECT
  (SELECT COALESCE(MAX(installed_rank), 0) FROM flyway_schema_history) + 1,
  '18', 'champs sensibles hmac', 'SQL',
  'V18__champs_sensibles_hmac.sql', NULL, 'baseline-manual', 0, true
WHERE NOT EXISTS (SELECT 1 FROM flyway_schema_history WHERE version = '18');
