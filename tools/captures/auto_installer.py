#!/usr/bin/env python3
"""
auto_installer.py — Sélection + installation automatique des 12 captures
selon les plages horaires stratégiques de la journée.
"""
import re
import shutil
from pathlib import Path
from collections import defaultdict

RACINE = Path.home() / "projets" / "ycognicore-cloud"
SRC = RACINE / "docs/rapports/captures/10-travail"
CIBLE = RACINE / "docs/rapports/captures/10"

CIBLE.mkdir(parents=True, exist_ok=True)

# Mapping : catégorie cible → plages horaires prioritaires (du plus prioritaire au moins)
# Format : "nom_final.png" : [(heure, minute_min, minute_max, priorité)]
MAPPING = {
    "01-docker-services.png": [
        ("12", 50, 59, "Démarrage Docker"),
        ("13", 0, 5, "Setup Docker"),
    ],
    "02-minio-buckets.png": [
        ("14", 50, 58, "Init MinIO"),
        ("15", 0, 5, "Buckets MinIO"),
    ],
    "03-vault-keys.png": [
        ("14", 30, 40, "Vault init"),
        ("14", 35, 45, "Vault keys"),
    ],
    "04-redis-minio-tests.png": [
        ("14", 0, 8, "Tests services"),
        ("14", 25, 30, "Vérif services"),
    ],
    "05-postgres-bases.png": [
        ("14", 10, 15, "Postgres bases"),
        ("14", 25, 32, "Préservation PG"),
    ],
    "06-flyway-history.png": [
        ("13", 0, 10, "Flyway test"),
        ("14", 40, 50, "Migration V7"),
    ],
    "07-endpoint-run.png": [
        ("13", 40, 55, "Test endpoint"),
        ("13", 50, 59, "Endpoint 12 part"),
    ],
    "08-endpoint-history.png": [
        ("13", 50, 59, "Endpoint history"),
        ("14", 45, 55, "Historique"),
    ],
    "09-partitions-demo001.png": [
        ("13", 55, 59, "Partitions créées"),
        ("14", 0, 5, "Vérif partitions"),
    ],
    "10-13-migrations.png": [
        ("9", 45, 55, "Vérif 13 migrations"),
        ("9", 50, 59, "13 migrations"),
        ("10", 0, 30, "Vérifications"),
    ],
    "11-git-log.png": [
        ("15", 10, 20, "Git commits"),
        ("15", 15, 25, "Git log"),
        ("15", 25, 35, "Commit final"),
    ],
    "12-git-tags.png": [
        ("15", 15, 25, "Git tags"),
        ("14", 50, 55, "Tag H0"),
        ("15", 25, 35, "Tag final"),
    ],
}

# Analyser toutes les captures
print("═══════════════════════════════════════════════════════")
print("  INSTALLATION AUTOMATIQUE DES 12 CAPTURES")
print("═══════════════════════════════════════════════════════")
print("")

toutes_captures = []
for img in sorted(SRC.glob("*.png")):
    match = re.search(r'(\d{2})h(\d{2})m(\d{2})s', img.name)
    if not match:
        # Nom UUID — date de modification
        mtime = img.stat().st_mtime
        import datetime
        dt = datetime.datetime.fromtimestamp(mtime)
        h, m, s = dt.strftime("%H"), dt.strftime("%M"), dt.strftime("%S")
    else:
        h, m, s = match.group(1), match.group(2), match.group(3)
    toutes_captures.append((h, m, s, img))

print(f"→ {len(toutes_captures)} captures analysées")
print("")

# Sélection
installees = 0
non_trouvees = []

for cible, plages in MAPPING.items():
    trouve = False
    for heure, m_min, m_max, desc in plages:
        for h, m, s, img in toutes_captures:
            if h == heure and m_min <= int(m) <= m_max:
                dest = CIBLE / cible
                shutil.copy2(img, dest)
                print(f"  ✅ {cible}")
                print(f"     ← {img.name}  [{desc}]")
                installees += 1
                trouve = True
                break
        if trouve:
            break
    if not trouve:
        print(f"  ⚠ {cible} — aucune capture dans les plages")
        non_trouvees.append(cible)

print("")
print("═══════════════════════════════════════════════════════")
print(f"  {installees}/12 captures installées")
print(f"═══════════════════════════════════════════════════════")

if non_trouvees:
    print("")
    print("  Captures non trouvées :")
    for n in non_trouvees:
        print(f"    - {n}")
    print("")
    print("  → Solution : ajuster les plages horaires dans le script")
