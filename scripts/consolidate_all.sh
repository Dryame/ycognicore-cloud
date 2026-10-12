#!/bin/bash
# ============================================================================
# consolidate_all.sh
# Consolidation automatique de la Phase 2 — yCogniCore Cloud
# ============================================================================
# Vérifie l'intégrité de la fondation BDD après un vertical slice.
# Effectue 8 contrôles et produit un rapport chiffré.
#
# Usage : ./scripts/consolidate_all.sh [nom_base]
# Defaut : ycc_tenant_demo001
# ============================================================================

set -e

DB="${1:-ycc_tenant_demo001}"
PG_HOST="${PG_HOST:-localhost}"
PG_USER="${PG_USER:-postgres}"
REPO_DIR="$HOME/projets/ycognicore-cloud"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="/tmp/consolidation_${TIMESTAMP}"
REPORT_FILE="${REPORT_DIR}/rapport_consolidation.md"

mkdir -p "$REPORT_DIR"
cd "$REPO_DIR"

# ============================================================================
# UTILITAIRES
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Exécuter une requête SQL et retourner le résultat (sans espaces)
sql_value() {
    psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -t -A -c "$1" 2>/dev/null | tr -d ' \n'
}

# Exécuter une requête SQL multi-lignes
sql_query() {
    psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -c "$1" 2>/dev/null
}

# Vérifier une valeur vs attendue
check_value() {
    local label="$1"
    local actual="$2"
    local expected="$3"

    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}  ✓${NC} $label : $actual"
        echo "- ✓ $label : $actual" >> "$REPORT_FILE"
        return 0
    else
        echo -e "${RED}  ✗${NC} $label : $actual (attendu : $expected)"
        echo "- ✗ $label : $actual (attendu : $expected)" >> "$REPORT_FILE"
        return 1
    fi
}

# Ligne de rapport générique (informatif)
report_line() {
    echo "$1"
    echo "$1" >> "$REPORT_FILE"
}

# ============================================================================
# EN-TÊTE
# ============================================================================

echo ""
echo -e "${BOLD}=============================================="
echo "  CONSOLIDATION PHASE 2 — yCogniCore Cloud"
echo -e "==============================================${NC}"
echo "Base         : $DB"
echo "Host         : $PG_HOST"
echo "Utilisateur  : $PG_USER"
echo "Date         : $(date '+%Y-%m-%d %H:%M:%S')"
echo "Rapport      : $REPORT_FILE"
echo ""

# Initialiser le rapport
cat > "$REPORT_FILE" << EOF
# Rapport de consolidation Phase 2

**Date** : $(date '+%Y-%m-%d %H:%M:%S')
**Base** : $DB
**Host** : $PG_HOST

---

## Résultats

EOF

# Compteurs globaux
TOTAL_CHECKS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

increment_check() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ "$1" = "0" ]; then
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
    fi
}

# ============================================================================
# VERIFICATION 0 — CONNEXION POSTGRESQL
# ============================================================================

