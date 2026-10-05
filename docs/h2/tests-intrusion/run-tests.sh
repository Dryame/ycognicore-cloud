#!/usr/bin/env bash
# =====================================================================
# Tests d'intrusion cross-tenant — 6 scénarios
# Projet : yCogniCore Cloud
# Sprint : H2 — BL-020
# Usage  : bash docs/h2/tests-intrusion/run-tests.sh
# =====================================================================
set +e
BASE="http://localhost:8080"
PASS=0
FAIL=0

check() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  [OK] $label"
        PASS=$((PASS+1))
    else
        echo "  [KO] $label (attendu: $expected, obtenu: $actual)"
        FAIL=$((FAIL+1))
    fi
}

echo "==============================================="
echo "  TESTS D'INTRUSION — 6 SCENARIOS"
echo "==============================================="

# ---------------------------------------------------------------------
# Préparation : login commercial DEMO001
# ---------------------------------------------------------------------
echo ""
echo "Préparation : login commercial@demo001.bf"
TOKEN=$(curl -s -X POST $BASE/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"commercial@demo001.bf","password":"Test@2026!","tenantCode":"DEMO001"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('accessToken',''))" 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo "[KO] Impossible d'obtenir un token — arrêt"
    exit 1
fi
echo "Token : ${TOKEN:0:30}..."

# =====================================================================
# Scénario 1 — Isolation BDD (JWT prioritaire sur header)
# =====================================================================
echo ""
echo "=== Scénario 1 : Isolation BDD ==="
echo "Test : envoyer X-Tenant-Code:DEMO002 avec un JWT DEMO001"
RESP=$(curl -s -H "Authorization: Bearer $TOKEN" \
             -H "X-Tenant-Code: DEMO002" \
             $BASE/api/_poc/whoami \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('pgDatabase',''))" 2>/dev/null)
check "JWT (DEMO001) prime sur header (DEMO002)" "ycc_tenant_demo001" "$RESP"

# =====================================================================
# Scénario 2 — JWT forgé (signature invalide)
# =====================================================================
echo ""
echo "=== Scénario 2 : JWT invalide ==="
echo "Test : token avec signature bidon"
HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer eyJhbGciOiJIUzUxMiJ9.token_bidon.signature_invalide" \
    $BASE/api/auth/me)
if [ "$HTTP" = "401" ] || [ "$HTTP" = "403" ]; then
    check "Signature invalide rejetee (HTTP $HTTP)" "yes" "yes"
else
    check "Signature invalide rejetee" "401/403" "$HTTP"
fi

# =====================================================================
# Scénario 3 — SQL Injection dans email
# =====================================================================
echo ""
echo "=== Scénario 3 : SQL Injection ==="
echo "Test : email avec tentative d'injection SQL"
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X POST $BASE/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.bf'"'"' OR '"'"'1'"'"'='"'"'1","password":"x","tenantCode":"DEMO001"}')
if [ "$HTTP" = "400" ] || [ "$HTTP" = "401" ] || [ "$HTTP" = "500" ]; then
    check "SQL Injection neutralisee (HTTP $HTTP)" "yes" "yes"
else
    check "SQL Injection neutralisee" "400/401/500" "$HTTP"
fi

# =====================================================================
# Scénario 4 — RBAC bypass
# =====================================================================
echo ""
echo "=== Scénario 4 : RBAC bypass ==="
echo "Test : commercial tente COMPTABILITE.VALIDER (non autorise)"
HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    $BASE/api/rbac-test/comptabilite/valider)
check "Acces refuse sans permission" "403" "$HTTP"

# =====================================================================
# Scénario 5 — RBAC autorise
# =====================================================================
echo ""
echo "=== Scénario 5 : RBAC autorise ==="
echo "Test : commercial VENTES.LIRE (autorise)"
HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    $BASE/api/rbac-test/ventes/lire)
check "Acces autorise avec permission" "200" "$HTTP"

# =====================================================================
# Scénario 6 — Escalade Superadmin (sans tenantCode)
# =====================================================================
echo ""
echo "=== Scénario 6 : Escalade Superadmin ==="
echo "Test : user tenant tente login sans tenantCode"
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X POST $BASE/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"commercial@demo001.bf","password":"Test@2026!"}')
if [ "$HTTP" = "401" ] || [ "$HTTP" = "500" ]; then
    check "Escalade Superadmin refusee (HTTP $HTTP)" "yes" "yes"
else
    check "Escalade Superadmin refusee" "401/500" "$HTTP"
fi

# =====================================================================
# Récapitulatif
# =====================================================================
echo ""
echo "==============================================="
echo "  RESULTAT : $PASS PASS / $FAIL FAIL"
echo "==============================================="
[ $FAIL -eq 0 ] && exit 0 || exit 1
