#!/usr/bin/env python3
"""extraction_14.py — Extrait 1 capture par tranche de 30 min"""
import re
import shutil
import datetime
from pathlib import Path

RACINE = Path.home() / "projets" / "ycognicore-cloud"
SRC = RACINE / "docs/rapports/captures/10-travail"
DEST = RACINE / "docs/rapports/captures/10-candidates"

DEST.mkdir(parents=True, exist_ok=True)

def extraire_heure(img):
    m = re.search(r'(\d{2})h(\d{2})m(\d{2})s', img.name)
    if m:
        return int(m.group(1)), int(m.group(2))
    m = re.search(r'_(\d{2})(\d{2})(\d{2})\.png', img.name)
    if m:
        return int(m.group(1)), int(m.group(2))
    mtime = img.stat().st_mtime
    dt = datetime.datetime.fromtimestamp(mtime)
    return dt.hour, dt.minute

# Tranches de 30 minutes : on prend 1 capture par tranche
# Journée 9h30 → 15h30
tranches = []
for h in range(9, 16):
    for m in [0, 30]:
        if h == 9 and m == 0:
            continue  # Commence à 9h30
        if h == 15 and m == 30:
            break
        tranches.append((h, m))

# Grouper les captures par tranche
captures_par_tranche = {}
for img in sorted(SRC.glob("*.png")):
    h, mn = extraire_heure(img)
    # Trouver la tranche
    for th, tm in tranches:
        if (h == th and mn >= tm and (mn < tm + 30 or (tm == 30 and h == th))) or \
           (h == th + 1 and tm == 30 and mn < 30):
            key = (th, tm)
            if key not in captures_par_tranche:
                captures_par_tranche[key] = []
            captures_par_tranche[key].append(img)
            break

print("═══════════════════════════════════════════════════════")
print("  EXTRACTION DE 1 CAPTURE PAR TRANCHE DE 30 MIN")
print("═══════════════════════════════════════════════════════")
print("")

count = 0
for (h, m) in tranches:
    if (h, m) in captures_par_tranche and captures_par_tranche[(h, m)]:
        # Prendre la capture du milieu de la tranche
        liste = captures_par_tranche[(h, m)]
        img = liste[len(liste) // 2]
        nom_dest = f"candidat_{h:02d}h{m:02d}_{img.name}"
        dest = DEST / nom_dest
        shutil.copy2(img, dest)
        print(f"  ✅ {h:02d}h{m:02d} — {img.name[:60]}")
        count += 1
    else:
        print(f"  ⚠ {h:02d}h{m:02d} — aucune capture")

print("")
print("═══════════════════════════════════════════════════════")
print(f"  {count} captures extraites dans {DEST}")
print("═══════════════════════════════════════════════════════")