echo -e "${BLUE}[0/8]${NC} Connexion PostgreSQL..."
if ! psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${RED}  ERREUR : impossible de se connecter à $DB${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓${NC} Connexion établie"
echo ""
echo "## Vérification 0 — Connexion" >> "$REPORT_FILE"
echo "- ✓ Connexion PostgreSQL établie" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# ============================================================================
# VERIFICATION 1 — INVENTAIRE DES TABLES
# ============================================================================

echo -e "${BLUE}[1/8]${NC} Inventaire des tables..."

# Tables attendues par bloc
EXPECTED_V9=3
EXPECTED_V10=4
EXPECTED_V11=7
EXPECTED_V12=14
EXPECTED_V13=13
EXPECTED_TOTAL=$((EXPECTED_V9 + EXPECTED_V10 + EXPECTED_V11 + EXPECTED_V12 + EXPECTED_V13))

ACTUAL_V9=$(sql_value "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('fichiers','ia_suggestions','kpi_snapshots');")
ACTUAL_V10=$(sql_value "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('tiers','role_tiers','contact_tiers','adresse_tiers');")
ACTUAL_V11=$(sql_value "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('familles_articles','unites_mesure','marques','taxes','articles','article_variantes','articles_fournisseurs');")
ACTUAL_V12=$(sql_value "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('prospects','contacts','campagnes','campagne_cibles','pipelines','pipeline_etapes','opportunites','opportunites_historique_etapes','activites','interactions','rendez_vous','rendez_vous_participants','crm_regles_automatisation','crm_regles_executions');")
ACTUAL_V13=$(sql_value "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('sequences_documents','documents_vente','documents_vente_lignes','documents_vente_liens','documents_vente_historique_statuts','listes_prix','lignes_tarif','promotions','circuits_validation','validations_documents','paiements','paiements_allocations','relances_factures');")

ACTUAL_TOTAL=$((ACTUAL_V9 + ACTUAL_V10 + ACTUAL_V11 + ACTUAL_V12 + ACTUAL_V13))

echo "  V9  (Fichiers + IA + KPI) : $ACTUAL_V9 / $EXPECTED_V9"
echo "  V10 (Tiers)               : $ACTUAL_V10 / $EXPECTED_V10"
echo "  V11 (Articles)            : $ACTUAL_V11 / $EXPECTED_V11"
echo "  V12 (CRM)                 : $ACTUAL_V12 / $EXPECTED_V12"
echo "  V13 (Ventes)              : $ACTUAL_V13 / $EXPECTED_V13"
echo "  TOTAL                     : $ACTUAL_TOTAL / $EXPECTED_TOTAL"
echo ""

echo "## Vérification 1 — Inventaire des tables" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "| Bloc | Tables | Attendu | Statut |" >> "$REPORT_FILE"
echo "|---|---|---|---|" >> "$REPORT_FILE"
echo "| V9  | $ACTUAL_V9  | $EXPECTED_V9  | $([ "$ACTUAL_V9" = "$EXPECTED_V9" ] && echo "✓" || echo "✗") |" >> "$REPORT_FILE"
echo "| V10 | $ACTUAL_V10 | $EXPECTED_V10 | $([ "$ACTUAL_V10" = "$EXPECTED_V10" ] && echo "✓" || echo "✗") |" >> "$REPORT_FILE"
echo "| V11 | $ACTUAL_V11 | $EXPECTED_V11 | $([ "$ACTUAL_V11" = "$EXPECTED_V11" ] && echo "✓" || echo "✗") |" >> "$REPORT_FILE"
echo "| V12 | $ACTUAL_V12 | $EXPECTED_V12 | $([ "$ACTUAL_V12" = "$EXPECTED_V12" ] && echo "✓" || echo "✗") |" >> "$REPORT_FILE"
echo "| V13 | $ACTUAL_V13 | $EXPECTED_V13 | $([ "$ACTUAL_V13" = "$EXPECTED_V13" ] && echo "✓" || echo "✗") |" >> "$REPORT_FILE"
echo "| **TOTAL** | **$ACTUAL_TOTAL** | **$EXPECTED_TOTAL** | $([ "$ACTUAL_TOTAL" = "$EXPECTED_TOTAL" ] && echo "**✓**" || echo "**✗**") |" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ "$ACTUAL_TOTAL" = "$EXPECTED_TOTAL" ]; then
    echo -e "${GREEN}  ✓ Toutes les $EXPECTED_TOTAL tables attendues sont présentes${NC}"
    increment_check 0
else
    echo -e "${RED}  ✗ Tables manquantes : $((EXPECTED_TOTAL - ACTUAL_TOTAL))${NC}"
    increment_check 1
fi
echo ""

# ============================================================================
# VERIFICATION 2 — INTEGRITE REFERENTIELLE (FK)
# ============================================================================

echo -e "${BLUE}[2/8]${NC} Intégrité référentielle (FK)..."

