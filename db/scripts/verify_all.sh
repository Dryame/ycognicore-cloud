#!/usr/bin/env bash
# =====================================================================
# verify_all.sh — Vérification complète des migrations
# Usage : ./db/scripts/verify_all.sh
# =====================================================================
set -euo pipefail

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_ADMIN_USER:-postgres}"
CP_DB="${CONTROL_PLANE_DB:-ycc_control_plane}"
TENANT_DB="${TENANT_DB:-ycc_tenant_demo001}"

echo "═══════════════════════════════════════════════════════"
echo "  VÉRIFICATION GLOBALE PHASE 1"
echo "═══════════════════════════════════════════════════════"
echo "  Host     : $PG_HOST:$PG_PORT"
echo "  Control  : $CP_DB"
echo "  Tenant   : $TENANT_DB"
echo "═══════════════════════════════════════════════════════"
echo ""

# Vérification Control Plane
if psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -lqt | cut -d\| -f1 | grep -qw "$CP_DB"; then
    echo "[1/2] Tests Control Plane"
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$CP_DB" \
        -f "$(dirname "$0")/test_migrations.sql"
else
    echo "[1/2] ⚠ Base $CP_DB absente — skip"
fi

echo ""

# Vérification Tenant
if psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -lqt | cut -d\| -f1 | grep -qw "$TENANT_DB"; then
    echo "[2/2] Tests Tenant"
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$TENANT_DB" \
        -f "$(dirname "$0")/test_migrations_tenant.sql"
else
    echo "[2/2] ⚠ Base $TENANT_DB absente — skip"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  VÉRIFICATION TERMINÉE"
echo "═══════════════════════════════════════════════════════"
