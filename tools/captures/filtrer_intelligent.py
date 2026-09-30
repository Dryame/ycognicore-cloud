#!/usr/bin/env python3
"""
filtrer_intelligent.py — Réduit 176 captures à ~15 candidates
en filtrant par plages horaires stratégiques.
"""
import re
import shutil
from pathlib import Path
from collections import defaultdict

RACINE = Path.home() / "projets" / "ycognicore-cloud"
SRC = RACINE / "docs/rapports/captures/10-travail"
DEST = RACINE / "docs/rapports/captures/10-selection"

DEST.mkdir(parents=True, exist_ok=True)

# Plages horaires importantes (heure, minute_debut, minute_fin, description)
PLAGES = [
    ("12", "55", "59", "Démarrage Docker"),
    ("13", "00", "05", "Docker setup"),
    ("13", "40", "55", "Test endpoint partitions"),
    ("14", "00", "05", "Tests fonctionnels"),
    ("14", "10", "15", "Postgres bases"),
    ("14", "30", "35", "Vault init"),
    ("14", "35", "40", "Vault keys"),
    ("14", "50", "55", "MinIO init"),
    ("15", "00", "05", "MinIO buckets"),
    ("15", "15", "20", "Git commits"),
]

# Analyser les fichiers
images_par_plage = defaultdict(list)

for img in sorted(SRC.glob("*.png")):
    # Extraire l'heure : "Capture_d'écran_2026-09-30_14h35m22s.png"
    match = re.search(r'(\d{2})h(\d{2})m', img.name)
    if not match:
        continue
    h, m = match.group(1), match.group(2)
    
    # Chercher dans les plages
    for ph, m_start, m_end, desc in PLAGES:
        if h == ph and m_start <= m <= m_end:
            images_par_plage[desc].append(img)
            break

# Copier les images importantes (limiter à 3 par plage)
total_copie = 0
mapping = {}

for desc, images in images_par_plage.items():
    print(f"\n▶ {desc} : {len(images)} captures trouvées")
    # Prendre les 3 premières (ou moins)
    for img in images[:3]:
        dest_file = DEST / img.name
        shutil.copy2(img, dest_file)
        print(f"    ✅ {img.name}")
        total_copie += 1
    if len(images) > 3:
        print(f"    (ignoré : {len(images) - 3} autres captures)")

print()
print(f"═══════════════════════════════════════════════════════")
print(f"  {total_copie} captures sélectionnées dans {DEST}")
print(f"═══════════════════════════════════════════════════════")