FK_COUNT=$(sql_value "SELECT COUNT(*) FROM pg_constraint WHERE contype='f' AND connamespace='public'::regnamespace;")
FK_ORPHAN=$(sql_value "
SELECT COUNT(*)
FROM pg_constraint c
LEFT JOIN pg_class t ON t.oid = c.confrelid
WHERE c.contype = 'f'
  AND c.connamespace = 'public'::regnamespace
  AND t.oid IS NULL;")

echo "  Clés étrangères totales : $FK_COUNT"
echo "  FK cassées (table cible absente) : $FK_ORPHAN"
echo ""

echo "## Vérification 2 — Intégrité référentielle" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- Clés étrangères : $FK_COUNT" >> "$REPORT_FILE"
echo "- FK cassées : $FK_ORPHAN" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ "$FK_ORPHAN" = "0" ] && [ "$FK_COUNT" -ge 70 ]; then
    echo -e "${GREEN}  ✓ $FK_COUNT FK valides, 0 cassée${NC}"
    increment_check 0
else
    echo -e "${RED}  ✗ FK cassées détectées${NC}"
    increment_check 1
fi
echo ""

# ============================================================================
# VERIFICATION 3 — DETECTION DES ORPHELINS
# ============================================================================

echo -e "${BLUE}[3/8]${NC} Détection des orphelins métier..."

TOTAL_ORPHANS=0

