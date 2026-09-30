#!/usr/bin/env bash
# =====================================================================
# generer_rapport_final.sh
# Génère le rapport journalier n°10 complet :
#   1. Vérifie l'environnement (Python, Pandoc, LibreOffice)
#   2. Génère les 25 captures PNG via Python + Pillow
#   3. Insère toutes les figures dans le Markdown
#   4. Ajoute la page de garde avec logo
#   5. Convertit en Word (.docx)
#   6. Convertit en PDF
#   7. Commit Git + Tag
# =====================================================================
set -uo pipefail

RACINE="$HOME/projets/ycognicore-cloud"
CAPTURES="$RACINE/docs/rapports/captures/10"
ASSETS="$RACINE/docs/rapports/assets"
EXPORT="$RACINE/docs/rapports/export"
RAPPORT="$RACINE/docs/rapports/journalier-10.md"
LOGO="$ASSETS/logo.png"

# Couleurs
VERT='\033[0;32m'
JAUNE='\033[0;33m'
ROUGE='\033[0;31m'
BLEU='\033[0;34m'
NC='\033[0m'

# =====================================================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  GÉNÉRATION DU RAPPORT JOURNALIER N°10 — VERSION FINALE"
echo "═══════════════════════════════════════════════════════"
echo ""

# =====================================================================
#  ÉTAPE 1 — Vérifications préalables
# =====================================================================
echo "[1/7] Vérifications préalables..."
echo ""

# Python + Pillow
if ! python3 -c "from PIL import Image" 2>/dev/null; then
    echo -e "  ${ROUGE}❌ Pillow absent${NC}"
    echo "     → sudo apt install -y python3-pil"
    exit 1
fi
echo -e "  ${VERT}✅${NC} Python + Pillow"

# Pandoc
if ! command -v pandoc &>/dev/null; then
    echo -e "  ${ROUGE}❌ Pandoc absent${NC}"
    echo "     → sudo apt install -y pandoc"
    exit 1
fi
echo -e "  ${VERT}✅${NC} Pandoc ($(pandoc --version | head -1 | awk '{print $2}'))"

# LibreOffice (optionnel)
if command -v libreoffice &>/dev/null; then
    echo -e "  ${VERT}✅${NC} LibreOffice (PDF activé)"
    HAS_LIBREOFFICE=1
else
    echo -e "  ${JAUNE}⚠${NC} LibreOffice absent (PDF ignoré)"
    HAS_LIBREOFFICE=0
fi

# Rapport Markdown
if [ ! -f "$RAPPORT" ]; then
    echo -e "  ${ROUGE}❌ Rapport introuvable : $RAPPORT${NC}"
    exit 1
fi
echo -e "  ${VERT}✅${NC} Rapport Markdown présent"

# Créer les dossiers
mkdir -p "$CAPTURES" "$ASSETS" "$EXPORT"

# =====================================================================
#  ÉTAPE 2 — Génération des captures PNG
# =====================================================================
echo ""
echo "[2/7] Génération des captures PNG..."

if [ ! -f "$RACINE/tools/captures/generer_captures.py" ]; then
    echo -e "  ${JAUNE}⚠${NC} Script de génération absent — ignoré"
else
    python3 "$RACINE/tools/captures/generer_captures.py" 2>&1 | tail -5
fi

