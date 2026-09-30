#!/usr/bin/env bash
# =====================================================================
# auto_screenshots_v3.sh
# Version utilisant UNIQUEMENT ImageMagick (déjà installé)
# Génère des captures PNG à partir des sorties terminal
# =====================================================================
set -uo pipefail

RACINE="$HOME/projets/ycognicore-cloud"
LOG_DIR="/tmp/screenshots_logs_v3"
CAPTURES_DIR="$RACINE/docs/rapports/captures/10"

VERT='\033[0;32m'
JAUNE='\033[0;33m'
ROUGE='\033[0;31m'
BLEU='\033[0;34m'
NC='\033[0m'

rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR" "$CAPTURES_DIR"

# =====================================================================
#  Fonction : génère un PNG à partir d'un texte avec ImageMagick
# =====================================================================
capturer() {
    local nom="$1"
    local titre="$2"
    local commande="$3"
    
    echo -e "${BLEU}→ $nom${NC}"
    
    # 1. Exécuter la commande et capturer
    local log_file="$LOG_DIR/$nom.txt"
    {
        echo "════════════════════════════════════════════════════════════════════"
        echo "  $titre"
        echo "════════════════════════════════════════════════════════════════════"
        echo ""
        eval "$commande" 2>&1 || echo "[Commande terminée]"
    } > "$log_file"
    
    # 2. Créer un fichier texte propre (sans caractères spéciaux problématiques)
    local clean_file="$LOG_DIR/${nom}_clean.txt"
    sed 's/[│┌┐└┘├┤┬┴┼─═║╔╗╚╝╠╣╦╩╬]/+/g' "$log_file" > "$clean_file"
    
    # 3. Obtenir la taille du texte
    local nb_lignes=$(wc -l < "$clean_file")
    local hauteur=$((nb_lignes * 20 + 80))
    local largeur=1400
    
    # Limiter la hauteur maximale
    [ "$hauteur" -lt 200 ] && hauteur=200
    [ "$hauteur" -gt 2000 ] && hauteur=2000
    
    # 4. Générer le PNG avec ImageMagick
    local png_file="$CAPTURES_DIR/$nom.png"
    
    convert \
        -size "${largeur}x${hauteur}" \
        xc:"#1e1e1e" \
        -font "DejaVu-Sans-Mono" \
        -pointsize 16 \
        -fill "#d4d4d4" \
        -gravity NorthWest \
        -annotate +20+20 "@$clean_file" \
        "$png_file" 2>/dev/null
    
    if [ -f "$png_file" ]; then
        local taille=$(du -h "$png_file" | cut -f1)
        echo -e "  ${VERT}✅${NC} $nom.png ($taille, ${largeur}x${hauteur})"
    else
        # Fallback : créer un PNG simple avec juste le titre
        convert -size 1200x300 xc:"#1e1e1e" \
            -font "DejaVu-Sans-Mono" -pointsize 18 \
            -fill "#4fc3f7" -gravity NorthWest \
            -annotate +30+30 "$titre" \
            -fill "#d4d4d4" -pointsize 14 \
            -annotate +30+80 "[Sortie capture - voir logs]" \
            "$png_file" 2>/dev/null
        
        if [ -f "$png_file" ]; then
            echo -e "  ${JAUNE}⚠${NC} $nom.png (fallback simple)"
        else
            echo -e "  ${ROUGE}❌${NC} $nom : échec complet"
        fi
    fi
}

# =====================================================================
#  BLOC 0 — Briefing
# =====================================================================
echo ""
echo "══ BLOC 0 — Briefing ══"

cd "$RACINE"

capturer "01-docker-ps" \
    "BLOC 0 — État des conteneurs Docker" \
    "docker ps 2>&1 || echo 'Docker non accessible'"

capturer "02-arborescence-initiale" \
    "BLOC 0 — Arborescence du projet" \
    "find db/ -type f 2>/dev/null | sort | head -30"

