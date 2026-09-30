#!/usr/bin/env python3
"""galerie_reduite.py — Galerie des ~15 captures candidates"""
from pathlib import Path

RACINE = Path.home() / "projets" / "ycognicore-cloud"
SRC = RACINE / "docs/rapports/captures/10-selection"
DEST = SRC / "galerie_reduite.html"

images = sorted(SRC.glob("*.png"))
print(f"→ {len(images)} images candidates")

CIBLES = [
    ("", "— Ignorer —"),
    ("01-docker-services.png", "01 — Services Docker (4 healthy)"),
    ("02-minio-buckets.png", "02 — MinIO buckets"),
    ("03-vault-keys.png", "03 — Vault keys (ycc-mfa-key)"),
    ("04-redis-minio-tests.png", "04 — Tests Redis+Vault+MinIO"),
    ("05-postgres-bases.png", "05 — Bases PostgreSQL préservées"),
    ("06-flyway-history.png", "06 — Flyway history (V1-V7)"),
    ("07-endpoint-run.png", "07 — Endpoint run (12 partitions)"),
    ("08-endpoint-history.png", "08 — Endpoint history"),
    ("09-partitions-demo001.png", "09 — Partitions demo001"),
    ("10-13-migrations.png", "10 — 13 migrations"),
    ("11-git-log.png", "11 — Git log"),
    ("12-git-tags.png", "12 — Git tags"),
]

options = "".join(f'<option value="{v}">{l}</option>' for v, l in CIBLES)

html = f"""<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Sélection — {len(images)} candidates</title>
<style>
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
body {{ font-family: 'Segoe UI', sans-serif; background: #f5f5f5; padding: 20px; }}
h1 {{ color: #1565c0; margin-bottom: 15px; }}
.toolbar {{ background: white; padding: 15px; border-radius: 8px; margin-bottom: 15px; display: flex; gap: 20px; align-items: center; position: sticky; top: 0; z-index: 100; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }}
.toolbar b {{ color: #1565c0; font-size: 1.3em; }}
.toolbar button {{ padding: 10px 20px; border: none; border-radius: 6px; cursor: pointer; font-weight: 600; }}
.btn-export {{ background: #2e7d32; color: white; }}
.grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 15px; }}
.capture {{ background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 4px rgba(0,0,0,0.1); }}
.capture.assigned {{ outline: 3px solid #2e7d32; }}
.capture img {{ width: 100%; height: 180px; object-fit: cover; display: block; cursor: zoom-in; background: #eee; }}
.capture .body {{ padding: 10px; }}
.capture select {{ width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px; font-size: 0.9em; }}
.capture select.assigned {{ background: #c8e6c9; font-weight: bold; }}
.capture .nom {{ font-size: 0.7em; font-family: monospace; color: #888; margin-top: 5px; word-break: break-all; }}
</style>
</head>
<body>
<h1>🎯 Sélection des {len(images)} captures candidates</h1>
<div class="toolbar">
    <span>Assignées : <b id="count">0</b>/12</span>
    <button class="btn-export" onclick="exporter()">💾 Exporter le mapping</button>
    <button onclick="reset()">Réinitialiser</button>
</div>
<div class="grid" id="grid"></div>
<script>
const IMAGES = {repr([img.name for img in images])};
const CIBLES = {repr(CIBLES)};
const assignments = {{}};

function render() {{
    document.getElementById('grid').innerHTML = IMAGES.map(img => {{
        const sel = assignments[img] || '';
        const opts = CIBLES.map(([v, l]) => `<option value="${{v}}" ${{sel === v ? 'selected' : ''}}>${{l}}</option>`).join('');
        return `<div class="capture ${{sel ? 'assigned' : ''}}">
            <img src="${{img}}" loading="lazy" onclick="window.open(this.src)">
            <div class="body">
                <select class="${{sel ? 'assigned' : ''}}" onchange="assigner('${{img}}', this.value)">${{opts}}</select>
                <div class="nom">${{img}}</div>
            </div>
        </div>`;
    }}).join('');
    document.getElementById('count').textContent = Object.values(assignments).filter(v => v).length;
}}

function assigner(img, val) {{
    if (val) assignments[img] = val; else delete assignments[img];
    render();
}}

function reset() {{
    if (!confirm('Réinitialiser ?')) return;
    for (const k in assignments) delete assignments[k];
    render();
}}

function exporter() {{
    const remplis = Object.entries(assignments).filter(([_, v]) => v);
    if (remplis.length === 0) {{ alert('Aucune assignation'); return; }}
    const mapping = {{}};
    for (const [img, cible] of remplis) {{
        if (mapping[cible]) {{ alert('Conflit : ' + cible); return; }}
        mapping[cible] = img;
    }}
    const json = JSON.stringify({{mapping: mapping}}, null, 2);
    const blob = new Blob([json], {{type: 'application/json'}});
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'mapping.json';
    a.click();
}}

render();
</script>
</body>
</html>"""

DEST.write_text(html, encoding="utf-8")
print(f"✅ Galerie : {DEST}")
