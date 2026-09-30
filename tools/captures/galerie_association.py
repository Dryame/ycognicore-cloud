#!/usr/bin/env python3
"""
galerie_association.py — Galerie avec menus déroulants pour associer
chaque capture à une catégorie cible (les 12 du rapport).
Génère un fichier mapping.json qui sera lu par le script de copie.
"""
from pathlib import Path

RACINE = Path.home() / "projets" / "ycognicore-cloud"
SRC = RACINE / "docs/rapports/captures/10-travail"
DEST = SRC / "galerie_association.html"

# Les 12 cibles
CIBLES = [
    ("", "— Ignorer cette capture —"),
    ("01-docker-services.png", "01 — Services Docker (4 healthy)"),
    ("02-minio-buckets.png", "02 — MinIO buckets (3 buckets)"),
    ("03-vault-keys.png", "03 — Vault keys (ycc-mfa-key)"),
    ("04-redis-minio-tests.png", "04 — Tests Redis+Vault+MinIO"),
    ("05-postgres-bases.png", "05 — Bases PostgreSQL préservées"),
    ("06-flyway-history.png", "06 — Flyway history (V1-V7)"),
    ("07-endpoint-run.png", "07 — Endpoint run (12 partitions)"),
    ("08-endpoint-history.png", "08 — Endpoint history (SUCCES)"),
    ("09-partitions-demo001.png", "09 — Partitions demo001 créées"),
    ("10-13-migrations.png", "10 — 13 migrations vérifiées"),
    ("11-git-log.png", "11 — Git log (commits du jour)"),
    ("12-git-tags.png", "12 — Git tags (v0.1.0, v0.2.0)"),
]

images = sorted(SRC.glob("*.png"))
print(f"→ {len(images)} images trouvées")

options_html = "".join(
    f'<option value="{val}">{label}</option>' for val, label in CIBLES
)

html = """<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Association des captures — Journalier n°10</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: 'Segoe UI', sans-serif; background: #f5f5f5; padding: 20px; }
h1 { color: #1565c0; margin-bottom: 15px; padding-bottom: 10px; border-bottom: 3px solid #0277bd; }
.toolbar {
    background: white; padding: 15px; border-radius: 8px; margin-bottom: 15px;
    display: flex; gap: 20px; align-items: center; flex-wrap: wrap;
    position: sticky; top: 0; z-index: 100; box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}
.toolbar .stat { font-size: 1em; color: #555; }
.toolbar .stat b { color: #1565c0; font-size: 1.3em; }
.toolbar button {
    padding: 10px 20px; border: none; border-radius: 6px; cursor: pointer;
    font-weight: 600; font-size: 0.95em;
}
.btn-export { background: #2e7d32; color: white; }
.btn-export:hover { background: #1b5e20; }
.btn-reset { background: #eee; color: #333; }
.grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 15px;
}
.capture {
    background: white; border-radius: 8px; overflow: hidden;
    box-shadow: 0 1px 4px rgba(0,0,0,0.1);
    transition: box-shadow 0.2s;
}
.capture:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.15); }
.capture.assigned { outline: 3px solid #2e7d32; }
.capture img { width: 100%; height: 160px; object-fit: cover; display: block; cursor: pointer; background: #eee; }
.capture .body { padding: 8px; }
.capture select {
    width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;
    font-size: 0.9em; background: white; cursor: pointer;
}
.capture select.assigned { background: #c8e6c9; font-weight: bold; }
.capture .nom {
    font-size: 0.65em; font-family: monospace; color: #888;
    margin-top: 5px; word-break: break-all;
}
.help {
    background: #e3f2fd; padding: 15px; border-radius: 8px; margin-bottom: 15px;
    border-left: 4px solid #1565c0; color: #0d47a1;
}
.help strong { color: #01579b; }
</style>
</head>
<body>
<h1>🎯 Association des captures aux catégories du rapport</h1>

<div class="help">
<strong>Mode d'emploi :</strong><br>
1. Pour chaque capture, choisissez dans le menu déroulant à quelle catégorie elle correspond.<br>
2. Cliquez sur <strong>💾 Exporter le mapping</strong> en haut.<br>
3. Un fichier <code>mapping.json</code> sera téléchargé — envoyez-le moi ou placez-le dans le dossier captures/10-travail/.
</div>

<div class="toolbar">
    <span class="stat">Total : <b id="total">0</b></span>
    <span class="stat">Assignées : <b id="assigned">0</b>/12</span>
    <button class="btn-export" onclick="exporter()">💾 Exporter le mapping</button>
    <button class="btn-reset" onclick="reset()">Réinitialiser</button>
</div>

<div class="grid" id="grid"></div>

<script>
const IMAGES = IMAGES_PLACEHOLDER;
const CIBLES = CIBLES_PLACEHOLDER;
const assignments = {};

function render() {
    document.getElementById('grid').innerHTML = IMAGES.map((img, i) => {
        const selected = assignments[img] || '';
        const cls = selected ? 'assigned' : '';
        const optionsHtml = CIBLES.map(([val, label]) => 
            `<option value="${val}" ${selected === val ? 'selected' : ''}>${label}</option>`
        ).join('');
        return `
        <div class="capture ${cls}">
            <img src="${img}" loading="lazy" title="${img}">
            <div class="body">
                <select class="${cls}" onchange="assigner('${img}', this.value)">
                    ${optionsHtml}
                </select>
                <div class="nom">${img}</div>
            </div>
        </div>
        `;
    }).join('');
    document.getElementById('total').textContent = IMAGES.length;
    document.getElementById('assigned').textContent = Object.values(assignments).filter(v => v).length;
}

function assigner(img, val) {
    if (val) assignments[img] = val;
    else delete assignments[img];
    render();
}

function reset() {
    if (!confirm('Réinitialiser toutes les associations ?')) return;
    for (const k in assignments) delete assignments[k];
    render();
}

function exporter() {
    const remplis = Object.entries(assignments).filter(([_, v]) => v);
    if (remplis.length === 0) {
        alert('Aucune capture associée.');
        return;
    }
    
    // Inverser le mapping : cible → fichier source
    const mapping = {};
    for (const [img, cible] of remplis) {
        if (mapping[cible]) {
            alert('⚠ Conflit : ' + cible + ' associée à 2 fichiers !');
            return;
        }
        mapping[cible] = img;
    }
    
    const json = JSON.stringify({
        date: new Date().toISOString(),
        mapping: mapping,
        total_associes: Object.keys(mapping).length
    }, null, 2);
    
    const blob = new Blob([json], { type: 'application/json' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'mapping.json';
    a.click();
}

render();
</script>
</body>
</html>
"""

# Construire les données JSON
imgs_json = "[\n  " + ",\n  ".join(f'"{img.name}"' for img in images) + "\n]"
cibles_json = "[\n  " + ",\n  ".join(f'["{v}", "{l}"]' for v, l in CIBLES) + "\n]"

html = html.replace("IMAGES_PLACEHOLDER", imgs_json)
html = html.replace("CIBLES_PLACEHOLDER", cibles_json)

DEST.write_text(html, encoding="utf-8")
print(f"✅ Galerie d'association créée : {DEST}")