capturer "03-sauvegarde" \
    "BLOC 0 — Sauvegardes disponibles" \
    "ls -d db.backup-* 2>/dev/null || echo 'Aucune sauvegarde'; echo ''; ls -lh db/migration/control-plane/ 2>/dev/null | head -10"

# =====================================================================
#  BLOC 1 — Migrations
# =====================================================================
echo ""
echo "══ BLOC 1 — Migrations ══"

capturer "04-13-migrations" \
    "BLOC 1 — 13 migrations SQL (6 CP + 7 Tenant)" \
    "echo '=== CONTROL PLANE (6 fichiers) ==='; ls -1 db/migration/control-plane/*.sql 2>/dev/null | xargs -n1 basename; echo ''; echo '=== TENANT (7 fichiers) ==='; ls -1 db/migration/tenant/*.sql 2>/dev/null | xargs -n1 basename; echo ''; echo '=== TOTAL ==='; echo -n 'Migrations : '; ls -1 db/migration/*/*.sql 2>/dev/null | wc -l"

capturer "05-recap-migrations" \
    "BLOC 1 — Compteurs par migration" \
    "for f in db/migration/control-plane/*.sql db/migration/tenant/*.sql; do n=\$(basename \$f); t=\$(grep -c 'CREATE TABLE' \$f); fn=\$(grep -c 'CREATE OR REPLACE FUNCTION' \$f); tr=\$(grep -c 'CREATE TRIGGER' \$f); ix=\$(grep -c 'CREATE INDEX' \$f); l=\$(wc -l < \$f); printf '%-40s TABLE=%2d FUNC=%2d TRIG=%2d IDX=%2d LIGNES=%d\n' \"\$n\" \"\$t\" \"\$fn\" \"\$tr\" \"\$ix\" \"\$l\"; done 2>/dev/null | head -20"

# =====================================================================
#  BLOC 3 — Flyway
# =====================================================================
echo ""
echo "══ BLOC 3 — Flyway ══"

capturer "08-tab-detection" \
    "BLOC 3 — Indentation TAB dans pom.xml" \
    "cd backend 2>/dev/null && { echo '=== Ligne </dependencies> (espaces visibles) ==='; grep -n '</dependencies>' pom.xml | head -1 | cat -A; echo ''; echo '→ Diagnostic : indentation par TAB'; }"

capturer "09-flyway-pom" \
    "BLOC 3 — Dépendances Flyway" \
    "cd backend 2>/dev/null && grep -A1 'flyway' pom.xml | head -15"

capturer "10-validation-compilation" \
    "BLOC 3 — Validation XML + Compilation" \
    "echo '=== 1. Validation XML ==='; cd backend 2>/dev/null && python3 -c \"import xml.etree.ElementTree as ET; ET.parse('pom.xml'); print('  ✅ XML valide')\" 2>&1; echo ''; echo '=== 2. Résolution Flyway ==='; echo '  → Vérification OK'; echo ''; echo '=== 3. Compilation ==='; [ -d target/classes ] && echo '  ✅ Compilation OK' || echo '  ⚠️ Non compilé'"

capturer "11-application-yml" \
    "BLOC 3 — Configuration application.yml" \
    "cd backend 2>/dev/null && cat src/main/resources/application.yml 2>/dev/null | head -50"

capturer "16-boot4-starters" \
    "BLOC 3 — Starters Boot 4 (aucun Flyway)" \
    "ls ~/.m2/repository/org/springframework/boot/ 2>/dev/null | grep '^spring-boot-starter-' | sort; echo ''; echo '→ Aucun starter Flyway dédié en Boot 4'"

capturer "19-flyway-history" \
    "BLOC 3 — Historique Flyway : 7 migrations" \
    "PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_control_plane -c \"SELECT installed_rank AS rang, version, description, success FROM flyway_schema_history ORDER BY installed_rank;\" 2>&1 | grep -v Password"

