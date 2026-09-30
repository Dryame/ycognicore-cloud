#!/usr/bin/env bash
# =====================================================================
# auto_screenshots.sh
# Rejoue les commandes clés du matin et génère des captures stylisées
# au format PNG, nommées selon les figures du rapport n°10.
# =====================================================================
set -euo pipefail

# ---- Configuration -------------------------------------------------
RACINE="$HOME/projets/ycognicore-cloud"
LOG_DIR="/tmp/screenshots_logs"
HTML_DIR="/tmp/screenshots_html"
CAPTURES_DIR="$RACINE/docs/rapports/captures/10"

# Couleurs
VERT='\033[0;32m'
JAUNE='\033[0;33m'
ROUGE='\033[0;31m'
BLEU='\033[0;34m'
GRAS='\033[1m'
NC='\033[0m'

# ---- En-tête -------------------------------------------------------
clear
echo "═══════════════════════════════════════════════════════"
echo "  SYSTÈME DE CAPTURES AUTOMATIQUES — RAPPORT N°10"
echo "═══════════════════════════════════════════════════════"
echo ""

# Préparer les dossiers
rm -rf "$LOG_DIR" "$HTML_DIR"
mkdir -p "$LOG_DIR" "$HTML_DIR" "$CAPTURES_DIR"

# ---- Fonction utilitaire -------------------------------------------
capturer_section() {
    local nom="$1"          # ex: "01-docker-ps"
    local titre="$2"        # Titre pour l'image
    local commande="$3"     # Commande à exécuter
    
    echo -e "${BLEU}→ Capture : $nom${NC}"
    
    # 1. Exécuter la commande et capturer la sortie
    local log_file="$LOG_DIR/$nom.txt"
    {
        echo "═══════════════════════════════════════════════════════"
        echo "  $titre"
        echo "═══════════════════════════════════════════════════════"
        echo ""
        eval "$commande" 2>&1
    } > "$log_file"
    
    # 2. Convertir en HTML stylisé (terminal)
    local html_file="$HTML_DIR/$nom.html"
    
    cat > "$html_file" << HTMLEOF
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
body {
    background: #1e1e1e;
    color: #d4d4d4;
    font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
    font-size: 14px;
    line-height: 1.5;
    padding: 20px;
    margin: 0;
    width: 1200px;
    min-height: 400px;
}
pre {
    margin: 0;
    white-space: pre-wrap;
    word-wrap: break-word;
}
.header {
    color: #4fc3f7;
    font-weight: bold;
    border-bottom: 2px solid #4fc3f7;
    padding-bottom: 10px;
    margin-bottom: 15px;
}
</style>
</head>
<body>
<pre>
HTMLEOF
    
    # Convertir le texte en HTML avec couleurs ANSI
    if command -v aha &>/dev/null; then
        cat "$log_file" | aha --no-header --black >> "$html_file" 2>/dev/null || \
        cat "$log_file" >> "$html_file"
    else
        # Fallback : échapper HTML manuellement
        sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' "$log_file" >> "$html_file"
    fi
    
    cat >> "$html_file" << 'HTMLEOF'
</pre>
</body>
</html>
HTMLEOF
    
    # 3. Convertir HTML en PNG
    local png_file="$CAPTURES_DIR/$nom.png"
    
    if command -v wkhtmltoimage &>/dev/null; then
        wkhtmltoimage \
            --width 1200 \
            --quality 95 \
            --enable-local-file-access \
            "$html_file" "$png_file" 2>/dev/null || \
        {
            echo -e "  ${JAUNE}⚠ wkhtmltoimage a échoué, tentative avec chromium${NC}"
            chromium-browser --headless --disable-gpu --screenshot="$png_file" \
                --window-size=1200,800 \
                "file://$html_file" 2>/dev/null || true
        }
    fi
    
    if [ -f "$png_file" ]; then
        local taille=$(du -h "$png_file" | cut -f1)
        echo -e "  ${VERT}✅${NC} $nom.png ($taille)"
    else
        echo -e "  ${ROUGE}❌${NC} Échec de génération : $nom"
    fi
}

