#!/usr/bin/env bash
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

if [ -n "${1:-}" ] && [ -d "$1/.git" ]; then
  REPO_DIR="$1"
elif [ -d ".git" ]; then
  REPO_DIR="$(pwd)"
else
  REPO_DIR="/home/idrissa_yameogo/projets/ycognicore-cloud"
fi

if [ ! -d "$REPO_DIR/.git" ]; then
  echo -e "${RED}✗ Dépôt Git introuvable : $REPO_DIR${NC}"
  exit 1
fi
cd "$REPO_DIR" || exit 1

TS="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/tmp/diagnostic_p0_${TS}.log"
TOTAL=0; PASSED=0; FAILED=0; WARNED=0

log()  { echo -e "$1" | tee -a "$LOG_FILE"; }
ok()   { TOTAL=$((TOTAL+1)); PASSED=$((PASSED+1)); log "  ${GREEN}✓${NC} $1"; }
ko()   { TOTAL=$((TOTAL+1)); FAILED=$((FAILED+1)); log "  ${RED}✗${NC} $1"; }
warn() { TOTAL=$((TOTAL+1)); WARNED=$((WARNED+1)); log "  ${YELLOW}⚠${NC} $1"; }
h1()   { log ""; log "${BOLD}${BLUE}=== $1 ===${NC}"; }

log "${BOLD}=========================================================${NC}"
log "${BOLD}  DIAGNOSTIC PHASE 0 — yCogniCore Cloud${NC}"
log "${BOLD}  Répertoire : $REPO_DIR${NC}"
log "${BOLD}  Date       : $(date '+%Y-%m-%d %H:%M:%S')${NC}"
log "${BOLD}  Log        : $LOG_FILE${NC}"
log "${BOLD}=========================================================${NC}"

h1 "1. ÉTAT DU DÉPÔT GIT"
git rev-parse --git-dir >/dev/null 2>&1 && ok "Dépôt Git détecté" || ko "Dépôt Git introuvable"
if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
  ok "Working tree propre"
else
  ko "Working tree non propre :"
  git status --short | head -20 | tee -a "$LOG_FILE"
fi
if git tag -l | grep -q "^v0.5.1-assainissement$"; then
  TAG_COMMIT=$(git rev-list -n 1 v0.5.1-assainissement)
  ok "Tag v0.5.1-assainissement présent (commit ${TAG_COMMIT:0:7})"
  git merge-base --is-ancestor v0.5.1-assainissement HEAD 2>/dev/null \
    && ok "Tag ancêtre de HEAD" || warn "Tag non ancêtre de HEAD"
else
  ko "Tag v0.5.1-assainissement absent"
fi

h1 "2. MIGRATIONS TENANT"
[ -d "db/migration/tenant" ] && ok "Répertoire db/migration/tenant/ présent" \
                             || ko "Répertoire db/migration/tenant/ absent"
NB_V1_V13=$(ls db/migration/tenant/V{1,2,3,4,5,6,7,8,9,10,11,12,13}__*.sql 2>/dev/null | wc -l)
[ "$NB_V1_V13" -ge 13 ] && ok "Migrations V1 à V13 présentes ($NB_V1_V13)" \
                        || ko "Migrations V1 à V13 incomplètes ($NB_V1_V13 / 13)"
[ -f "db/migration/tenant/V14__add_tenant_mfa.sql" ] \
  && ok "V14__add_tenant_mfa.sql présent" || ko "V14__add_tenant_mfa.sql absent"
find . -name "V8_add_tenant_mfa.sql" -not -path "./db.backup-*" 2>/dev/null | grep -q . \
  && ko "Doublon V8_add_tenant_mfa.sql encore présent" \
  || ok "Doublon V8_add_tenant_mfa.sql éliminé"
[ -d "db/migration/tenant/legacy" ] && ko "Dossier legacy/ encore présent" \
                                    || ok "Aucun dossier legacy/"

h1 "3. CONTROL-PLANE"
NB_CP=$(ls db/migration/control-plane/V{1,2,3,4,5,6,7}__*.sql 2>/dev/null | wc -l)
[ "$NB_CP" -ge 7 ] && ok "Migrations control-plane V1 à V7 présentes ($NB_CP)" \
                   || ko "Migrations control-plane incomplètes ($NB_CP / 7)"
[ -d "backend/src/main/resources/db/migration/control-plane" ] \
  && ko "Copie control-plane encore dans backend/" \
  || ok "Copie control-plane supprimée de backend/"

h1 "4. DOSSIER src/"
[ -d "src" ] && ko "Dossier src/ encore présent" || ok "Dossier src/ supprimé"

h1 "5. SCRIPTS"
for f in scripts/provisioning_tenant.py scripts/consolidate_all.sh scripts/analyze_quality.py; do
  [ -f "$f" ] && ok "$f présent" || ko "$f manquant"
done
[ -f "db/scripts/provisioning_tenant.py" ] && ko "db/scripts/provisioning_tenant.py encore présent" \
                                           || ok "db/scripts/provisioning_tenant.py supprimé"

h1 "6. BASES DE DONNÉES"
if timeout 5 docker ps >/dev/null 2>&1; then
  if timeout 5 docker ps 2>/dev/null | grep -q "pg-ycc"; then
    ok "Conteneur pg-ycc actif"
    PG_VERSION=$(timeout 10 docker exec pg-ycc psql -U postgres -tAc "SELECT version();" 2>/dev/null | grep -oE "PostgreSQL [0-9]+" | head -1)
    echo "$PG_VERSION" | grep -q "16" && ok "PostgreSQL 16 confirmé" || warn "Version : $PG_VERSION"
    NB_V14=$(timeout 10 docker exec pg-ycc psql -U postgres -d ycc_control_plane -tAc \
      "SELECT COUNT(*) FROM tenant_databases WHERE version_schema='V14';" 2>/dev/null | tr -d ' ')
    [ "${NB_V14:-0}" -ge 2 ] && ok "Tenants à V14 : $NB_V14" || ko "Tenants à V14 : ${NB_V14:-0}"
  else
    ko "Conteneur pg-ycc non actif"
  fi
else
  warn "Docker non disponible"
fi

h1 "7. DOCUMENTATION"
for f in "docs/decisions/points-a-confirmer.md" "docs/adr/ADR-030-convention-migrations-flyway.md" \
         "docs/rapports/journalier-T0.10.md" "README.md" "docs/BACKLOG.md"; do
  [ -f "$f" ] && ok "$f présent" || ko "$f manquant"
done

h1 "8. COMPILATION"
if [ -d "backend" ]; then
  cd backend
  if MAVEN_OPTS="-Xmx512m" timeout 120 ./mvnw -q -o compile >/tmp/diag_mvn.log 2>&1; then
    ok "Compilation Maven OK"
  else
    ko "Compilation Maven en échec"
    tail -5 /tmp/diag_mvn.log | tee -a "$LOG_FILE"
  fi
  cd "$REPO_DIR"
else
  ko "backend/ introuvable"
fi

h1 "SYNTHÈSE"
log "  Vérifications totales : $TOTAL"
log "  ${GREEN}Réussies${NC}            : $PASSED"
log "  ${YELLOW}Avertissements${NC}       : $WARNED"
log "  ${RED}Échouées${NC}            : $FAILED"

if [ "$FAILED" -eq 0 ]; then
  log "${GREEN}${BOLD}✓ STATUT : PHASE 0 VALIDÉE — PRÊTE POUR P1${NC}"
  exit 0
else
  log "${RED}${BOLD}✗ STATUT : PHASE 0 NON VALIDÉE — $FAILED échec(s)${NC}"
  exit 1
fi
