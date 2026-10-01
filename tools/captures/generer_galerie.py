#!/usr/bin/env python3
"""
generer_galerie.py — Génère une galerie HTML pour sélection visuelle
Usage : python3 generer_galerie.py
"""
import os
import re
from pathlib import Path
from datetime import datetime

RACINE = Path.home() / "projets" / "ycognicore-cloud"
SRC = RACINE / "docs/rapports/captures/10-travail"
DEST_HTML = RACINE / "docs/rapports/captures/10-travail/galerie.html"

print("═══════════════════════════════════════════════════════")
print("  GÉNÉRATION DE LA GALERIE HTML")
print("═══════════════════════════════════════════════════════")

# Lister toutes les images
images = []
for f in sorted(SRC.glob("*.png")):
    stats = f.stat()
    # Extraire l'heure depuis le nom si possible
    match = re.search(r'(\d{2})h(\d{2})m', f.name)
    heure = f"{match.group(1)}:{match.group(2)}" if match else "?"

    images.append({
        "nom": f.name,
        "chemin": f"10-travail/{f.name}",
        "taille": stats.st_size // 1024,  # Ko
        "heure": heure,
    })

print(f"  → {len(images)} images trouvées")

# Générer HTML
html = """<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Sélection des captures — Journalier n°10</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Segoe UI', sans-serif; background: #f5f5f5; padding: 20px; }
        h1 { color: #1565c0; margin-bottom: 15px; padding-bottom: 10px; border-bottom: 3px solid #0277bd; }
        .toolbar {
            background: white; padding: 15px; border-radius: 8px; margin-bottom: 15px;
            display: flex; gap: 15px; align-items: center; flex-wrap: wrap;
            position: sticky; top: 0; z-index: 100; box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        .toolbar input[type="text"] {
            padding: 8px 12px; border: 1px solid #ddd; border-radius: 4px; font-size: 1em;
            width: 200px;
        }
        .toolbar button {
            padding: 8px 15px; border: none; border-radius: 4px; cursor: pointer;
            font-weight: 600; font-size: 0.9em;
        }
        .btn-export { background: #e65100; color: white; }
        .btn-export:hover { background: #bf360c; }
        .btn-reset { background: #eee; color: #333; }
        .btn-filter { background: #1565c0; color: white; }
        .stats { color: #666; font-size: 0.9em; }
        .stats b { color: #1565c0; font-size: 1.2em; }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 10px;
        }
        .capture {
            background: white; border-radius: 6px; overflow: hidden;
            box-shadow: 0 1px 4px rgba(0,0,0,0.1); cursor: pointer;
            transition: transform 0.15s, box-shadow 0.15s;
            position: relative;
        }
        .capture:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(0,0,0,0.2); }
        .capture img {
            width: 100%; height: 120px; object-fit: cover; background: #eee;
            display: block;
        }
        .capture .info {
            padding: 6px 8px; font-size: 0.7em;
            font-family: monospace; color: #555;
            white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
        }
        .capture .badge {
            position: absolute; top: 4px; right: 4px;
            background: #2e7d32; color: white;
            padding: 2px 6px; border-radius: 4px;
            font-size: 0.7em; font-weight: bold;
        }
        .capture.selected { outline: 4px solid #2e7d32; }
        .capture.selected::after {
            content: "✓"; position: absolute; top: 50%; left: 50%;
            transform: translate(-50%, -50%);
            font-size: 4em; color: rgba(46, 125, 50, 0.7);
            font-weight: bold; pointer-events: none;
        }
    </style>
</head>
<body>
    <h1>📸 Sélection des captures — Journalier n°10</h1>
    
    <div class="toolbar">
        <span class="stats">Total : <b id="total">0</b></span>
        <span class="stats">Sélectionnées : <b id="sel-count">0</b></span>
        <input type="text" id="filtre-heure" placeholder="Filtrer par heure (ex: 15)">
        <button class="btn-filter" onclick="appliquerFiltre()">Filtrer</button>
        <button class="btn-reset" onclick="resetFiltre()">Reset</button>
        <button class="btn-export" onclick="exporter()">💾 Exporter la sélection</button>
    </div>
    
    <div class="grid" id="grid"></div>
    
<script>
const IMAGES = IMAGES_PLACEHOLDER;
const selection = new Set();

function render(liste) {
    document.getElementById('grid').innerHTML = liste.map(img => {
        const isSelected = selection.has(img.nom);
        return `
            <div class="capture ${isSelected ? 'selected' : ''}" 
                 data-nom="${img.nom}"
                 onclick="toggle('${img.nom}')">
                <img src="${img.chemin}" loading="lazy" 
                     onerror="this.src='data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22200%22 height=%22120%22%3E%3Ctext x=%22100%22 y=%2265%22 text-anchor=%22middle%22 fill=%22%23999%22 font-size=%2214%22%3E${img.nom}%3C/text%3E%3C/svg%3E'">
                ${isSelected ? '<div class="badge">SÉLECTIONNÉE</div>' : ''}
                <div class="info">${img.nom.replace(/_/g, ' ')}</div>
            </div>
        `;
    }).join('');
    document.getElementById('total').textContent = liste.length;
    document.getElementById('sel-count').textContent = selection.size;
}

function toggle(nom) {
    if (selection.has(nom)) selection.delete(nom);
    else selection.add(nom);
    render(IMAGES);
}

function appliquerFiltre() {
    const f = document.getElementById('filtre-heure').value.trim();
    if (!f) { render(IMAGES); return; }
    const filtree = IMAGES.filter(img => img.nom.includes(f));
    render(filtree);
}

function resetFiltre() {
    document.getElementById('filtre-heure').value = '';
    render(IMAGES);
}

function exporter() {
    if (selection.size === 0) { alert('Aucune capture sélectionnée.'); return; }
    const lignes = ['# Sélection finale des captures\n', `Total : ${selection.size}\n`];
    let i = 1;
    for (const nom of Array.from(selection).sort()) {
        lignes.push(`${i}. ${nom}`);
        i++;
    }
    const blob = new Blob([lignes.join('\n')], { type: 'text/markdown' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'captures_selectionnees.md';
    a.click();
}

render(IMAGES);
</script>
</body>
</html>
"""

# Remplacer le placeholder
images_json = "[\n"
for img in images:
    images_json += f'    {{"nom": "{img["nom"]}", "chemin": "{img["chemin"]}", "heure": "{img["heure"]}"}},\n'
images_json += "]"

html = html.replace("IMAGES_PLACEHOLDER", images_json)

DEST_HTML.write_text(html, encoding="utf-8")

print(f"  ✅ Galerie générée : {DEST_HTML}")
print("")
print("═══════════════════════════════════════════════════════")
print("  OUVREZ LA GALERIE DANS UN NAVIGATEUR :")
print("═══════════════════════════════════════════════════════")
print("")
print(f"  firefox {DEST_HTML}")
print(f"  ou")
print(f"  google-chrome {DEST_HTML}")
print("")
