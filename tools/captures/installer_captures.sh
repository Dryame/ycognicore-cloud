#!/usr/bin/env bash
# =====================================================================
# installer_captures.sh — Copie les 12 captures cibles dans captures/10/
# Usage : ./installer_captures.sh
# =====================================================================
set -euo pipefail

TRAVAIL="$HOME/projets/ycognicore-cloud/docs/rapports/captures/10-travail"
CIBLE="$HOME/projets/ycognicore-cloud/docs/rapports/captures/10"

mkdir -p "$CIBLE"

echo "═══════════════════════════════════════════════════════"
echo "  INSTALLATION DES 12 CAPTURES"
echo "═══════════════════════════════════════════════════════"
echo ""

# Mapping : nom cible → recherche dans la galerie
# Format : "nom_final|motif_recherche"
declare -a MAPPING=(
    "01-docker-services.png|docker.*ps|services|healthy"
    "02-minio-buckets.png|minio|bucket|ycc-documents"
    "03-vault-keys.png|vault|transit|ycc-mfa"
    "04-redis-minio-tests.png|redis|PONG|HTTP.*200"
    "05-postgres-bases.png|postgres|bases|ycc_control"
    "06-flyway-history.png|flyway|migration|V7"
    "07-endpoint-run.png|endpoint|run|partition"
    "08-endpoint-history.png|history|historique"
    "09-partitions-demo001.png|partition|demo001|audit_log"
    "10-13-migrations.png|13.*migration|verification"
    "11-git-log.png|git.*log|commit"
    "12-git-tags.png|git.*tag|v0.1.0|v0.2.0"
)

# Instructions manuelles
echo "Ce script ne peut PAS identifier automatiquement le contenu"
echo "des images. Pour chaque capture :"
echo ""
echo "1. Ouvrez la galerie : file://$TRAVAIL/galerie.html"
echo "2. Repérez visuellement la capture correspondant au contenu"
echo "3. Notez son nom exact"
echo "4. Copiez-la manuellement :"
echo ""
echo "   cp '$TRAVAIL/<nom_exact>.png' '$CIBLE/01-docker-services.png'"
echo ""

echo "Rappel du mapping :"
for entry in "${MAPPING[@]}"; do
    IFS='|' read -r nom motif <<< "$entry"
    echo "  $nom  ←  $motif"
done

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Une fois les 12 copies faites, vérifiez :"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  ls -lh $CIBLE/"
echo ""
