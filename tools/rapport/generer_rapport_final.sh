#!/usr/bin/env bash
# =====================================================================
# generer_rapport_final.sh
# Copie les captures Windows, les renomme, génère le rapport Word
# =====================================================================
set -euo pipefail

# ---- Configuration -------------------------------------------------
RACINE="$HOME/projets/ycognicore-cloud"

# Chemin Windows (source)
WIN_PATH="/mnt/c/Users/Tedis/Documents/Yameogo Idrissa/STAGE/SOCIETE BENJEDDOU TECHNOLOGIE/captures"

# Dossiers cibles
CAPTURES_WORK="$RACINE/docs/rapports/captures/10-travail"
CAPTURES_FINAL="$RACINE/docs/rapports/captures/10"
ASSETS="$RACINE/docs/rapports/assets"
SORTIE="$RACINE/docs/rapports/export"
RAPPORT_MD="$RACINE/docs/rapports/journalier-10.md"

# Couleurs
VERT='\033[0;32m'
JAUNE='\033[0;33m'
ROUGE='\033[0;31m'
BLEU='\033[0;34m'
NC='\033[0m'

# ---- En-tête -------------------------------------------------------
clear
echo "═══════════════════════════════════════════════════════"
echo "  GÉNÉRATION FINALE DU RAPPORT JOURNALIER N°10"
echo "═══════════════════════════════════════════════════════"
echo ""

# ---- Étape 1 — Vérifications --------------------------------------
echo "[1/7] Vérifications préalables..."

if [ ! -d "$WIN_PATH" ]; then
    echo -e "  ${ROUGE}❌ Chemin Windows introuvable${NC}"
    echo "     $WIN_PATH"
    exit 1
fi
NB_TOTAL=$(find "$WIN_PATH" -maxdepth 1 -type f -iname "*.png" 2>/dev/null | wc -l)
echo -e "  ${VERT}✅${NC} Captures trouvées : $NB_TOTAL fichiers PNG"

if [ ! -f "$RAPPORT_MD" ]; then
    echo -e "  ${JAUNE}⚠${NC} Rapport Markdown absent — il sera créé"
fi

if ! command -v pandoc &>/dev/null; then
    echo -e "  ${ROUGE}❌ Pandoc non installé${NC}"
    echo "     → sudo apt install -y pandoc"
    exit 1
fi
echo -e "  ${VERT}✅${NC} Pandoc disponible"

# ---- Étape 2 — Création de l'arborescence -------------------------
echo ""
echo "[2/7] Création de l'arborescence..."

mkdir -p "$CAPTURES_WORK"
mkdir -p "$CAPTURES_FINAL"
mkdir -p "$ASSETS"
mkdir -p "$SORTIE"

echo -e "  ${VERT}✅${NC} Dossiers créés"

# ---- Étape 3 — Copie des captures ---------------------------------
echo ""
echo "[3/7] Copie des captures depuis Windows..."

