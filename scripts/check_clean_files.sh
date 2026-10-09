#!/bin/bash
# ============================================================================
# check_clean_files.sh
# ============================================================================

REPO_DIR="$HOME/projets/ycognicore-cloud"
CHECK_PATH="${2:-.}"
cd "$REPO_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TOTAL_FILES=0
TOTAL_ISSUES=0
TOTAL_WARNINGS=0

echo "=============================================="
echo "VALIDATION DE PROPRETE DES FICHIERS"
echo "=============================================="
echo "Chemin : $CHECK_PATH"
echo ""

FILES=$(find "$CHECK_PATH" -type f \
    \( -name "*.md" -o -name "*.sql" -o -name "*.sh" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" \
    -not -path "*/target/*" -not -path "*/legacy/*" 2>/dev/null || true)

if [ -z "$FILES" ]; then
    echo "Aucun fichier trouve"
    exit 0
fi

echo "Fichiers analyses : $(echo "$FILES" | wc -l)"
echo ""

for file in $FILES; do
    TOTAL_FILES=$((TOTAL_FILES + 1))
    rel="${file#./}"
    issues=0
    msg=""

    # BOM
    if head -c 3 "$file" | grep -q $'\xef\xbb\xbf'; then
        issues=$((issues + 1)); msg="$msg\n    - BOM"
    fi

    # Encodage
    if ! file "$file" | grep -q "UTF-8\|ASCII"; then
        issues=$((issues + 1)); msg="$msg\n    - Encodage non-UTF8"
    fi

    # CRLF
    if grep -q $'\r' "$file"; then
        issues=$((issues + 1)); msg="$msg\n    - CRLF"
    fi

    # Espaces en fin
    count=$(grep -cE ' +$' "$file" 2>/dev/null || echo 0)
    if [ "$count" -gt 0 ]; then
        issues=$((issues + 1)); msg="$msg\n    - $count ligne(s) avec espaces en fin"
    fi

    # Saut final
    if [ -s "$file" ]; then
        last=$(tail -c 1 "$file" | od -An -c | tr -d ' ')
        if [ "$last" != "\\n" ]; then
            issues=$((issues + 1)); msg="$msg\n    - Pas de saut final"
        fi
    fi

    # Secrets
    if grep -qE "(password|secret|token|api_key)[[:space:]]*[:=][[:space:]]*['\"][^'\"]{8,}['\"]" "$file" 2>/dev/null; then
        if grep -E "(password|secret|token|api_key)[[:space:]]*[:=][[:space:]]*['\"][^'\"]{8,}['\"]" "$file" | grep -vqE "(placeholder|example|CHANGE_ME|YOUR_|<)"; then
            issues=$((issues + 1)); msg="$msg\n    - Secret potentiel"
        fi
    fi

    # TODO/FIXME (warning)
    todo=$(grep -cE "(TODO|FIXME|XXX|HACK):" "$file" 2>/dev/null || echo 0)
    if [ "$todo" -gt 0 ]; then
        TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1))
        msg="$msg\n    WARN: $todo TODO/FIXME"
    fi

    # SQL : parentheses + blocs DO
    if [[ "$file" == *.sql ]]; then
        op=$(grep -o "(" "$file" | wc -l)
        cp=$(grep -o ")" "$file" | wc -l)
        if [ "$op" -ne "$cp" ]; then
            issues=$((issues + 1)); msg="$msg\n    - Parentheses desequilibrees ($op vs $cp)"
        fi
        do_cnt=$(grep -c "DO \$\$" "$file" || echo 0)
        end_cnt=$(grep -c "END;" "$file" || echo 0)
        if [ "$do_cnt" -gt 0 ] && [ "$end_cnt" -lt "$do_cnt" ]; then
            issues=$((issues + 1)); msg="$msg\n    - Bloc DO non ferme"
        fi
    fi

    # Bash : shebang
    if [[ "$file" == *.sh ]]; then
        if ! head -1 "$file" | grep -q "^#!/"; then
            issues=$((issues + 1)); msg="$msg\n    - Shebang manquant"
        fi
    fi

    # Markdown : frontmatter
    if [[ "$file" == *.md ]]; then
        if ! head -1 "$file" | grep -q "^---$"; then
            TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1))
            msg="$msg\n    WARN: Frontmatter YAML manquant"
        fi
    fi

    if [ "$issues" -gt 0 ]; then
        echo -e "${RED}KO${NC} $rel"
        echo -e "$msg"
        TOTAL_ISSUES=$((TOTAL_ISSUES + issues))
    else
        echo -e "${GREEN}OK${NC} $rel"
    fi
done

echo ""
echo "=============================================="
echo "RESUME"
echo "=============================================="
echo "Fichiers analyses : $TOTAL_FILES"
echo "Erreurs           : $TOTAL_ISSUES"
echo "Avertissements    : $TOTAL_WARNINGS"
echo ""

if [ "$TOTAL_ISSUES" -eq 0 ]; then
    echo -e "${GREEN}STATUT : TOUS LES FICHIERS SONT PROPRES${NC}"
    exit 0
else
    echo -e "${RED}STATUT : $TOTAL_ISSUES erreur(s)${NC}"
    exit 1
fi