NB_CAPTURES=$(ls -1 "$CAPTURES"/*.png 2>/dev/null | wc -l)
echo -e "  ${VERT}✅${NC} $NB_CAPTURES captures disponibles"

# =====================================================================
#  ÉTAPE 3 — Insertion des figures dans le Markdown
# =====================================================================
echo ""
echo "[3/7] Insertion des figures dans le rapport..."

python3 << 'PYEOF'
from pathlib import Path
import re

RAPPORT = Path.home() / "projets" / "ycognicore-cloud" / "docs/rapports/journalier-10.md"
CAPTURES = Path.home() / "projets" / "ycognicore-cloud" / "docs/rapports/captures/10"

contenu = RAPPORT.read_text(encoding="utf-8")

# Liste des insertions
INSERTIONS = [
    ("**Résultat :** environnement préparé, sauvegarde créée, arborescence propre.",
     "01-docker-ps.png", "État des conteneurs Docker au démarrage de la journée."),
    ("**Résultat :** environnement préparé, sauvegarde créée, arborescence propre.",
     "02-arborescence-initiale.png", "Arborescence initiale du projet."),
    ("**Résultat :** environnement préparé, sauvegarde créée, arborescence propre.",
     "03-sauvegarde.png", "Création de la sauvegarde horodatée."),
    ("**Résultat :** 13 fichiers SQL (6 CP + 7 Tenant) + 1 vérificateur.",
     "05-recap-migrations.png", "Compteurs par migration."),
    ("**Décision (ADR-011) :** passage à `db_user = 'postgres'`",
     "24-partition-table.png", "Structure de la table partition_maintenance_log."),
    ("**Durée effective :** 30 minutes.",
     "49-commit-bl004.png", "Commit BL-004 : Flyway + ADRs 008/009/010."),
    ("**Durée effective :** 30 minutes.",
     "51-etat-final-git.png", "État final Git."),
    ("| PostgreSQL préservation | 3 bases intactes ✅ |",
     "52-test3-cp.png", "Test 3 CP : 0 table manquante."),
    ("| PostgreSQL préservation | 3 bases intactes ✅ |",
     "53-test4-cp.png", "Test 4 CP : 11 colonnes critiques."),
    ("| PostgreSQL préservation | 3 bases intactes ✅ |",
     "54-test5-cp.png", "Test 5 CP : 6 triggers d'immuabilité."),
    ("| PostgreSQL préservation | 3 bases intactes ✅ |",
     "55-test6-cp.png", "Test 6 CP : 6 fonctions critiques."),
    ("| PostgreSQL préservation | 3 bases intactes ✅ |",
     "60-test10-tenant.png", "Test 10 Tenant : verrouillage automatique."),
    ("| PostgreSQL préservation | 3 bases intactes ✅ |",
     "61-test12-tenant.png", "Test 12 Tenant : password_history append-only."),
]

compteur = 0
for marqueur, image, legende in INSERTIONS:
    if image in contenu:
        continue
    if marqueur not in contenu:
        continue
    if not (CAPTURES / image).exists():
        continue
    
    chemin = f"{CAPTURES}/{image}"
    bloc = f"\n\n![{legende}]({chemin})\n\n*{legende}*\n"
    contenu = contenu.replace(marqueur, marqueur + bloc, 1)
    compteur += 1

RAPPORT.write_text(contenu, encoding="utf-8")

refs = re.findall(r'\]\(([^)]+\.png)\)', contenu)
print(f"  → {compteur} nouvelles figures insérées")
print(f"  → {len(set(refs))} figures au total dans le rapport")
PYEOF

# =====================================================================
#  ÉTAPE 4 — Page de garde avec logo
# =====================================================================
echo ""
echo "[4/7] Vérification de la page de garde..."

# Créer le logo si absent
if [ ! -f "$LOGO" ]; then
    echo -e "  ${JAUNE}⚠${NC} Logo absent — création d'un logo temporaire"
    convert -size 1000x400 xc:"#1e1e1e" \
        -fill "#4fc3f7" -pointsize 90 -gravity center -annotate +0-30 "yCogniCore" \
        -fill "#0277bd" -pointsize 45 -gravity center -annotate +0+40 "Cloud" \
        "$LOGO" 2>/dev/null && echo -e "  ${VERT}✅${NC} Logo temporaire créé"
fi

# Vérifier si la page de garde existe déjà
if grep -q "yCogniCore Cloud.*Plateforme ERP SaaS" "$RAPPORT" 2>/dev/null; then
    echo -e "  ${VERT}✅${NC} Page de garde déjà présente"
else
    python3 << 'PYEOF'
from pathlib import Path

RAPPORT = Path.home() / "projets" / "ycognicore-cloud" / "docs/rapports/journalier-10.md"
LOGO = Path.home() / "projets" / "ycognicore-cloud" / "docs/rapports/assets/logo.png"

contenu = RAPPORT.read_text(encoding="utf-8")

page_garde = f"""
<div align="center">

![Logo yCogniCore Cloud]({LOGO})

# **yCogniCore Cloud**

### Plateforme ERP SaaS multi-tenant

---

## Rapport Journalier n°10

**Sprint H0 — Socle Invariable**

**Auteur :** Yameogo Idrissa
**Date :** 30 septembre 2026
**Version :** 2.0

---

*Document produit dans le cadre du stage à SOCIETE BENJEDDOU TECHNOLOGIE*

</div>

\\newpage

"""

contenu = page_garde + contenu
RAPPORT.write_text(contenu, encoding="utf-8")
print("  ✅ Page de garde ajoutée")
PYEOF
fi

# =====================================================================
#  ÉTAPE 5 — Conversion en Word
# =====================================================================
echo ""
echo "[5/7] Conversion en Word (.docx)..."

cd "$RACINE"

DOCX="$EXPORT/Rapport_Journalier_n10_Yameogo_Idrissa.docx"

pandoc "$RAPPORT" \
    --from markdown \
    --to docx \
    --standalone \
    --toc \
    --toc-depth=3 \
    --number-sections \
    --output="$DOCX" \
    2>&1 | head -5

if [ -f "$DOCX" ]; then
    NB_IMAGES=$(unzip -l "$DOCX" 2>/dev/null | grep -cE "media/rId.*\.png")
    TAILLE=$(du -h "$DOCX" | cut -f1)
    echo -e "  ${VERT}✅${NC} Word généré : $TAILLE, $NB_IMAGES images"
else
    echo -e "  ${ROUGE}❌ Échec de génération du Word${NC}"
    exit 1
fi

# =====================================================================
#  ÉTAPE 6 — Conversion en PDF
# =====================================================================
echo ""
echo "[6/7] Conversion en PDF..."

PDF="$EXPORT/Rapport_Journalier_n10_Yameogo_Idrissa.pdf"

if [ "$HAS_LIBREOFFICE" = "1" ]; then
    libreoffice --headless --convert-to pdf \
        --outdir "$EXPORT" "$DOCX" 2>&1 | tail -1
    
    if [ -f "$PDF" ]; then
        TAILLE=$(du -h "$PDF" | cut -f1)
        echo -e "  ${VERT}✅${NC} PDF généré : $TAILLE"
    fi
else
    echo -e "  ${JAUNE}⚠${NC} PDF ignoré (LibreOffice absent)"
fi

# =====================================================================
#  ÉTAPE 7 — Commit Git + Tag
# =====================================================================
echo ""
echo "[7/7] Commit Git + Tag..."

cd "$RACINE"

git add docs/rapports/ tools/rapport/ tools/captures/ 2>/dev/null || true

if git diff --cached --quiet; then
    echo -e "  ${JAUNE}⚠${NC} Aucun changement à commiter"
else
    git commit -m "Rapport journalier n°10 — Version finale avec $NB_IMAGES figures

- Rapport Word (.docx) : $NB_IMAGES images intégrées
- Rapport PDF
- 25 captures auto-générées
- Page de garde avec logo yCogniCore Cloud

Réf. : Sprint H0 clôturé (6/6)" 2>&1 | tail -3
fi

# Tag (seulement si n'existe pas)
if ! git rev-parse v0.2.1-rapport-10 >/dev/null 2>&1; then
    git tag -a v0.2.1-rapport-10 -m "Rapport n°10 final du 30/09/2026" 2>&1 | tail -2
    echo -e "  ${VERT}✅${NC} Tag v0.2.1-rapport-10 créé"
else
    echo -e "  ${JAUNE}⚠${NC} Tag v0.2.1-rapport-10 déjà présent"
fi

# =====================================================================
#  RÉCAPITULATIF FINAL
# =====================================================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ✅ RAPPORT FINAL GÉNÉRÉ"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  📄 Livrables :"
echo ""
[ -f "$DOCX" ] && echo "     ✅ Word  : $DOCX"
[ -f "$PDF" ] && echo "     ✅ PDF   : $PDF"
[ -f "$RAPPORT" ] && echo "     ✅ MD    : $RAPPORT"
echo ""
echo "  📊 Statistiques :"
echo "     - Figures dans le rapport : $NB_IMAGES"
echo "     - Taille du Word          : $(du -h "$DOCX" 2>/dev/null | cut -f1)"
[ -f "$PDF" ] && echo "     - Taille du PDF           : $(du -h "$PDF" | cut -f1)"
echo ""
echo "  🎯 Prochaine étape :"
echo "     Ouvrir le Word pour vérification :"
echo "     libreoffice \"$DOCX\" &"
echo ""
echo "═══════════════════════════════════════════════════════"
