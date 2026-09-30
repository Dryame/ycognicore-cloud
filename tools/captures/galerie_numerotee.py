#!/usr/bin/env python3
"""
galerie_numerotee.py — Galerie avec numéros pour identification manuelle
"""
from pathlib import Path

RACINE = Path.home() / "projets" / "ycognicore-cloud"
SRC = RACINE / "docs/rapports/captures/10-travail"
DEST = SRC / "galerie_numerotee.html"

images = sorted(SRC.glob("*.png"))
print(f"→ {len(images)} images trouvées")

# Construire le HTML
html = """<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Galerie numérotée - Sélection captures</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: 'Segoe UI', sans-serif; background: #f5f5f5; padding: 20px; }
h1 { color: #1565c0; margin-bottom: 15px; padding-bottom: 10px; border-bottom: 3px solid #0277bd; }
.info { background: #fff3e0; padding: 15px; border-radius: 8px; margin-bottom: 15px; border-left: 4px solid #e65100; }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 12px; }
.capture { background: white; border-radius: 6px; overflow: hidden; box-shadow: 0 1px 4px rgba(0,0,0,0.1); position: relative; }
.capture .num {
    position: absolute; top: 8px; left: 8px;
    background: #e65100; color: white;
    width: 45px; height: 45px;
    border-radius: 50%; display: flex; align-items: center; justify-content: center;
    font-weight: bold; font-size: 1.3em; box-shadow: 0 2px 6px rgba(0,0,0,0.3);
    z-index: 10;
}
.capture img { width: 100%; height: 150px; object-fit: cover; background: #eee; display: block; }
.capture .info-nom { padding: 8px; font-size: 0.7em; font-family: monospace; color: #555; word-break: break-all; }
</style>
</head>
<body>
<h1>Galerie numérotée — Sélection des 12 captures</h1>
<div class="info">
<strong>Instructions :</strong><br>
1. Parcourez les images numérotées de 1 à 176<br>
2. Notez le numéro de chaque capture importante<br>
3. Communiquez la liste au format : <code>01-docker-services → 42</code>
</div>
<div class="grid">
"""

for i, img in enumerate(images, start=1):
    html += f"""
    <div class="capture">
        <div class="num">{i}</div>
        <img src="{img.name}" loading="lazy">
        <div class="info-nom">{img.name}</div>
    </div>
    """

html += """
</div>
</body>
</html>
"""

DEST.write_text(html, encoding="utf-8")
print(f"✅ Galerie numérotée : {DEST}")

# Aussi générer un fichier texte avec la liste numérotée
LISTE = SRC / "liste_numerotee.txt"
with open(LISTE, "w", encoding="utf-8") as f:
    for i, img in enumerate(images, start=1):
        f.write(f"{i:3d} | {img.name}\n")
print(f"✅ Liste texte : {LISTE}")
