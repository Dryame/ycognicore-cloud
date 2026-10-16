#!/usr/bin/env bash
# Demonstration L3 pour encadreur — 5 scenarios en 5 minutes.
# Ref : plan Phase 3 v1.4, sortie L3.

set -euo pipefail

API="${API:-http://localhost:8080}"
TENANT="DEMO001"
EMAIL="${EMAIL:-admin@demo001.bf}"
PASSWORD="${PASSWORD:-AdminDemo2026!}"
COOKIE_JAR="$(mktemp)"
LOGIN_JSON="$(mktemp)"

color() { printf '\033[1;36m%s\033[0m\n' "$*"; }
ok()    { printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
ko()    { printf '  \033[1;31m✗\033[0m %s\n' "$*"; }

cleanup() { rm -f "$COOKIE_JAR" "$LOGIN_JSON"; }
trap cleanup EXIT

echo
color "=== DEMONSTRATION L3 — yCogniCore Cloud ==="
echo "API     : $API"
echo "Tenant  : $TENANT"
echo "Date    : $(date -u '+%Y-%m-%d %H:%M UTC')"
echo

# ---------------------------------------------------------------
color "1. Verification des conteneurs Docker"
docker ps --filter "name=ycc" --format "  {{.Names}}\t{{.Status}}"
echo

# ---------------------------------------------------------------
color "2. Connexion SANS MFA (compte sans MFA)"
curl -sS -c "$COOKIE_JAR" -X POST "$API/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"tenantCode\":\"$TENANT\"}" \
  -o "$LOGIN_JSON"

if jq -e '.accessToken' "$LOGIN_JSON" >/dev/null 2>&1; then
  ok "Tokens emis (access + refresh cookie)"
  ACCESS="$(jq -r '.accessToken' "$LOGIN_JSON")"
elif jq -e '.mfaRequired == true' "$LOGIN_JSON" >/dev/null 2>&1; then
  ok "MFA requis — challenge emis"
  ACCESS=""
else
  ko "Reponse inattendue : $(cat "$LOGIN_JSON")"
  exit 1
fi
echo

# ---------------------------------------------------------------
color "3. Requete authentifiee avec session valide"
if [[ -n "$ACCESS" ]]; then
  HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer $ACCESS" \
    "$API/api/auth/me")"
  [[ "$HTTP_CODE" == "200" ]] && ok "GET /api/auth/me → 200" \
                             || ko "GET /api/auth/me → $HTTP_CODE"
else
  ok "Scenario 3 ignore (MFA requis, voir scenario 4)"
fi
echo

# ---------------------------------------------------------------
color "4. Verification MFA (si challenge emis)"
if jq -e '.challengeToken' "$LOGIN_JSON" >/dev/null 2>&1; then
  CHALLENGE="$(jq -r '.challengeToken' "$LOGIN_JSON")"
  echo "  Challenge token : ${CHALLENGE:0:16}…"
  read -rp "  Entrez le code TOTP a 6 chiffres : " CODE
  MFA_JSON="$(mktemp)"
  curl -sS -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST "$API/api/mfa/challenge-verify" \
    -H 'Content-Type: application/json' \
    -d "{\"challengeToken\":\"$CHALLENGE\",\"code\":\"$CODE\"}" \
    -o "$MFA_JSON"
  if jq -e '.accessToken' "$MFA_JSON" >/dev/null 2>&1; then
    ok "Code MFA valide — tokens emis"
    ACCESS="$(jq -r '.accessToken' "$MFA_JSON")"
  else
    ko "Code MFA refuse : $(cat "$MFA_JSON")"
  fi
  rm -f "$MFA_JSON"
else
  ok "Scenario 4 ignore (pas de MFA sur ce compte)"
fi
echo

# ---------------------------------------------------------------
color "5. Rate limiting (11 requetes rapides sur /api/auth/login)"
CODES=""
for i in $(seq 1 11); do
  C="$(curl -sS -o /dev/null -w '%{http_code}' -X POST "$API/api/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"inexistant-$i@x.y\",\"password\":\"x\",\"tenantCode\":\"$TENANT\"}")"
  CODES="$CODES $C"
done
echo "  Codes :$CODES"
echo "$CODES" | grep -q '429' && ok "429 present — RateLimitFilter actif" \
                            || ko "Aucun 429 detecte — verifier seuils"
echo

# ---------------------------------------------------------------
echo
color "   Attente 65s pour reinitialiser le quota rate limit..."
sleep 65
echo

color "6. Rotation du refresh token (D-13 : usage unique)"

# Re-login pour obtenir un refresh tout neuf
LOGIN2_JSON="$(mktemp)"
curl -sS -c "$COOKIE_JAR" -X POST "$API/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"tenantCode\":\"$TENANT\"}" \
  -o "$LOGIN2_JSON"

REFRESH_OLD="$(jq -r '.refreshToken // empty' "$LOGIN2_JSON")"
if [[ -z "$REFRESH_OLD" ]]; then
  ko "Pas de refresh token dans la reponse login"
else
  # 1er usage : doit reussir (200)
  R1_JSON="$(mktemp)"
  R1_CODE="$(curl -sS -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST "$API/api/auth/refresh" \
    -H 'Content-Type: application/json' \
    -H "X-Tenant-Code: $TENANT" \
    -H "X-Tenant-Code: $TENANT" \
    -d "{\"refreshToken\":\"$REFRESH_OLD\"}" \
    -o "$R1_JSON" -w '%{http_code}')"
  REFRESH_NEW="$(jq -r '.refreshToken // empty' "$R1_JSON" 2>/dev/null)"

  # 2e usage avec l'ANCIEN token : rejeu -> doit refuser
  R2_CODE="$(curl -sS -b "$COOKIE_JAR" -X POST "$API/api/auth/refresh" \
    -H 'Content-Type: application/json' \
    -H "X-Tenant-Code: $TENANT" \
    -H "X-Tenant-Code: $TENANT" \
    -d "{\"refreshToken\":\"$REFRESH_OLD\"}" \
    -o /dev/null -w '%{http_code}')"

  echo "  1er refresh (valide) : $R1_CODE   rotation OK : $([[ -n "$REFRESH_NEW" ]] && echo oui || echo non)"
  echo "  2e refresh (rejeu)   : $R2_CODE"

  if [[ "$R1_CODE" == "200" && "$R2_CODE" == "401" ]]; then
    ok "Rotation + rejeu refuse — D-13 effectif"
  elif [[ "$R1_CODE" != "200" ]]; then
    ko "1er refresh refuse ($R1_CODE) — verifier RefreshService"
  elif [[ "$R2_CODE" != "401" ]]; then
    ko "Rejeu accepte ($R2_CODE) — rotation non effective"
  fi

  rm -f "$R1_JSON"
fi
rm -f "$LOGIN2_JSON"
echo

color "=== FIN DE DEMONSTRATION ==="
echo
echo "Points a souligner devant l'encadreur :"
echo "  - MFA obligatoire (F1)  : scenario 2 et 4"
echo "  - Rejeu refuse (F2)     : scenario 6"
echo "  - Revocation (F3)       : via change-password (hors script)"
echo "  - Rate limiting (F7)    : scenario 5"
echo "  - Audit chaine (D-03)   : voir table audit_log apres login"
echo