# Documents V13 → Tiers V10
ORPHAN_DOC_TIERS=$(sql_value "
SELECT COUNT(*) FROM documents_vente dv
LEFT JOIN tiers t ON t.id = dv.tiers_id
WHERE dv.tiers_id IS NOT NULL AND t.id IS NULL AND dv.deleted_at IS NULL;")

# Documents lignes → Article V11
ORPHAN_LIGNE_ARTICLE=$(sql_value "
SELECT COUNT(*) FROM documents_vente_lignes dvl
LEFT JOIN articles a ON a.id = dvl.article_id
WHERE dvl.article_id IS NOT NULL AND a.id IS NULL AND dvl.deleted_at IS NULL;")

# Opportunités V12 → Tiers V10
ORPHAN_OPP_TIERS=$(sql_value "
SELECT COUNT(*) FROM opportunites o
LEFT JOIN tiers t ON t.id = o.tiers_id
WHERE o.tiers_id IS NOT NULL AND t.id IS NULL AND o.deleted_at IS NULL;")

# Contacts V12 → Tiers V10
ORPHAN_CONTACT_TIERS=$(sql_value "
SELECT COUNT(*) FROM contacts c
LEFT JOIN tiers t ON t.id = c.tiers_id
WHERE c.tiers_id IS NOT NULL AND t.id IS NULL AND c.deleted_at IS NULL;")

# Paiements V13 → Tiers V10
ORPHAN_PAIEMENT_TIERS=$(sql_value "
SELECT COUNT(*) FROM paiements p
LEFT JOIN tiers t ON t.id = p.tiers_id
WHERE p.tiers_id IS NOT NULL AND t.id IS NULL AND p.deleted_at IS NULL;")

# Articles V11 → Famille V11
ORPHAN_ARTICLE_FAMILLE=$(sql_value "
SELECT COUNT(*) FROM articles a
LEFT JOIN familles_articles f ON f.id = a.famille_id
WHERE a.famille_id IS NOT NULL AND f.id IS NULL AND a.deleted_at IS NULL;")

TOTAL_ORPHANS=$((ORPHAN_DOC_TIERS + ORPHAN_LIGNE_ARTICLE + ORPHAN_OPP_TIERS + ORPHAN_CONTACT_TIERS + ORPHAN_PAIEMENT_TIERS + ORPHAN_ARTICLE_FAMILLE))

echo "  Documents → Tiers        : $ORPHAN_DOC_TIERS"
echo "  Lignes → Article         : $ORPHAN_LIGNE_ARTICLE"
echo "  Opportunités → Tiers     : $ORPHAN_OPP_TIERS"
echo "  Contacts → Tiers         : $ORPHAN_CONTACT_TIERS"
echo "  Paiements → Tiers        : $ORPHAN_PAIEMENT_TIERS"
echo "  Articles → Famille       : $ORPHAN_ARTICLE_FAMILLE"
echo "  TOTAL orphelins          : $TOTAL_ORPHANS"
echo ""

echo "## Vérification 3 — Orphelins métier" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- Documents → Tiers : $ORPHAN_DOC_TIERS" >> "$REPORT_FILE"
echo "- Lignes → Article : $ORPHAN_LIGNE_ARTICLE" >> "$REPORT_FILE"
echo "- Opportunités → Tiers : $ORPHAN_OPP_TIERS" >> "$REPORT_FILE"
echo "- Contacts → Tiers : $ORPHAN_CONTACT_TIERS" >> "$REPORT_FILE"
echo "- Paiements → Tiers : $ORPHAN_PAIEMENT_TIERS" >> "$REPORT_FILE"
echo "- Articles → Famille : $ORPHAN_ARTICLE_FAMILLE" >> "$REPORT_FILE"
echo "- **TOTAL** : $TOTAL_ORPHANS" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ "$TOTAL_ORPHANS" = "0" ]; then
    echo -e "${GREEN}  ✓ Aucun orphelin détecté${NC}"
    increment_check 0
else
    echo -e "${RED}  ✗ $TOTAL_ORPHANS orphelin(s) détecté(s)${NC}"
    increment_check 1
fi
echo ""

# ============================================================================
# VERIFICATION 4 — TRIGGERS ACTIFS
# ============================================================================

echo -e "${BLUE}[4/8]${NC} Triggers d'audit et de protection..."

TRIGGERS_TOTAL=$(sql_value "
SELECT COUNT(*) FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
WHERE c.relnamespace = 'public'::regnamespace
  AND NOT t.tgisinternal
  AND t.tgname LIKE 'trg_%';")

TRIGGERS_AUDIT=$(sql_value "
SELECT COUNT(*) FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
WHERE c.relnamespace = 'public'::regnamespace
  AND t.tgname LIKE '%_audit_temporel'
  AND t.tgenabled = 'O';")

TRIGGERS_NO_DELETE=$(sql_value "
SELECT COUNT(*) FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
WHERE c.relnamespace = 'public'::regnamespace
  AND t.tgname LIKE '%_no_hard_delete'
  AND t.tgenabled = 'O';")

TRIGGERS_DISABLED=$(sql_value "
SELECT COUNT(*) FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
WHERE c.relnamespace = 'public'::regnamespace
  AND NOT t.tgisinternal
  AND t.tgname LIKE 'trg_%'
  AND t.tgenabled <> 'O';")

echo "  Triggers totaux      : $TRIGGERS_TOTAL"
echo "  Audit temporel       : $TRIGGERS_AUDIT"
echo "  No hard delete       : $TRIGGERS_NO_DELETE"
echo "  Triggers désactivés  : $TRIGGERS_DISABLED"
echo ""

echo "## Vérification 4 — Triggers" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- Triggers totaux : $TRIGGERS_TOTAL" >> "$REPORT_FILE"
echo "- Audit temporel : $TRIGGERS_AUDIT" >> "$REPORT_FILE"
echo "- No hard delete : $TRIGGERS_NO_DELETE" >> "$REPORT_FILE"
echo "- Désactivés : $TRIGGERS_DISABLED" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ "$TRIGGERS_DISABLED" = "0" ] && [ "$TRIGGERS_AUDIT" -ge 30 ] && [ "$TRIGGERS_NO_DELETE" -ge 30 ]; then
    echo -e "${GREEN}  ✓ Tous les triggers sont actifs${NC}"
    increment_check 0
else
    echo -e "${RED}  ✗ Triggers manquants ou désactivés${NC}"
    increment_check 1
fi
echo ""

# ============================================================================
# VERIFICATION 5 — DROITS RBAC
# ============================================================================

echo -e "${BLUE}[5/8]${NC} Droits RBAC (ycc_tenant_app)..."

# Compter les tables avec SELECT
TABLES_WITH_SELECT=$(sql_value "
SELECT COUNT(DISTINCT table_name)
FROM information_schema.role_table_grants
WHERE grantee = 'ycc_tenant_app'
  AND table_schema = 'public'
  AND privilege_type = 'SELECT';")

# Compter les tables avec DELETE (interdit)
TABLES_WITH_DELETE=$(sql_value "
SELECT COUNT(DISTINCT table_name)
FROM information_schema.role_table_grants
WHERE grantee = 'ycc_tenant_app'
  AND table_schema = 'public'
  AND privilege_type = 'DELETE';")

echo "  Tables avec SELECT   : $TABLES_WITH_SELECT"
echo "  Tables avec DELETE   : $TABLES_WITH_DELETE (doit être 0)"
echo ""

echo "## Vérification 5 — Droits RBAC" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- Tables avec SELECT : $TABLES_WITH_SELECT" >> "$REPORT_FILE"
echo "- Tables avec DELETE : $TABLES_WITH_DELETE (attendu : 0)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ "$TABLES_WITH_SELECT" -ge 30 ] && [ "$TABLES_WITH_DELETE" = "0" ]; then
    echo -e "${GREEN}  ✓ Droits RBAC corrects${NC}"
    increment_check 0
else
    echo -e "${RED}  ✗ Problème de droits RBAC${NC}"
    increment_check 1
fi
echo ""

# ============================================================================
# VERIFICATION 6 — TESTS DE NON-REGRESSION
# ============================================================================

echo -e "${BLUE}[6/8]${NC} Tests de non-régression (V9 → V13)..."

TESTS_OK=0
TESTS_TOTAL=0

for bloc in v9 v10 v11 v12 v13; do
    TEST_FILE="db/scripts/test_${bloc}_migration.sql"

    if [ ! -f "$TEST_FILE" ]; then
        echo -e "  ${YELLOW}⚠${NC} $bloc : fichier de test absent"
        continue
    fi

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    RESULT=$(psql -h "$PG_HOST" -U "$PG_USER" -d "$DB" -f "$TEST_FILE" 2>&1 | grep -E "TOUS LES TESTS PASSENT" || echo "ECHEC")

    if echo "$RESULT" | grep -q "TOUS LES TESTS PASSENT"; then
        echo -e "  ${GREEN}✓${NC} $bloc : PASS"
        TESTS_OK=$((TESTS_OK + 1))
    else
        echo -e "  ${RED}✗${NC} $bloc : ECHEC"
    fi
done

echo "  Tests OK : $TESTS_OK / $TESTS_TOTAL"
echo ""

echo "## Vérification 6 — Tests de non-régression" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- Tests passés : $TESTS_OK / $TESTS_TOTAL" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ "$TESTS_OK" = "$TESTS_TOTAL" ] && [ "$TESTS_TOTAL" -ge 3 ]; then
    echo -e "${GREEN}  ✓ Tous les tests passent${NC}"
    increment_check 0
else
    echo -e "${RED}  ✗ Certains tests échouent${NC}"
    increment_check 1
fi
echo ""

# ============================================================================
# VERIFICATION 7 — COHERENCE SYSCOHADA
# ============================================================================

echo -e "${BLUE}[7/8]${NC} Cohérence SYSCOHADA..."

ARTICLES_SANS_COMPTE=$(sql_value "
SELECT COUNT(*) FROM articles a
LEFT JOIN familles_articles f ON f.id = a.famille_id
WHERE a.deleted_at IS NULL
  AND (a.compte_comptable_stock IS NULL AND f.compte_comptable_stock IS NULL);")

echo "  Articles sans compte comptable : $ARTICLES_SANS_COMPTE"
echo ""

echo "## Vérification 7 — Cohérence SYSCOHADA" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- Articles sans compte comptable : $ARTICLES_SANS_COMPTE" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Note : peut être 0 si aucun article n'a été créé ou si tous ont un compte
if [ "$ARTICLES_SANS_COMPTE" = "0" ]; then
    echo -e "${GREEN}  ✓ Cohérence SYSCOHADA OK${NC}"
    increment_check 0
else
    echo -e "${YELLOW}  ⚠ $ARTICLES_SANS_COMPTE article(s) sans compte comptable${NC}"
    increment_check 0  # Non bloquant
fi
echo ""

# ============================================================================
# VERIFICATION 8 — SOFT DELETE
# ============================================================================

echo -e "${BLUE}[8/8]${NC} Soft delete sur toutes les tables transactionnelles..."

TABLES_WITHOUT_DELETED_AT=$(sql_value "
SELECT COUNT(*)
FROM information_schema.tables t
WHERE t.table_schema = 'public'
  AND t.table_type = 'BASE TABLE'
  AND t.table_name NOT IN ('kpi_snapshots','crm_regles_executions','opportunites_historique_etapes','documents_vente_liens','documents_vente_historique_statuts','paiements_allocations','rendez_vous_participants','campagne_cibles')
  AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = t.table_name
      AND c.column_name = 'deleted_at'
  );")

echo "  Tables transactionnelles sans deleted_at : $TABLES_WITHOUT_DELETED_AT"
echo ""

echo "## Vérification 8 — Soft delete" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- Tables sans deleted_at : $TABLES_WITHOUT_DELETED_AT" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ "$TABLES_WITHOUT_DELETED_AT" = "0" ]; then
    echo -e "${GREEN}  ✓ Soft delete présent sur toutes les tables${NC}"
    increment_check 0
else
    echo -e "${YELLOW}  ⚠ $TABLES_WITHOUT_DELETED_AT table(s) sans deleted_at${NC}"
    increment_check 0  # Non bloquant
fi
echo ""

# ============================================================================
# RAPPORT FINAL
# ============================================================================

echo -e "${BOLD}=============================================="
echo "  RESULTAT DE LA CONSOLIDATION"
echo -e "==============================================${NC}"
echo ""
echo "  Vérifications totales : $TOTAL_CHECKS"
echo -e "  ${GREEN}Réussies${NC}             : $TOTAL_PASSED"
echo -e "  ${RED}Échouées${NC}             : $TOTAL_FAILED"
echo ""

# Ajouter au rapport
cat >> "$REPORT_FILE" << EOF

---

## Résultat final

| Indicateur | Valeur |
|---|---|
| Vérifications totales | $TOTAL_CHECKS |
| Réussies | $TOTAL_PASSED |
| Échouées | $TOTAL_FAILED |

EOF

# Synthèse
if [ "$TOTAL_FAILED" = "0" ]; then
    echo -e "${GREEN}${BOLD}  ✓ STATUT : FONDATION SOLIDE${NC}"
    echo ""
    echo "  Toutes les vérifications sont passées."
    echo "  La base de données est prête pour la suite de la Phase 2."
    echo ""
    echo "**STATUT : FONDATION SOLIDE**" >> "$REPORT_FILE"
    EXIT_CODE=0
else
    echo -e "${RED}${BOLD}  ✗ STATUT : FONDATION NON SOLIDE${NC}"
    echo ""
    echo "  $TOTAL_FAILED vérification(s) en échec."
    echo "  Corriger les problèmes avant de continuer."
    echo ""
    echo "**STATUT : FONDATION NON SOLIDE ($TOTAL_FAILED échec(s))**" >> "$REPORT_FILE"
    EXIT_CODE=1
fi

echo "  Rapport complet : $REPORT_FILE"
echo ""
echo -e "${BOLD}==============================================${NC}"
echo ""

exit $EXIT_CODE
