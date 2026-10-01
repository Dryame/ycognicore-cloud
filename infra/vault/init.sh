#!/usr/bin/env bash
# =============================================================
# init.sh — Initialisation Vault (transit + cle ycc-mfa-key)
# Ref. : ADR-002, ADR-005, BL-012
# =============================================================
set -euo pipefail

CONTAINER="${VAULT_CONTAINER:-vault-ycc}"
VAULT_TOKEN="${VAULT_TOKEN:-ycc-dev-token}"

echo "================================"
echo "  INIT VAULT"
echo "================================"
echo ""

echo "[1/3] Activation du moteur transit..."
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" "$CONTAINER" \
  vault secrets enable -path=transit transit 2>&1 | tail -1 || true

echo ""
echo "[2/3] Creation de la cle ycc-mfa-key..."
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" "$CONTAINER" \
  vault write -f transit/keys/ycc-mfa-key 2>&1 | tail -3

echo ""
echo "[3/3] Verification des cles..."
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" "$CONTAINER" \
  vault list transit/keys

echo ""
echo "================================"
echo "  VAULT INITIALISE"
echo "================================"
