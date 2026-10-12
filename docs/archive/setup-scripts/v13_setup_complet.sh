#!/bin/bash
# ============================================================================
# v13_setup_complet.sh — V13 Ventes (13 tables)
# ============================================================================
set -e

DB="${1:-ycc_tenant_demo001}"
PG_HOST="${PG_HOST:-localhost}"
PG_USER="${PG_USER:-postgres}"
REPO_DIR="$HOME/projets/ycognicore-cloud"
LOG_DIR="/tmp/v13_logs_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$LOG_DIR"

echo "=============================================="
echo "V13 VENTES — SETUP COMPLET"
echo "=============================================="
echo "Base : $DB | Logs : $LOG_DIR"
echo ""

cd "$REPO_DIR"

# ETAPE 1 — Fichiers
echo "[1/5] Verification des fichiers source..."
[ -f "db/migration/tenant/V13__ventes.sql" ] || { echo "KO : V13__ventes.sql manquant"; exit 1; }
echo "  OK : V13__ventes.sql"
[ -f "db/scripts/test_v13_migration.sql" ] || { echo "KO : test_v13_migration.sql manquant"; exit 1; }
echo "  OK : test_v13_migration.sql"
echo ""

# ETAPE 2 — Prérequis
echo "[2/5] Verification des prerequis..."
psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -c "SELECT 1;" > /dev/null 2>&1 || { echo "KO : connexion"; exit 1; }
echo "  OK : connexion PostgreSQL"

for T in fichiers tiers articles prospects; do
    C=$(psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -t -c "
    SELECT COUNT(*) FROM information_schema.tables WHERE table_name='$T' AND table_schema='public';" | tr -d ' ')
    if [ "$C" != "1" ]; then echo "KO : table $T manquante (V9-V12 requis)"; exit 1; fi
    echo "  OK : $T presente"
done

V13_COUNT=$(psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -t -c "
SELECT COUNT(*) FROM information_schema.tables
WHERE table_name IN ('documents_vente','paiements','listes_prix') AND table_schema='public';" | tr -d ' ')
if [ "$V13_COUNT" != "0" ]; then
    echo "  Suppression des tables V13 existantes..."
    psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -c "
    DROP TABLE IF EXISTS relances_factures CASCADE;
    DROP TABLE IF EXISTS paiements_allocations CASCADE;
    DROP TABLE IF EXISTS paiements CASCADE;
    DROP TABLE IF EXISTS validations_documents CASCADE;
    DROP TABLE IF EXISTS circuits_validation CASCADE;
    DROP TABLE IF EXISTS promotions CASCADE;
    DROP TABLE IF EXISTS lignes_tarif CASCADE;
    DROP TABLE IF EXISTS listes_prix CASCADE;
    DROP TABLE IF EXISTS documents_vente_historique_statuts CASCADE;
    DROP TABLE IF EXISTS documents_vente_liens CASCADE;
    DROP TABLE IF EXISTS documents_vente_lignes CASCADE;
    DROP TABLE IF EXISTS documents_vente CASCADE;
    DROP TABLE IF EXISTS sequences_documents CASCADE;
    DROP FUNCTION IF EXISTS prochain_numero_document(VARCHAR, INTEGER) CASCADE;
    DROP FUNCTION IF EXISTS tracer_changement_statut_document() CASCADE;
    DROP FUNCTION IF EXISTS empecher_modification_doc_hist() CASCADE;"
fi
echo "  OK : V13 non applique"
echo ""

# ETAPE 3 — Migration
echo "[3/5] Application de V13..."
psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -f db/migration/tenant/V13__ventes.sql 2>&1 | tee "$LOG_DIR/migration.log" | tail -5
grep -q "V13__ventes.sql — Module Ventes OK" "$LOG_DIR/migration.log" || { echo "KO migration"; exit 1; }
echo "  OK : migration reussie"
echo ""

# ETAPE 4 — Tests
echo "[4/5] Execution des tests..."
psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -f db/scripts/test_v13_migration.sql 2>&1 | tee "$LOG_DIR/tests.log" | tail -8
grep -q "TOUS LES TESTS PASSENT" "$LOG_DIR/tests.log" || { echo "KO tests"; exit 1; }
echo "  OK : tous les tests passent"
echo ""

# ETAPE 5 — Résumé
echo "[5/5] Resume"
echo ""
echo "  Tables V13 (13 attendues) :"
psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -t -c "
SELECT '    ' || tablename FROM pg_tables
WHERE schemaname='public' AND tablename IN (
    'sequences_documents','documents_vente','documents_vente_lignes',
    'documents_vente_liens','documents_vente_historique_statuts',
    'listes_prix','lignes_tarif','promotions',
    'circuits_validation','validations_documents',
    'paiements','paiements_allocations','relances_factures')
ORDER BY tablename;"

echo ""
echo "=============================================="
echo "V13 VENTES TERMINE AVEC SUCCES"
echo "=============================================="
echo "Base          : $DB"
echo "Tables creees : 13"
echo "Logs          : $LOG_DIR"
echo "=============================================="
