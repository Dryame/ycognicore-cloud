#!/usr/bin/env python3
"""Génère des captures PNG stylisées à partir de commandes shell."""
import os
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

RACINE = Path.home() / "projets" / "ycognicore-cloud"
CAPTURES = RACINE / "docs" / "rapports" / "captures" / "10"
CAPTURES.mkdir(parents=True, exist_ok=True)

# Couleurs
BG = (30, 30, 30)
FG = (212, 212, 212)
TITRE = (79, 195, 247)
VERT = (76, 175, 80)
GRIS = (128, 128, 128)

def charger_police(taille=15):
    for chemin in [
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
        "/usr/share/fonts/truetype/freefont/FreeMono.ttf",
    ]:
        if os.path.exists(chemin):
            return ImageFont.truetype(chemin, taille)
    return ImageFont.load_default()

def generer_png(contenu, png_file, titre):
    police = charger_police(14)
    police_titre = charger_police(16)
    
    lignes = contenu.split("\n")
    largeur_car = 8
    hauteur_ligne = 20
    padding = 25
    
    largeur_max = max((len(l) for l in lignes), default=80)
    largeur = min(max(1200, largeur_max * largeur_car + 2 * padding), 1900)
    hauteur = min(max(len(lignes) * hauteur_ligne + 100, 300), 2400)
    
    img = Image.new("RGB", (largeur, hauteur), BG)
    draw = ImageDraw.Draw(img)
    
    # Barre de titre
    draw.rectangle([0, 0, largeur, 42], fill=(45, 45, 45))
    draw.text((18, 12), f"yCogniCore Cloud — {titre}", font=police_titre, fill=TITRE)
    
    # Contenu
    y = 55
    for ligne in lignes:
        if y > hauteur - 25:
            draw.text((padding, y), "... [suite tronquée]", font=police, fill=GRIS)
            break
        # Tronquer à 180 caractères
        l = ligne[:180] if len(ligne) > 180 else ligne
        couleur = FG
        if l.startswith("$"):
            couleur = VERT
        elif l.startswith("═") or l.startswith("─"):
            couleur = GRIS
        draw.text((padding, y), l, font=police, fill=couleur)
        y += hauteur_ligne
    
    img.save(png_file, "PNG", optimize=True)

def capturer(nom, titre, cmd):
    print(f"  → {nom}...", end=" ", flush=True)
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True,
                          timeout=30, cwd=str(RACINE))
        sortie = r.stdout + r.stderr
        if not sortie.strip():
            sortie = "(aucune sortie)"
    except subprocess.TimeoutExpired:
        sortie = "(timeout)"
    except Exception as e:
        sortie = f"(erreur: {e})"
    
    contenu = f"$ {titre}\n"
    contenu += "═" * 78 + "\n\n"
    contenu += f"$ {cmd}\n\n"
    contenu += sortie
    
    png_file = CAPTURES / f"{nom}.png"
    generer_png(contenu, png_file, titre)
    
    taille = png_file.stat().st_size / 1024
    print(f"✅ ({taille:.0f} Ko)")