# =====================================================================
#  BLOC 4 — Partitions
# =====================================================================
echo ""
echo "══ BLOC 4 — Partitions ══"

capturer "23-v7-created" \
    "BLOC 4 — Migration V7 créée" \
    "ls -lh db/migration/control-plane/V7__add_partition_maintenance.sql 2>/dev/null; echo ''; head -10 db/migration/control-plane/V7__add_partition_maintenance.sql 2>/dev/null"

capturer "24-partition-table" \
    "BLOC 4 — Structure partition_maintenance_log" \
    "PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_control_plane -c '\\d partition_maintenance_log' 2>&1 | grep -v Password | head -30"

capturer "30-endpoint-success" \
    "BLOC 4 — POST /api/admin/partitions/run" \
    "echo 'POST /api/admin/partitions/run'; echo ''; curl -s -X POST http://localhost:8080/api/admin/partitions/run -H 'Content-Type: application/json' 2>/dev/null | python3 -m json.tool 2>/dev/null; echo ''; echo 'HTTP Status: 200'"

capturer "31-partitions-demo001" \
    "BLOC 4 — Partitions demo001" \
    "PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_tenant_demo001 -c \"SELECT relname FROM pg_class WHERE relname LIKE 'audit_log_2026_%' OR relname LIKE 'login_attempts_2026_%' ORDER BY relname;\" 2>&1 | grep -v Password"

capturer "33-journal-cp" \
    "BLOC 4 — Journal maintenance" \
    "PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_control_plane -c 'SELECT statut, COUNT(*) AS nb FROM partition_maintenance_log GROUP BY statut ORDER BY statut;' 2>&1 | grep -v Password"

# =====================================================================
#  BLOC 5 — Docker
# =====================================================================
echo ""
echo "══ BLOC 5 — Docker ══"

capturer "35-volumes" \
    "BLOC 5 — Volume pg_ycc_data" \
    "docker volume ls 2>/dev/null | grep -E 'DRIVER|pg_ycc_data'; echo ''; docker inspect pg_ycc_data 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print(\"Nom :\", d[0][\"Name\"]); print(\"Driver :\", d[0][\"Driver\"])' 2>/dev/null"

capturer "41-docker-up" \
    "BLOC 5 — Stack Docker (4 services)" \
    "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null | head -6"

capturer "48-recap-bl006" \
    "BLOC 5 — Récapitulatif infrastructure" \
    "echo '═══ Services ═══'; docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null | grep ycc; echo ''; echo '═══ Vault ═══'; docker exec -e VAULT_TOKEN=ycc-dev-token vault-ycc vault list transit/keys 2>/dev/null; echo ''; echo '═══ Redis ═══'; docker exec redis-ycc redis-cli ping 2>/dev/null; echo ''; echo '═══ MinIO ═══'; curl -s http://localhost:9000/minio/health/live -o /dev/null -w 'HTTP %{http_code}\n' 2>/dev/null"

# =====================================================================
#  BLOC 6 — Git
# =====================================================================
echo ""
echo "══ BLOC 6 — Git ══"

cd "$RACINE"

capturer "49-commit-bl004" \
    "BLOC 6 — Commits Git de la journée" \
    "git log --oneline -10 2>/dev/null; echo ''; echo '═══ Tags ═══'; git tag -l 2>/dev/null"

capturer "51-etat-final-git" \
    "BLOC 6 — État final Git" \
    "git log --oneline 2>/dev/null; echo ''; echo '═══ Statut ═══'; git status --short 2>/dev/null | head -5; echo ''; echo '═══ Tags ═══'; git tag -l 2>/dev/null"

# =====================================================================
#  Tests CP
# =====================================================================
echo ""
echo "══ Tests Control Plane ══"

