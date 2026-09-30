#!/usr/bin/env bash
# =====================================================================
# init.sh — Initialisation de Vault (mode dev)
# Crée :
#   - Transit engine (chiffrement)
#   - Clé ycc-mfa-key (pour les secrets MFA)
# =====================================================================
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-ycc-dev-token}"

export VAULT_ADDR VAULT_TOKEN

echo "═══════════════════════════════════════════════════════"
echo "  INIT VAULT — $VAULT_ADDR"
echo "═══════════════════════════════════════════════════════"

# Attendre que Vault soit prêt
echo ""
echo "[1/4] Attente de Vault..."
for i in {1..30}; do
    if vault status >/dev/null 2>&1; then
        echo "  ✅ Vault prêt (après ${i}s)"
        break
    fi
    sleep 1
done

# Activer le moteur transit (chiffrement)
echo ""
echo "[2/4] Activation du moteur transit..."
vault secrets enable -path=transit transit 2>/dev/null || echo "  (déjà activé)"

# Créer la clé ycc-mfa-key
echo ""
echo "[3/4] Création de la clé ycc-mfa-key..."
vault write -f transit/keys/ycc-mfa-key 2>&1 | tail -5 || echo "  (déjà existante)"

# Vérification
echo ""
echo "[4/4] Vérification..."
vault list transit/keys

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ✅ VAULT INITIALISÉ"
echo "═══════════════════════════════════════════════════════"
echo "  Token : $VAULT_TOKEN"
echo "  Clé   : ycc-mfa-key"
echo ""