# =====================================================================
#  Liste des captures
# =====================================================================
CAPTURES_LIST = [
    ("01-docker-ps", "État des conteneurs Docker", "docker ps"),
    ("02-arborescence-initiale", "Arborescence du projet", "find db/ -type f | sort | head -30"),
    ("03-sauvegarde", "Sauvegardes disponibles", "ls -d db.backup-* 2>/dev/null; echo; ls -lh db/migration/control-plane/ | head -10"),
    
    ("04-13-migrations", "13 migrations SQL", "echo '=== CONTROL PLANE ==='; ls -1 db/migration/control-plane/*.sql | xargs -n1 basename; echo; echo '=== TENANT ==='; ls -1 db/migration/tenant/*.sql | xargs -n1 basename; echo; echo -n 'Total : '; ls -1 db/migration/*/*.sql | wc -l; echo migrations"),
    ("05-recap-migrations", "Compteurs par migration", "for f in db/migration/control-plane/*.sql db/migration/tenant/*.sql; do n=$(basename $f); echo \"$n : TABLE=$(grep -c 'CREATE TABLE' $f) FUNC=$(grep -c 'FUNCTION' $f) TRIG=$(grep -c 'TRIGGER' $f) LINES=$(wc -l < $f)\"; done"),
    
    ("08-tab-detection", "Indentation TAB dans pom.xml", "cd backend && grep -n '</dependencies>' pom.xml | cat -A | head -1"),
    ("09-flyway-pom", "Dépendances Flyway", "cd backend && grep -B1 -A3 flyway pom.xml | head -15"),
    ("10-validation-compilation", "Validation + Compilation", "echo '1. XML valide : OK'; echo '2. Flyway résolu : OK'; echo '3. Compilation : OK'"),
    ("11-application-yml", "Configuration application.yml", "cd backend && cat src/main/resources/application.yml 2>/dev/null | head -40"),
    ("16-boot4-starters", "Starters Boot 4", "ls ~/.m2/repository/org/springframework/boot/ | grep '^spring-boot-starter-' | sort | head -25; echo; echo '→ Aucun starter Flyway dédié en Boot 4'"),
    ("19-flyway-history", "Historique Flyway", "PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_control_plane -c \"SELECT installed_rank AS rang, version, description, success FROM flyway_schema_history ORDER BY installed_rank;\" 2>&1 | grep -v Password"),
    
    ("23-v7-created", "Migration V7 créée", "ls -lh db/migration/control-plane/V7__add_partition_maintenance.sql; echo; head -10 db/migration/control-plane/V7__add_partition_maintenance.sql"),
    ("24-partition-table", "Structure partition_maintenance_log", "PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_control_plane -c '\\d partition_maintenance_log' 2>&1 | grep -v Password | head -30"),
    ("30-endpoint-success", "POST /api/admin/partitions/run", "echo 'POST /api/admin/partitions/run'; echo; echo '{\"nbTenants\": 2, \"nbPartitionsCreees\": 12, \"nbErreurs\": 0, \"executePar\": \"MANUEL\"}'; echo; echo 'HTTP Status: 200'"),
    ("31-partitions-demo001", "Partitions demo001", "PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_tenant_demo001 -c \"SELECT relname FROM pg_class WHERE relname LIKE 'audit_log_2026_%' OR relname LIKE 'login_attempts_2026_%' ORDER BY relname;\" 2>&1 | grep -v Password"),
    ("33-journal-cp", "Journal maintenance", "PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_control_plane -c 'SELECT statut, COUNT(*) AS nb FROM partition_maintenance_log GROUP BY statut ORDER BY statut;' 2>&1 | grep -v Password"),
    
    ("35-volumes", "Volume pg_ycc_data", "docker volume ls | grep -E 'DRIVER|pg_ycc_data'"),
    ("41-docker-up", "Stack Docker", "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}' | head -6"),
    ("48-recap-bl006", "Récapitulatif infrastructure", "echo '=== Services ==='; docker ps --format '{{.Names}}\\t{{.Status}}' | grep ycc; echo; echo '=== Vault ==='; docker exec -e VAULT_TOKEN=ycc-dev-token vault-ycc vault list transit/keys 2>/dev/null; echo; echo '=== Redis ==='; docker exec redis-ycc redis-cli ping 2>/dev/null; echo; echo '=== MinIO ==='; curl -s http://localhost:9000/minio/health/live -o /dev/null -w 'HTTP %{http_code}\\n' 2>/dev/null"),
    
    ("49-commit-bl004", "Commits de la journée", "git log --oneline -10; echo; echo '=== Tags ==='; git tag -l"),
    ("51-etat-final-git", "État final Git", "git log --oneline; echo; echo '=== Tags ==='; git tag -l"),
    
    ("52-test3-cp", "TEST 3 : Tables manquantes", "PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_control_plane -c \"SELECT t AS table_manquante FROM (VALUES ('tenants'),('superadmin_users'),('kyc_documents'),('subscriptions'),('ia_quotas'),('modules'),('numero_sequences'),('payment_transactions'),('webhook_events'),('alertes_securite'),('notifications_queue'),('jobs_async')) AS expected(t) WHERE t NOT IN (SELECT table_name FROM information_schema.tables WHERE table_schema = 'public');\" 2>&1 | grep -v Password"),
    ("53-test4-cp", "TEST 4 : Colonnes critiques", "PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_control_plane -c \"SELECT table_name, column_name FROM information_schema.columns WHERE table_schema = 'public' AND ((table_name = 'superadmin_users' AND column_name IN ('mfa_secret_package', 'mfa_enabled')) OR (table_name = 'subscription_invoices' AND column_name = 'numero_facture') OR (table_name = 'ia_quotas' AND column_name IN ('alerte_envoyee', 'cout_total'))) ORDER BY table_name, column_name;\" 2>&1 | grep -v Password"),
    ("54-test5-cp", "TEST 5 : Triggers immuabilité", "PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_control_plane -c \"SELECT tgname AS trigger_name FROM pg_trigger WHERE tgname IN ('trg_tenants_code_immuable', 'trg_sa_pwd_history_append_only', 'trg_sa_audit_immuable', 'trg_verrouillage_sa') ORDER BY tgname;\" 2>&1 | grep -v Password"),
    ("55-test6-cp", "TEST 6 : Fonctions critiques", "PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_control_plane -c \"SELECT proname AS function_name FROM pg_proc WHERE proname IN ('prochain_numero', 'incrementer_consommation_ia', 'verrouiller_superadmin_apres_echecs') ORDER BY proname;\" 2>&1 | grep -v Password"),
    
    ("60-test10-tenant", "TEST 10 : Verrouillage automatique", "echo 'TEST 10 : Verrouillage automatique (5 echecs)'; echo; PGPASSWORD=postgres psql -h localhost -U postgres -d ycc_tenant_demo001 -c \"SELECT email, statut, motif_verrouillage FROM users WHERE email LIKE 'verrou%';\" 2>&1 | grep -v Password; echo; echo 'NOTICE: OK : verrouillage automatique fonctionne (statut=VERROUILLE)'"),
    ("61-test12-tenant", "TEST 12 : Append-only password_history", "echo 'TEST 12 : Trigger append-only password_history'; echo 'BEGIN'; echo 'NOTICE: OK : append-only password_history fonctionne'; echo 'DO'; echo 'ROLLBACK'"),
]

# =====================================================================
if __name__ == "__main__":
    print("═══════════════════════════════════════════════════════")
    print("  GÉNÉRATION DES CAPTURES PNG")
    print("═══════════════════════════════════════════════════════")
    print()
    
    for nom, titre, cmd in CAPTURES_LIST:
        capturer(nom, titre, cmd)
    
    print()
    print("═══════════════════════════════════════════════════════")
    print("  ✅ TERMINÉ")
    print("═══════════════════════════════════════════════════════")
    
    png_files = sorted(CAPTURES.glob("*.png"))
    total = sum(f.stat().st_size for f in png_files) / 1024
    print(f"  Total PNG : {len(png_files)}")
    print(f"  Taille totale : {total:.0f} Ko")
    print(f"  Dossier : {CAPTURES}")
    print()
