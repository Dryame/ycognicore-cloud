#!/usr/bin/env bash
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

REPO_DIR="/home/idrissa_yameogo/projets/ycognicore-cloud"
if [ ! -d "$REPO_DIR/.git" ]; then
    echo -e "${RED}Dépôt introuvable : $REPO_DIR${NC}"
    exit 1
fi
cd "$REPO_DIR" || exit 1

TOTAL=0; PASSED=0; FAILED=0; WARNED=0
h1()   { echo ""; echo -e "${BOLD}${BLUE}=== $1 ===${NC}"; }
ok()   { TOTAL=$((TOTAL+1)); PASSED=$((PASSED+1)); echo -e "  ${GREEN}OK${NC}   $1"; }
ko()   { TOTAL=$((TOTAL+1)); FAILED=$((FAILED+1)); echo -e "  ${RED}KO${NC}   $1"; }
warn() { TOTAL=$((TOTAL+1)); WARNED=$((WARNED+1)); echo -e "  ${YELLOW}WARN${NC} $1"; }

echo -e "${BOLD}=========================================================${NC}"
echo -e "${BOLD}  PRE-VERIFICATION — PHASE 2${NC}"
echo -e "${BOLD}  Dépôt : $REPO_DIR${NC}"
echo -e "${BOLD}  Date  : $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BOLD}=========================================================${NC}"

h1 "1. ETAT GIT"
if [ -z "$(git status --porcelain)" ]; then
    ok "Working tree propre"
else
    ko "Working tree non propre :"
    git status --short | sed 's/^/       /'
fi
BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$BRANCH" = "main" ] && ok "Branche : main" || warn "Branche : $BRANCH"
git fetch origin --quiet 2>/dev/null || warn "git fetch ignoré"
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main 2>/dev/null || echo "unavailable")
[ "$LOCAL" = "$REMOTE" ] && ok "Local = origin/main ($(echo $LOCAL | cut -c1-7))" \
                        || warn "Local != origin/main"

h1 "2. TAGS DE PHASE"
for tag in v0.5.1-assainissement v0.6.1-fiabilisation; do
    git tag -l | grep -q "^${tag}$" && ok "Tag : $tag" || ko "Tag absent : $tag"
done

h1 "3. STRUCTURE"
for dir in db/migration/tenant db/migration/control-plane backend frontend infra docs scripts; do
    [ -d "$dir" ] && ok "Répertoire : $dir" || ko "Manquant : $dir"
done
[ -d "src" ] && ko "src/ racine encore présent" || ok "src/ absent (conforme P0)"

h1 "4. MIGRATIONS TENANT"
NB_MIG=$(ls db/migration/tenant/V*__*.sql 2>/dev/null | wc -l)
[ "$NB_MIG" -ge 16 ] && ok "Migrations tenant : $NB_MIG" || ko "Migrations tenant : $NB_MIG (attendu >= 16)"
for v in 14 15 16; do
    ls db/migration/tenant/V${v}__*.sql >/dev/null 2>&1 && ok "V${v} présent" || ko "V${v} manquant"
done
[ -d "db/migration/tenant/legacy" ] && ko "legacy/ encore présent" || ok "Pas de legacy/"

h1 "5. DOCKER"
if command -v docker >/dev/null 2>&1; then
    for svc in pg-ycc vault-ycc redis-ycc minio-ycc; do
        docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${svc}$" \
            && ok "Conteneur : $svc" || warn "Non actif : $svc"
    done
else
    warn "docker indisponible"
fi

h1 "6. BASES TENANT"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^pg-ycc$"; then
    for db in ycc_tenant_demo001 ycc_tenant_demo002; do
        VERSION=$(docker exec pg-ycc psql -U postgres -d "$db" -tAc \
            "SELECT COALESCE(MAX(version), '0') FROM flyway_schema_history WHERE success = true;" \
            2>/dev/null | tr -d ' ')
        [ "$VERSION" = "16" ] && ok "$db : V$VERSION" || warn "$db : V$VERSION (attendu : 16)"
    done
else
    warn "pg-ycc non actif"
fi

h1 "7. COMPILATION BACKEND (sans exécution des tests)"
if [ -f "backend/mvnw" ]; then
    cd backend
    if MAVEN_OPTS="-Xmx512m" timeout 180 ./mvnw -q -o test-compile -B >/tmp/preverif-mvn.log 2>&1; then
        ok "Compilation des tests réussie (test-compile)"
    else
        ko "Compilation en échec — voir /tmp/preverif-mvn.log"
        tail -5 /tmp/preverif-mvn.log | sed 's/^/       /'
    fi
    cd "$REPO_DIR"

    NB_TESTS=$(find backend/src/test -name "*Test.java" -o -name "*IT.java" 2>/dev/null | wc -l)
    [ "$NB_TESTS" -ge 5 ] && ok "Fichiers de tests : $NB_TESTS" \
                          || ko "Fichiers de tests : $NB_TESTS (attendu >= 5)"
else
    ko "backend/mvnw introuvable"
fi

h1 "8. DOCUMENTATION"
for file in docs/decisions/points-a-confirmer.md docs/BACKLOG.md README.md; do
    [ -f "$file" ] && ok "Présent : $file" || ko "Manquant : $file"
done
[ -d "docs/methode" ] && ok "docs/methode/ présent" || warn "docs/methode/ absent (à créer en T2.1)"
NB_ADR=$(ls docs/adr/ADR-*.md 2>/dev/null | wc -l)
echo "       ADR existants : $NB_ADR"
ls docs/adr/ADR-*.md 2>/dev/null | sed 's/^/         /'

h1 "SYNTHESE"
echo "  Total : $TOTAL"
echo -e "  ${GREEN}Réussies${NC}       : $PASSED"
echo -e "  ${YELLOW}Avertissements${NC}  : $WARNED"
echo -e "  ${RED}Échouées${NC}       : $FAILED"
echo ""
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}PRET POUR LA PHASE 2${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}NON PRET — $FAILED échec(s)${NC}"
    exit 1
fi
