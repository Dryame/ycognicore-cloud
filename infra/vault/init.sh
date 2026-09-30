#!/usr/bin/env bash
# =====================================================================
# init.sh — Initialisation Vault via docker exec
# Active le moteur transit et crée la clé ycc-mfa-key
# Note : le CLI vault est dans le conteneur, pas sur l'hôte
# =====================================================================
set -euo pipefail

CONTAINER="${VAULT_CONTAINER:-vault-ycc}"
VAULT_TOKEN="${VAULT_TOKEN:-ycc-dev-token}"

echo "═══════════════════════════════════════════════════════"
echo "  INIT VAULT"
echo "═══════════════════════════════════════════════════════"

echo ""
echo "[1/3] Activation du moteur transit..."
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" "$CONTAINER" \
    vault secrets enable -path=transit transit 2>&1 | tail -1

echo ""
echo "[2/3] Création de la clé ycc-mfa-key..."
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" "$CONTAINER" \
    vault write -f transit/keys/ycc-mfa-key 2>&1 | tail -1

echo ""
echo "[3/3] Vérification des clés..."
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" "$CONTAINER" \
    vault list transit/keys

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  VAULT INITIALISE"
echo "═══════════════════════════════════════════════════════"
