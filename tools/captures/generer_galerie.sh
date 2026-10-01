#!/usr/bin/env bash
# =====================================================================
# generer_galerie.sh — Génère une galerie HTML pour sélection visuelle
# Usage : ./generer_galerie.sh
# =====================================================================
set -euo pipefail

RACINE=~/projets/ycognicore-cloud
COLLECTE="$RACINE/docs/rapports/captures/10-collecte"
GALERIE="$COLLECTE/galerie.html"

if [ ! -f "$COLLECTE/captures.csv" ]; then
    echo "❌ Erreur : captures.csv introuvable. Lancez d'abord collecter_captures.sh"
    exit 1
fi

echo "═══════════════════════════════════════════════════════"
echo "  GÉNÉRATION DE LA GALERIE HTML"
echo "═══════════════════════════════════════════════════════"

cat > "$GALERIE" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Sélection des captures — Journalier n°10</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Segoe UI', sans-serif;
            background: #f5f5f5;
            padding: 20px;
        }
        h1 {
            color: #1565c0;
            margin-bottom: 20px;
            border-bottom: 3px solid #0277bd;
            padding-bottom: 10px;
        }
        .stats {
            background: white;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
            display: flex;
            gap: 30px;
        }
        .stats span { font-weight: bold; color: #1565c0; }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 15px;
        }
        .capture {
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 6px rgba(0,0,0,0.1);
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .capture:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }
        .capture.doublon { opacity: 0.4; }
        .capture img {
            width: 100%;
            height: 160px;
            object-fit: cover;
            background: #eee;
        }
        .capture .infos {
            padding: 10px;
            font-size: 0.85em;
        }
        .capture .nom {
            font-family: monospace;
            font-size: 0.75em;
            color: #666;
            margin-bottom: 5px;
            word-break: break-all;
        }
        .capture .meta {
            display: flex;
            justify-content: space-between;
            color: #888;
        }
        .capture .actions {
            padding: 10px;
            border-top: 1px solid #eee;
            display: flex;
            gap: 10px;
        }
        .capture button {
            flex: 1;
            padding: 8px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-weight: 600;
            font-size: 0.85em;
        }
        .btn-garder {
            background: #c8e6c9;
            color: #2e7d32;
        }
        .btn-garder.selected {
            background: #2e7d32;
            color: white;
        }
        .btn-rejeter {
            background: #ffcdd2;
            color: #c62828;
        }
        .btn-rejeter.selected {
            background: #c62828;
            color: white;
        }
        .selection-box {
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: #1565c0;
            color: white;
            padding: 15px 25px;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
            font-weight: bold;
        }
        .selection-box #compteur { font-size: 1.5em; }
        #export {
            position: fixed;
            top: 20px;
            right: 20px;
            background: #e65100;
            color: white;
            padding: 12px 20px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-weight: bold;
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
        }
        #export:hover { background: #bf360c; }
    </style>
</head>
<body>
    <h1>📸 Sélection des captures — Rapport Journalier n°10</h1>
    
    <button id="export" onclick="exporterSelection()">💾 Exporter la sélection</button>
    
    <div class="stats" id="stats">
        Chargement...
    </div>
    
    <div class="grid" id="grid">
        Chargement des captures...
    </div>
    
    <div class="selection-box">
        Sélection : <span id="compteur">0</span>
    </div>

<script>
const CAPTURES_CSV = `CAPTURES_PLACEHOLDER`;

const lignes = CAPTURES_CSV.trim().split('\n').slice(1);
const captures = lignes.map(l => {
    const [chemin, taille, date, hash, doublon] = l.split(',');
    return { chemin, taille, date, hash, doublon, statut: null };
});

document.getElementById('stats').innerHTML = `
    <div>Total : <span>${captures.length}</span></div>
    <div>Doublons : <span>${captures.filter(c => c.doublon === 'oui').length}</span></div>
    <div>Uniques : <span>${captures.filter(c => c.doublon === 'non').length}</span></div>
`;

const grid = document.getElementById('grid');
grid.innerHTML = captures.map((c, i) => {
    const nomCourt = c.chemin.split('/').pop();
    const cheminFile = 'file://' + c.chemin;
    return `
        <div class="capture ${c.doublon === 'oui' ? 'doublon' : ''}" data-index="${i}">
            <img src="${cheminFile}" onerror="this.src='data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22280%22 height=%22160%22%3E%3Ctext x=%22140%22 y=%2280%22 text-anchor=%22middle%22 fill=%22%23999%22%3EAperçu non disponible%3C/text%3E%3C/svg%3E'">
            <div class="infos">
                <div class="nom">${nomCourt}</div>
                <div class="meta">
                    <span>${c.taille} Ko</span>
                    <span>${c.date.split(' ')[1].slice(0, 5)}</span>
                </div>
            </div>
            <div class="actions">
                <button class="btn-garder" onclick="marquer(${i}, 'garder')">✓ Garder</button>
                <button class="btn-rejeter" onclick="marquer(${i}, 'rejeter')">✗ Rejeter</button>
            </div>
        </div>
    `;
}).join('');

function marquer(index, statut) {
    const div = document.querySelector(`[data-index="${index}"]`);
    const btnGarder = div.querySelector('.btn-garder');
    const btnRejeter = div.querySelector('.btn-rejeter');
    
    if (captures[index].statut === statut) {
        captures[index].statut = null;
        btnGarder.classList.remove('selected');
        btnRejeter.classList.remove('selected');
    } else {
        captures[index].statut = statut;
        btnGarder.classList.toggle('selected', statut === 'garder');
        btnRejeter.classList.toggle('selected', statut === 'rejeter');
    }
    
    majCompteur();
}

function majCompteur() {
    const gardees = captures.filter(c => c.statut === 'garder').length;
    document.getElementById('compteur').textContent = gardees;
}

function exporterSelection() {
    const gardees = captures.filter(c => c.statut === 'garder');
    if (gardees.length === 0) {
        alert('Aucune capture sélectionnée.');
        return;
    }
    
    let texte = '# Sélection finale des captures\n\n';
    texte += `Total sélectionné : ${gardees.length}\n\n`;
    texte += '| # | Chemin | Taille (Ko) | Date |\n';
    texte += '|---|---|---|---|\n';
    gardees.forEach((c, i) => {
        texte += `| ${i+1} | \`${c.chemin}\` | ${c.taille} | ${c.date} |\n`;
    });
    
    const blob = new Blob([texte], { type: 'text/markdown' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'captures_selectionnees.md';
    a.click();
}

majCompteur();
</script>
</body>
</html>
HTMLEOF

# Remplacer le placeholder par le contenu CSV
CSV_CONTENT=$(cat "$COLLECTE/captures.csv")
python3 << PYEOF
from pathlib import Path

fichier = Path("$GALERIE")
contenu = fichier.read_text(encoding="utf-8")
csv_content = """$CSV_CONTENT"""
contenu = contenu.replace("CAPTURES_PLACEHOLDER", csv_content)
fichier.write_text(contenu, encoding="utf-8")
PYEOF

echo ""
echo "✅ Galerie générée : $GALERIE"
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  OUVREZ LA GALERIE DANS UN NAVIGATEUR :"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  firefox $GALERIE"
echo "  ou"
echo "  google-chrome $GALERIE"
echo ""