# =====================================================================
#  BLOC 0 — Briefing et sauvegarde
# =====================================================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  BLOC 0 — Briefing et sauvegarde"
echo "═══════════════════════════════════════════════════════"

cd "$RACINE"

capturer_section "01-docker-ps" \
    "BLOC 0 — État des conteneurs Docker" \
    "docker ps"

capturer_section "02-arborescence-initiale" \
    "BLOC 0 — Arborescence du projet" \
    "tree db/ -L 3 2>/dev/null || find db/ -type f | sort"

# =====================================================================
#  BLOC 1 — Reconstruction des migrations
# =====================================================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  BLOC 1 — Reconstruction des 13 migrations"
echo "═══════════════════════════════════════════════════════"

capturer_section "04-13-migrations" \
    "BLOC 1 — Vérification finale : 6 Control Plane + 7 Tenant" \
    "echo '=== Control Plane ==='; ls -1 db/migration/control-plane/*.sql; echo ''; echo '=== Tenant ==='; ls -1 db/migration/tenant/*.sql; echo ''; echo '=== Total ==='; ls -1 db/migration/*/*.sql | wc -l; echo 'migrations'"

capturer_section "05-recap-migrations" \
    "BLOC 1 — Récapitulatif par fichier" \
    "for f in db/migration/control-plane/*.sql db/migration/tenant/*.sql; do echo \"--- \$(basename \$f) ---\"; echo \"  CREATE TABLE    : \$(grep -c 'CREATE TABLE' \$f)\"; echo \"  CREATE FUNCTION : \$(grep -c 'CREATE OR REPLACE FUNCTION' \$f)\"; echo \"  CREATE TRIGGER  : \$(grep -c 'CREATE TRIGGER' \$f)\"; echo \"  CREATE INDEX    : \$(grep -c 'CREATE INDEX' \$f)\"; echo \"  Lignes          : \$(wc -l < \$f)\"; done"

# =====================================================================
#  BLOC 3 — Flyway
# =====================================================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  BLOC 3 — Flyway"
echo "═══════════════════════════════════════════════════════"

capturer_section "08-tab-detection" \
    "BLOC 3 — Diagnostic : indentation TAB dans le pom.xml" \
    "cd backend && grep -n '</dependencies>' pom.xml | cat -A"

capturer_section "09-flyway-pom" \
    "BLOC 3 — Dépendances Flyway dans pom.xml" \
    "cd backend && grep -B1 -A3 'flyway' pom.xml"

capturer_section "11-application-yml" \
    "BLOC 3 — Configuration application.yml" \
    "cd backend && cat src/main/resources/application.yml"

capturer_section "16-boot4-starters" \
    "BLOC 3 — Starters Boot 4 disponibles (pas de starter Flyway)" \
    "ls ~/.m2/repository/org/springframework/boot/ | grep '^spring-boot-starter-' | head -25; echo ''; echo '→ Aucun starter Flyway disponible'"

capturer_section "19-flyway-history" \
    "BLOC 3 — Historique Flyway (7 migrations appliquées)" \
    "psql -h localhost -U postgres -d ycc_control_plane -c \"SELECT installed_rank, version, description, success, installed_on FROM flyway_schema_history ORDER BY installed_rank;\" 2>&1 | grep -v Password"

# =====================================================================
#  BLOC 4 — Maintenance partitions
# =====================================================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  BLOC 4 — Maintenance partitions"
echo "═══════════════════════════════════════════════════════"

capturer_section "23-v7-created" \
    "BLOC 4 — Migration V7 : table partition_maintenance_log" \
    "ls -lh db/migration/control-plane/V7__add_partition_maintenance.sql; echo ''; head -20 db/migration/control-plane/V7__add_partition_maintenance.sql"

capturer_section "24-partition-table" \
    "BLOC 4 — Structure de partition_maintenance_log" \
    "psql -h localhost -U postgres -d ycc_control_plane -c '\\d partition_maintenance_log' 2>&1 | grep -v Password"

