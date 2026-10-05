# Runbook — Rotation des clés Vault

**Projet** : yCogniCore Cloud
**Sprint** : H2 — BL-021
**Durée** : ~10 minutes

## Objectif
Faire tourner la clé `ycc-mfa-key` sans interrompre le service.

**Référence** : ADR-002, NFR-SEC-21.

## Étapes

### 1. État actuel

    docker exec -e VAULT_TOKEN=ycc-dev-token vault-ycc \
      vault read transit/keys/ycc-mfa-key

### 2. Rotation

    docker exec -e VAULT_TOKEN=ycc-dev-token vault-ycc \
      vault write -f transit/keys/ycc-mfa-key/rotate

### 3. Vérifier

    docker exec -e VAULT_TOKEN=ycc-dev-token vault-ycc \
      vault read transit/keys/ycc-mfa-key

Attendu : `latest_version` incrémenté.

## Cadence
- Dev : à chaque redéploiement
- Prod : tous les 90 jours (PCI-DSS)

**Fin du runbook**
