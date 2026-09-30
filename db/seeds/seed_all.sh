#!/usr/bin/env bash
# =====================================================================
# seed_all.sh — Orchestrateur de seeds
# Usage : ./db/seeds/seed_all.sh
# =====================================================================
set -euo pipefail

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_ADMIN_USER:-postgres}"
CP_DB="${CONTROL_PLANE_DB:-ycc_control_plane}"
TENANT_DB="${TENANT_DB:-ycc_tenant_demo001}"

echo "═══════════════════════════════════════════════════════"
echo "  SEED yCogniCore Cloud — Phase 1"
echo "═══════════════════════════════════════════════════════"
echo "  Host     : $PG_HOST:$PG_PORT"
echo "  Control  : $CP_DB"
echo "  Tenant   : $TENANT_DB"
echo "═══════════════════════════════════════════════════════"

echo ""
echo "[1/2] Seed control plane ($CP_DB)"
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$CP_DB" \
    -f "$(dirname "$0")/seed_control_plane.sql"

echo ""
echo "[2/2] Seed tenant ($TENANT_DB)"
if psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -lqt | cut -d\| -f1 | grep -qw "$TENANT_DB"; then
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$TENANT_DB" \
        -f "$(dirname "$0")/seed_tenant.sql"
else
    echo "  ⚠ Base $TENANT_DB absente — exécuter d'abord provisioning_tenant.py"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  SEED TERMINÉ"
echo "═══════════════════════════════════════════════════════"