# Nettoyer le dossier de travail précédent
rm -f "$CAPTURES_WORK"/*.png 2>/dev/null || true

COUNT=0
find "$WIN_PATH" -maxdepth 1 -type f -iname "*.png" | while read -r fichier; do
    nom=$(basename "$fichier")
    # Nettoyer le nom (espaces, apostrophes, accents)
    nom_clean=$(echo "$nom" | sed 's/ /_/g' | sed "s/'//g" | sed 's/é/e/g' | sed 's/è/e/g')
    cp "$fichier" "$CAPTURES_WORK/$nom_clean"
    COUNT=$((COUNT + 1))
done

NB_COPIES=$(ls -1 "$CAPTURES_WORK"/*.png 2>/dev/null | wc -l)
echo -e "  ${VERT}✅${NC} $NB_COPIES captures copiées dans 10-travail/"

# ---- Étape 4 — Génération du mapping intelligent ------------------
echo ""
echo "[4/7] Analyse des captures par horodatage..."

# Script Python pour générer un mapping intelligent basé sur les horaires
python3 << 'PYEOF'
import re
import shutil
from pathlib import Path
from datetime import datetime

RACINE = Path.home() / "projets" / "ycognicore-cloud"
SRC = RACINE / "docs/rapports/captures/10-travail"
DEST = RACINE / "docs/rapports/captures/10"

def extraire_datetime(img):
    """Extrait la datetime depuis le nom ou le mtime"""
    # Format : Capture_d'écran_2026-09-30_145703.png
    m = re.search(r'_(\d{4})-(\d{2})-(\d{2})_(\d{2})(\d{2})(\d{2})', img.name)
    if m:
        return datetime(int(m.group(1)), int(m.group(2)), int(m.group(3)),
                       int(m.group(4)), int(m.group(5)), int(m.group(6)))
    # Format : 14h57m03s
    m = re.search(r'(\d{2})h(\d{2})m(\d{2})s', img.name)
    if m:
        return datetime(2026, 9, 30, int(m.group(1)), int(m.group(2)), int(m.group(3)))
    # Fallback : mtime
    return datetime.fromtimestamp(img.stat().st_mtime)

# Charger toutes les captures avec leur datetime
captures = []
for img in SRC.glob("*.png"):
    captures.append((extraire_datetime(img), img))
captures.sort(key=lambda x: x[0])

print(f"  → {len(captures)} captures analysées")

# Mapping : figure → fenêtre horaire
# Basé sur le déroulement de la journée
MAPPING_HORAIRE = {
    # Briefing et sauvegarde (08h30 - 09h30)
    "02-arborescence-initiale.png": (8, 30, 9, 30),
    "03-sauvegarde.png":            (8, 30, 9, 30),
    # Reconstruction 13 migrations (09h30 - 10h30)
    "04-13-migrations.png":         (9, 30, 10, 30),
    # Flyway (11h30 - 12h30)
    "08-tab-detection.png":         (11, 30, 12, 30),
    "09-flyway-pom.png":            (11, 30, 12, 30),
    "10-validation-compilation.png":(11, 30, 12, 30),
    "11-application-yml.png":       (11, 30, 12, 30),
    "16-boot4-starters.png":        (11, 30, 12, 30),
    "19-flyway-history.png":        (11, 30, 12, 30),
    "20-nb-tables-seeds.png":       (11, 30, 12, 30),
    "21-etat-apres-seed.png":       (11, 30, 12, 30),
    "22-flyway-history-7.png":      (12, 30, 13, 30),
    # BL-005 Partitions (12h30 - 13h30)
    "23-v7-created.png":            (12, 30, 13, 30),
    "24-partition-table.png":       (12, 30, 13, 30),
    "25-compilation-demarrage.png": (12, 30, 13, 30),
    "26-endpoint-0.png":            (13, 30, 14, 0),
    "27-errors-password.png":       (13, 30, 14, 0),
    "28-alter-role.png":            (13, 30, 14, 0),
    "29-tenant-databases.png":      (13, 30, 14, 0),
    "30-endpoint-success.png":      (13, 30, 14, 0),
    "31-partitions-demo001.png":    (13, 30, 14, 0),
    "32-partitions-demo002.png":    (13, 30, 14, 0),
    "33-journal-cp.png":            (13, 30, 14, 0),
    "34-5-dernieres.png":           (13, 30, 14, 0),
    # BL-006 Docker (14h00 - 15h00)
    "01-pgsty-pull.png":            (14, 0, 15, 0),
    "35-volumes.png":               (14, 0, 14, 30),
    "36-ports.png":                 (14, 0, 14, 30),
    "37-dumps.png":                 (14, 0, 14, 30),
    "38-validation-yaml.png":       (14, 0, 14, 30),
    "39-images-modif.png":          (14, 0, 14, 30),
    "40-test-pull.png":             (14, 0, 15, 0),
    "41-docker-up.png":             (14, 30, 15, 0),
    "42-healthcheck.png":           (14, 30, 15, 0),
    "43-vault-healthy.png":         (14, 30, 15, 0),
    "44-verif-pg.png":              (14, 30, 15, 0),
    "45-tests-services.png":        (14, 30, 15, 0),
    "46-init-vault-ok.png":         (14, 30, 15, 0),
    "47-init-minio-ok.png":         (14, 30, 15, 0),
    "48-recap-bl006.png":           (14, 30, 15, 0),
    # Git / Tests (15h00 - 16h00)
    "49-commit-bl004.png":          (15, 0, 16, 0),
    "50-commit-chore.png":          (15, 0, 16, 0),
    "51-etat-final-git.png":        (15, 0, 16, 0),
    "62-isolation-proof.png":       (15, 0, 16, 0),
    "63-generation-dumps.png":      (15, 0, 16, 0),
    # Tests CP/Tenant (dans le désordre horaire — chercher par contenu)
    # On les assignera plus tard
}

# Assigner les captures avec fenêtre horaire
resultats = {}
deja_utilisees = set()

for cible, (h_debut, m_debut, h_fin, m_fin) in MAPPING_HORAIRE.items():
    debut = datetime(2026, 9, 30, h_debut, m_debut)
    fin = datetime(2026, 9, 30, h_fin, m_fin)
    
    candidates = [(dt, img) for dt, img in captures 
                  if debut <= dt <= fin and img.name not in deja_utilisees]
    
    if candidates:
        # Prendre la première ou du milieu
        dt, img = candidates[len(candidates)//2]
        resultats[cible] = img
        deja_utilisees.add(img.name)

# Afficher le mapping
print(f"  → {len(resultats)} captures assignées automatiquement")
print()

# Copier avec les bons noms
compteur = 0
for cible, source in resultats.items():
    dest = DEST / cible
    shutil.copy2(source, dest)
    compteur += 1

print(f"  ✅ {compteur} captures copiées dans docs/rapports/captures/10/")

# Créer un fichier de suivi
tracking = RACINE / "docs/rapports/captures/10-mapping.txt"
with open(tracking, "w", encoding="utf-8") as f:
    f.write("# Mapping captures → figures du rapport\n\n")
    for cible, source in sorted(resultats.items()):
        f.write(f"{cible}  ←  {source.name}\n")
    f.write(f"\nTotal : {len(resultats)} captures assignées\n")
    f.write(f"Non assignées : {len(captures) - len(resultats)}\n")

print(f"  📝 Suivi : {tracking}")
PYEOF

# ---- Étape 5 — Vérification du logo -------------------------------
echo ""
echo "[5/7] Vérification du logo..."

if [ ! -f "$ASSETS/logo.png" ]; then
    echo -e "  ${JAUNE}⚠${NC} Logo absent : $ASSETS/logo.png"
    echo "     → Placez votre logo PNG à cet endroit pour la page de garde."
    echo "     → Le document sera généré sans logo (l'espace sera vide)."
else
    echo -e "  ${VERT}✅${NC} Logo trouvé : $ASSETS/logo.png"
    ls -lh "$ASSETS/logo.png"
fi

# ---- Étape 6 — Génération du Word ---------------------------------
echo ""
echo "[6/7] Génération du document Word..."

DOCX="$SORTIE/Rapport_Journalier_n10_Yameogo_Idrissa.docx"
REFERENCE="$SORTIE/reference.docx"

# Créer un fichier de référence Word pour les styles
pandoc --print-default-data-file reference.docx > "$REFERENCE" 2>/dev/null || true

if [ ! -f "$RAPPORT_MD" ]; then
    echo -e "  ${ROUGE}❌ Rapport Markdown absent${NC}"
    echo "     → Créez d'abord : $RAPPORT_MD"
    exit 1
fi

cd "$RACINE"

# Conversion Markdown → Word
pandoc "$RAPPORT_MD" \
    --from markdown \
    --to docx \
    --standalone \
    --toc \
    --toc-depth=3 \
    --number-sections \
    --resource-path="$RACINE:$CAPTURES_FINAL:$ASSETS" \
    --output="$DOCX" \
    --metadata title="Rapport Journalier n°10" \
    --metadata subtitle="Sprint H0 — Socle Invariable" \
    --metadata author="Yameogo Idrissa" \
    --metadata date="30 septembre 2026" \
    ${REFERENCE:+--reference-doc="$REFERENCE"} \
    2>&1 | tail -5

if [ -f "$DOCX" ]; then
    echo ""
    echo -e "  ${VERT}✅ Rapport Word généré${NC}"
    ls -lh "$DOCX"
else
    echo -e "  ${ROUGE}❌ Échec de la génération${NC}"
    exit 1
fi

# ---- Étape 7 — Génération PDF (si LibreOffice dispo) --------------
echo ""
echo "[7/7] Génération du PDF (optionnel)..."

PDF="$SORTIE/Rapport_Journalier_n10_Yameogo_Idrissa.pdf"

if command -v libreoffice &>/dev/null; then
    libreoffice --headless --convert-to pdf \
        --outdir "$SORTIE" "$DOCX" &>/dev/null && \
        echo -e "  ${VERT}✅ PDF généré : $PDF${NC}" || \
        echo -e "  ${JAUNE}⚠ Conversion PDF échouée${NC}"
else
    echo -e "  ${JAUNE}⚠ LibreOffice non installé — PDF ignoré${NC}"
fi

# ---- Récapitulatif -------------------------------------------------
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ✅ GÉNÉRATION TERMINÉE"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  📄 Rapport Word : $DOCX"
[ -f "$PDF" ] && echo "  📄 Rapport PDF  : $PDF"
echo ""
echo "  📊 Statistiques :"
echo "     - Captures totales    : $NB_COPIES"
echo "     - Captures assignées  : $(ls -1 $CAPTURES_FINAL/*.png 2>/dev/null | wc -l)"
echo "     - Taille du Word      : $(du -h $DOCX | cut -f1)"
echo ""
echo "  🎯 Prochaines étapes :"
echo "     1. Ouvrir : libreoffice $DOCX &"
echo "     2. Vérifier la page de garde et la TOC"
echo "     3. Ajuster les captures mal assignées si besoin"
echo "     4. Enregistrer la vidéo de démonstration"
echo ""
echo "  📝 Fichier de suivi : docs/rapports/captures/10-mapping.txt"
echo ""
