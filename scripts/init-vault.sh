#!/usr/bin/env bash
# Init Vault Transit (idempotent). A executer apres chaque restart de vault-ycc.
# Ref. : P4 D-P4-6, D-P4-4.
set -euo pipefail

VAULT_TOKEN="${VAULT_TOKEN:-ycc-dev-token}"
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
export VAULT_TOKEN VAULT_ADDR

echo "=== Init Vault Transit ==="

# Attendre Vault
for i in $(seq 1 20); do
  if curl -s -o /dev/null -w "%{http_code}" "$VAULT_ADDR/v1/sys/health" | grep -q "200"; then
    echo "✓ Vault joignable"
    break
  fi
  sleep 1
done

# Monter transit si absent
if docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-ycc vault secrets list 2>/dev/null | grep -q "transit/"; then
  echo "✓ Transit deja monte"
else
  echo "→ Montage de transit..."
  docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-ycc vault secrets enable transit
  echo "✓ Transit monte"
fi

# Creer les cles si absentes
for KEY in ycc-mfa-key ycc-master-key; do
  if docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-ycc vault list transit/keys 2>/dev/null | grep -q "$KEY"; then
    echo "✓ Cle $KEY existante"
  else
    echo "→ Creation $KEY..."
    docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-ycc vault write -f "transit/keys/$KEY"
    echo "✓ Cle $KEY creee"
  fi
done

echo
echo "=== Vault Transit pret ==="
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-ycc vault list transit/keys