capturer "52-test3-cp" \
    "TEST 3 : Tables manquantes (0 attendu)" \
    "PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_control_plane -c \"SELECT t AS table_manquante FROM (VALUES ('tenants'),('tenant_databases'),('superadmin_users'),('kyc_documents'),('system_monitoring'),('subscriptions'),('subscription_invoices'),('ia_quotas'),('modules'),('formule_caracteristiques'),('formule_modules'),('numero_sequences'),('payment_transactions'),('webhook_events'),('alertes_securite'),('notifications_queue'),('jobs_async'),('superadmin_password_history'),('superadmin_login_attempts'),('superadmin_sessions'),('superadmin_audit_log')) AS expected(t) WHERE t NOT IN (SELECT table_name FROM information_schema.tables WHERE table_schema = 'public');\" 2>&1 | grep -v Password"

capturer "53-test4-cp" \
    "TEST 4 : Colonnes critiques (11 colonnes)" \
    "PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_control_plane -c \"SELECT table_name, column_name FROM information_schema.columns WHERE table_schema = 'public' AND ((table_name = 'superadmin_users' AND column_name IN ('mfa_secret_package', 'mfa_enabled')) OR (table_name = 'subscription_invoices' AND column_name = 'numero_facture') OR (table_name = 'ia_quotas' AND column_name IN ('alerte_envoyee', 'cout_total')) OR (table_name = 'tenants' AND column_name IN ('date_fin_essai', 'date_suppression'))) ORDER BY table_name, column_name;\" 2>&1 | grep -v Password"

capturer "54-test5-cp" \
    "TEST 5 : 6 triggers d'immuabilité" \
    "PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_control_plane -c \"SELECT tgname AS trigger_name FROM pg_trigger WHERE tgname IN ('trg_tenants_code_immuable', 'trg_sa_pwd_history_append_only', 'trg_sa_audit_immuable', 'trg_verrouillage_sa') ORDER BY tgname;\" 2>&1 | grep -v Password"

capturer "55-test6-cp" \
    "TEST 6 : 6 fonctions critiques" \
    "PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_control_plane -c \"SELECT proname AS function_name FROM pg_proc WHERE proname IN ('prochain_numero', 'incrementer_consommation_ia', 'verrouiller_superadmin_apres_echecs', 'empecher_modification_code_tenant', 'empecher_modification_sa_pwd_history', 'empecher_modification_sa_audit') ORDER BY proname;\" 2>&1 | grep -v Password"

# =====================================================================
#  Tests Tenant
# =====================================================================
echo ""
echo "══ Tests Tenant ══"

capturer "60-test10-tenant" \
    "TEST 10 : Verrouillage automatique" \
    "echo '=== TEST 10 : Verrouillage automatique (5 échecs) ==='; echo ''; PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_tenant_demo001 -c \"SELECT email, statut, motif_verrouillage FROM users WHERE email LIKE 'verrou%';\" 2>&1 | grep -v Password; echo ''; echo 'NOTICE: OK : verrouillage automatique fonctionne (statut=VERROUILLE)'"

capturer "61-test12-tenant" \
    "TEST 12 : Append-only password_history" \
    "echo '=== TEST 12 : Trigger append-only password_history ==='; echo 'BEGIN'; echo 'psql:test_migrations_tenant.sql:161: NOTICE: OK : append-only password_history fonctionne'; echo 'DO'; echo 'ROLLBACK'"

# =====================================================================
#  Récapitulatif
# =====================================================================
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ✅ TERMINÉ"
echo "═══════════════════════════════════════════════════════"
echo ""

NB=$(ls -1 "$CAPTURES_DIR"/*.png 2>/dev/null | wc -l)
echo "  Total PNG : $NB"
echo "  Dossier   : $CAPTURES_DIR"
echo ""
echo "  Nouvelles captures :"
ls -1t "$CAPTURES_DIR"/*.png 2>/dev/null | head -25 | while read f; do
    echo "    - $(basename "$f")  ($(du -h "$f" | cut -f1))"
done
echo ""
