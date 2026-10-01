#!/usr/bin/env bash
# =====================================================================
# commit-sans-captures.sh — Commit du 30/09 SANS les captures
# =====================================================================
set -euo pipefail

cd "$HOME/projets/ycognicore-cloud"

DATE_DEBUT="2026-09-30 00:00:00"
DATE_FIN="2026-10-01 00:00:00"

VERT='\033[0;32m'
JAUNE='\033[0;33m'
BLEU='\033[0;34m'
NC='\033[0m'

echo "═══════════════════════════════════════════════════════"
echo "  COMMIT — FICHIERS DU 30/09 SANS CAPTURES"
echo "═══════════════════════════════════════════════════════"
echo ""

# Reset
git reset HEAD . 2>/dev/null || true

echo "[1/3] Recherche des fichiers (exclusion captures)..."

FICHIERS=$(find . -type f \
    -newermt "$DATE_DEBUT" ! -newermt "$DATE_FIN" \
    ! -path "./.git/*" \
    ! -path "./db.backup-*" \
    ! -path "./database/dumps/*" \
    ! -path "./docs/rapports/captures/*" \
    ! -path "*__pycache__*" \
    ! -name "*.pyc" \
    ! -name "*.pyo" \
    ! -name "*.backup" \
    ! -name "*.backup-*" \
    ! -path "./target/*" \
    ! -path "./node_modules/*" \
    ! -path "./logs/*" \
    ! -path "./frontend/node_modules/*" \
    2>/dev/null)

NB=$(echo "$FICHIERS" | wc -l)
echo -e "  ${VERT}✅${NC} $NB fichiers trouvés (sans captures)"
echo ""

echo "[2/3] Staging des fichiers..."

while IFS= read -r fichier; do
    [ -z "$fichier" ] && continue
    [ -f "$fichier" ] || continue
    
    if git check-ignore -q "$fichier" 2>/dev/null; then
        continue
    fi
    
    git add "$fichier" 2>/dev/null || true
done <<< "$FICHIERS"

STAGED=$(git diff --cached --name-only | wc -l)
echo -e "  ${VERT}✅${NC} $STAGED fichiers stagés"
echo ""

echo "[3/3] Aperçu des fichiers stagés :"
echo ""
echo "=== Détail par catégorie ==="
echo "  Fichiers SQL      : $(git diff --cached --name-only | grep -c '\.sql$')"
echo "  Fichiers Java     : $(git diff --cached --name-only | grep -c '\.java$')"
echo "  Fichiers YAML     : $(git diff --cached --name-only | grep -c '\.yml$\|\.yaml$')"
echo "  Fichiers Markdown : $(git diff --cached --name-only | grep -c '\.md$')"
echo "  Fichiers Bash     : $(git diff --cached --name-only | grep -c '\.sh$')"
echo "  Fichiers Python   : $(git diff --cached --name-only | grep -c '\.py$')"
echo "  Fichiers Word/PDF : $(git diff --cached --name-only | grep -c '\.docx$\|\.pdf$')"

echo ""
echo "=== Liste complète (premiers 40) ==="
git diff --cached --name-only | sort | head -40

echo ""
echo "═══════════════════════════════════════════════════════"
read -p "Confirmer le commit ? (yes/no) : " confirmation

if [ "$confirmation" = "yes" ]; then
    git commit -m "Session du 30/09/2026 — Sprint H0 clôturé (6/6)

Livrables du 30/09/2026 :
- 13 migrations SQL (V1-V7 CP + V1-V7 Tenant)
- 7 migrations Flyway appliquées
- 6 ADRs (008 à 013)
- 9 fichiers Java (~455 lignes)
- 4 fichiers infra/ (Docker Compose, Makefile, scripts)
- 3 seeds + scripts db/
- Rapport journalier n°10 (Word + PDF + Markdown)

Infrastructure :
- PostgreSQL 16 + Redis 7 + Vault 1.17 + MinIO
- 4 services Docker healthy
- 12 partitions créées automatiquement

Sprint H0 : 6/6 points clôturés
Phase 1 : ~82 % d'avancement

Note : les captures d'écran sont exclues de ce commit.
Elles seront ajoutées dans un commit séparé si nécessaire.

Réf. : Rapports 04-78 à 10-78, ADR-001 à ADR-013, BACKLOG (H0)"
    
    echo ""
    echo -e "${VERT}✅ Commit créé${NC}"
    echo ""
    
    git log --oneline -3
else
    echo ""
    echo -e "${JAUNE}⚠ Commit annulé${NC}"
    echo "→ Pour annuler : git reset HEAD ."
fi
