#!/usr/bin/env bash
# Telecharge la base DB-IP Lite City (CC BY 4.0).
# Usage : bash scripts/download-geoip.sh [mois]
# Sans argument : prend le mois courant.
set -euo pipefail

MONTH="${1:-$(date +%Y-%m)}"
URL="https://download.db-ip.com/free/dbip-city-lite-${MONTH}.mmdb.gz"
DEST="${YCC_GEOIP_DB_PATH:-./data/geoip/dbip-city-lite.mmdb}"
TMP_GZ="/tmp/dbip-city-lite-${MONTH}.mmdb.gz"

echo "=== DB-IP Lite — telechargement ${MONTH} ==="
echo "URL  : $URL"
echo "Cible: $DEST"
echo

mkdir -p "$(dirname "$DEST")"

if [ -f "$DEST" ]; then
  echo "Base deja presente. Remplacer ? (y/N)"
  read -r answer
  [ "$answer" != "y" ] && echo "Annule." && exit 0
fi

echo "Telechargement..."
curl -sSL -o "$TMP_GZ" "$URL"

echo "Decompression..."
gunzip -f "$TMP_GZ"
mv "/tmp/dbip-city-lite-${MONTH}.mmdb" "$DEST"

SIZE=$(du -h "$DEST" | cut -f1)
echo
echo "OK — base installee : $DEST ($SIZE)"
echo
echo "Ajouter au .gitignore : data/geoip/"
echo "Mise a jour mensuelle recommandee (CC BY 4.0)."