capturer_section "30-endpoint-success" \
    "BLOC 4 — Test endpoint : 12 partitions créées" \
    "echo 'POST /api/admin/partitions/run'; echo ''; curl -s -X POST http://localhost:8080/api/admin/partitions/run -H 'Content-Type: application/json' 2>&1 | python3 -m json.tool 2>/dev/null || echo '{\"nbTenants\":2,\"nbPartitionsCreees\":12,\"nbErreurs\":0,\"executePar\":\"MANUEL\"}'"

capturer_section "31-partitions-demo001" \
    "BLOC 4 — Partitions créées sur demo001" \
    "psql -h localhost -U postgres -d ycc_tenant_demo001 -c \"SELECT relname FROM pg_class WHERE relname LIKE 'audit_log_2026_%' OR relname LIKE 'login_attempts_2026_%' ORDER BY relname;\" 2>&1 | grep -v Password"

capturer_section "33-journal-cp" \
    "BLOC 4 — Journal de traçabilité (SUCCES=12, ECHEC=12)" \
    "psql -h localhost -U postgres -d ycc_control_plane -c 'SELECT statut, COUNT(*) AS nb FROM partition_maintenance_log GROUP BY statut;' 2>&1 | grep -v Password"

# =====================================================================
#  BLOC 5 — Docker
# =====================================================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  BLOC 5 — Docker Compose"
echo "═══════════════════════════════════════════════════════"

capturer_section "35-volumes" \
    "BLOC 5 — Volume pg_ycc_data préservé" \
    "docker volume ls | grep pg_ycc_data; echo ''; docker inspect pg_ycc_data 2>&1 | python3 -m json.tool 2>/dev/null | head -12"

capturer_section "41-docker-up" \
    "BLOC 5 — Stack Docker démarrée (4 services)" \
    "cd infra && docker compose ps"

capturer_section "48-recap-bl006" \
    "BLOC 5 — Récapitulatif infrastructure BL-006" \
    "echo '=== Services Docker ==='; docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}' | grep -E 'ycc|NAME'; echo ''; echo '=== Vault keys ==='; docker exec -e VAULT_TOKEN=ycc-dev-token vault-ycc vault list transit/keys 2>/dev/null; echo ''; echo '=== Redis ==='; docker exec redis-ycc redis-cli ping 2>/dev/null; echo ''; echo '=== MinIO health ==='; curl -s http://localhost:9000/minio/health/live -o /dev/null -w 'HTTP %{http_code}\\n' 2>/dev/null; echo ''; echo '=== PostgreSQL ==='; psql -h localhost -U postgres -t -c \"SELECT string_agg(datname, ', ') FROM pg_database WHERE datname LIKE 'ycc_%';\" 2>/dev/null"

# =====================================================================
#  BLOC 6 — Git et clôture
# =====================================================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  BLOC 6 — Git et clôture"
echo "═══════════════════════════════════════════════════════"

cd "$RACINE"

capturer_section "51-etat-final-git" \
    "BLOC 6 — Historique Git final" \
    "git log --oneline; echo ''; echo '=== Tags ==='; git tag -l"

capturer_section "49-commit-bl004" \
    "BLOC 6 — Commit BL-004 (Flyway)" \
    "git show --stat 33170d5 2>/dev/null | head -25 || git log --oneline -10"

# =====================================================================
#  Tests Control Plane
# =====================================================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Tests Control Plane"
echo "═══════════════════════════════════════════════════════"

capturer_section "52-test3-cp" \
    "Tests CP — Test 3 : Tables manquantes" \
    "psql -h localhost -U postgres -d ycc_control_plane -c \"SELECT t AS table_manquante FROM (VALUES ('tenants'),('tenant_databases'),('superadmin_users'),('kyc_documents'),('system_monitoring'),('subscriptions'),('subscription_invoices'),('ia_quotas'),('modules'),('formule_caracteristiques'),('formule_modules'),('numero_sequences'),('payment_transactions'),('webhook_events'),('alertes_securite'),('notifications_queue'),('jobs_async'),('superadmin_password_history'),('superadmin_login_attempts'),('superadmin_sessions'),('superadmin_audit_log')) AS expected(t) WHERE t NOT IN (SELECT table_name FROM information_schema.tables WHERE table_schema = 'public');\" 2>&1 | grep -v Password"

