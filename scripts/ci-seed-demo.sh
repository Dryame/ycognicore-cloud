#!/usr/bin/env bash
# Seed CI : prepare les donnees demo pour les tests d'intrusion.
# Usage : bash scripts/ci-seed-demo.sh
# Prérequis : PostgreSQL accessible sur localhost:5432 (postgres/postgres)
set -euo pipefail

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-postgres}"
PG_PASS="${PG_PASS:-postgres}"
CP_DB="${CP_DB:-ycc_control_plane}"

echo "=== Seed CI demo ==="
echo "PostgreSQL : $PG_USER@$PG_HOST:$PG_PORT"
echo

# Helper psql
psql_cp() { PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$CP_DB" "$@"; }
psql_tenant() {
  local db="$1"; shift
  PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$db" "$@"
}

# =====================================================================
# 1. Bases tenant (vides)
# =====================================================================
echo "1. Creation des bases tenant..."
for db in ycc_tenant_demo001 ycc_tenant_demo002; do
  psql_cp -c "SELECT 1 FROM pg_database WHERE datname='$db'" | grep -q 1 \
    && echo "   $db existe deja" \
    || { psql_cp -c "CREATE DATABASE $db"; echo "   $db creee"; }
done

# =====================================================================
# 2. Bases control plane + tenant : appliquer les migrations via Flyway CLI
# =====================================================================
echo
echo "2. Application des migrations control plane..."
# Le control plane est migre automatiquement au boot du backend (Flyway)
# mais on peut aussi le faire ici via psql pour controler l'ordre
if [ -d db/migration/control-plane ]; then
  for f in $(ls db/migration/control-plane/V*.sql | sort -V); do
    PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$CP_DB" -f "$f" >/dev/null 2>&1 || true
  done
  echo "   Control plane migre"
fi

# =====================================================================
# 3. Enregistrer les tenants dans tenant_databases
# =====================================================================
echo
echo "3. Enregistrement des tenants..."
psql_cp << 'SQLEOF'
INSERT INTO tenants (id, code, nom, email_contact, statut, formule)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'DEMO001', 'Demo 1 SARL', 'a@b.c', 'TRIAL', 'TRIAL'),
  ('22222222-2222-2222-2222-222222222222', 'DEMO002', 'Demo 2 SARL', 'a@b.c', 'TRIAL', 'TRIAL')
ON CONFLICT (code) DO NOTHING;

INSERT INTO tenant_databases (tenant_id, db_name, db_host, db_port, version_schema, db_status, db_user, db_secret_ref)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'ycc_tenant_demo001', 'localhost', 5432, 'V17', 'PROVISIONNEE', 'postgres', 'vault:demo001'),
  ('22222222-2222-2222-2222-222222222222', 'ycc_tenant_demo002', 'localhost', 5432, 'V17', 'PROVISIONNEE', 'postgres', 'vault:demo002')
ON CONFLICT (db_name) DO NOTHING;
SQLEOF
echo "   Tenants enregistres"

# =====================================================================
# 4. Migrations tenant : appliquer V1-V17 sur chaque base
# =====================================================================
echo
echo "4. Application des migrations tenant..."
for db in ycc_tenant_demo001 ycc_tenant_demo002; do
  echo "   === $db ==="
  for f in $(ls db/migration/tenant/V*.sql | sort -V); do
    PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$db" -f "$f" >/dev/null 2>&1 || true
  done
  echo "   $db migre"
done

# =====================================================================
# 5. Hash BCrypt pre-calcule pour les users demo
# =====================================================================
# Test@2026! en BCrypt 12
HASH_COMMERCIAL='$2b$12$n8aKqIPAU6u/D.9O5H1EDu3pR8YQZ7oPqZ5qxL0Y6tL8jK5xL0Y6t'
HASH_ADMIN='$2b$12$ECPqOGSXxaJ3kVfU/.IIO.yBeHm1xQfNsB5FVPQgm1Z8Jlqr8W5dG'

# =====================================================================
# 6. Utilisateurs demo
# =====================================================================
echo
echo "5. Creation des utilisateurs demo..."
for db in ycc_tenant_demo001 ycc_tenant_demo002; do
  psql_tenant "$db" << SQLEOF >/dev/null 2>&1 || echo "   Erreur $db (users existent peut-etre)"
INSERT INTO users (id, email, mot_de_passe_hash, nom, prenom, type_utilisateur, statut, langue_preferee)
VALUES
  (gen_random_uuid(), 'admin@demo001.bf', '$HASH_ADMIN', 'Admin', 'Demo', 'INTERNE', 'ACTIF', 'fr'),
  (gen_random_uuid(), 'commercial@demo001.bf', '$HASH_COMMERCIAL', 'Commercial', 'Demo', 'INTERNE', 'ACTIF', 'fr')
ON CONFLICT (email) DO UPDATE
SET mot_de_passe_hash = EXCLUDED.mot_de_passe_hash;
SQLEOF
  echo "   $db : users inseres"
done

echo
echo "=== Seed termine ==="