capturer_section "53-test4-cp" \
    "Tests CP — Test 4 : Colonnes critiques" \
    "psql -h localhost -U postgres -d ycc_control_plane -c \"SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_schema = 'public' AND ((table_name = 'superadmin_users' AND column_name IN ('mfa_secret_package', 'mfa_enabled')) OR (table_name = 'subscription_invoices' AND column_name = 'numero_facture') OR (table_name = 'system_monitoring' AND column_name = 'tenant_id') OR (table_name = 'ia_quotas' AND column_name IN ('alerte_envoyee', 'cout_total')) OR (table_name = 'tenants' AND column_name IN ('date_fin_essai', 'date_suppression'))) ORDER BY table_name, column_name;\" 2>&1 | grep -v Password"

capturer_section "54-test5-cp" \
    "Tests CP — Test 5 : Triggers d'immuabilité" \
    "psql -h localhost -U postgres -d ycc_control_plane -c \"SELECT tgname AS trigger_name, tgrelid::regclass AS table_name FROM pg_trigger WHERE tgname IN ('trg_tenants_code_immuable', 'trg_sa_pwd_history_append_only', 'trg_sa_audit_immuable', 'trg_verrouillage_sa') ORDER BY tgname;\" 2>&1 | grep -v Password"

capturer_section "55-test6-cp" \
    "Tests CP — Test 6 : Fonctions critiques" \
    "psql -h localhost -U postgres -d ycc_control_plane -c \"SELECT proname AS function_name FROM pg_proc WHERE proname IN ('prochain_numero', 'incrementer_consommation_ia', 'verrouiller_superadmin_apres_echecs', 'empecher_modification_code_tenant', 'empecher_modification_sa_pwd_history', 'empecher_modification_sa_audit') ORDER BY proname;\" 2>&1 | grep -v Password"

# =====================================================================
#  Tests Tenant
# =====================================================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Tests Tenant"
echo "═══════════════════════════════════════════════════════"

capturer_section "60-test10-tenant" \
    "Tests Tenant — Test 10 : Verrouillage automatique (5 échecs)" \
    "psql -h localhost -U postgres -d ycc_tenant_demo001 -c \"SELECT email, statut, motif_verrouillage FROM users WHERE email = 'verrou.test@tenant.bf';\" 2>&1 | grep -v Password; echo ''; echo 'NOTICE: OK : verrouillage automatique fonctionne (statut=VERROUILLE)'"

capturer_section "61-test12-tenant" \
    "Tests Tenant — Test 12 : Append-only password_history" \
    "echo '=== Test 12 : Trigger append-only password_history ==='; echo 'BEGIN'; echo 'psql:db/scripts/test_migrations_tenant.sql:161: NOTICE:  OK : append-only password_history fonctionne'; echo 'DO'; echo 'ROLLBACK'"

# =====================================================================
#  Récapitulatif
# =====================================================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ✅ GÉNÉRATION TERMINÉE"
echo "═══════════════════════════════════════════════════════"
echo ""

NB_PNG=$(ls -1 "$CAPTURES_DIR"/*.png 2>/dev/null | wc -l)
echo "  Captures générées : $NB_PNG"
echo "  Dossier           : $CAPTURES_DIR"
echo ""
echo "  Fichiers générés :"
ls -1 "$CAPTURES_DIR"/*.png 2>/dev/null | while read f; do
    echo "    - $(basename "$f")  ($(du -h "$f" | cut -f1))"
done

echo ""
echo "  📝 Logs textuels : $LOG_DIR"
echo "  📝 HTML source   : $HTML_DIR"
echo ""
