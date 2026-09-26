"""
provisioning_tenant.py

Automatise la création complète d'un espace client (tenant), sans
intervention humaine, conformément à NFR-SCAL-02 (délai < 5 minutes).

Ce que fait ce script, dans l'ordre :
    1. Crée la base PostgreSQL dédiée au tenant (ycc_tenant_<code>)
    2. Applique les 3 migrations Flyway tenant (V1, V2, V3)
    3. Enregistre la base dans control_plane.tenant_databases
    4. Crée le premier compte Admin Client (mot de passe temporaire)
    5. Initialise le quota IA du mois en cours (control_plane.ia_quotas)

Si une étape échoue, tout est annulé (la base créée est supprimée) pour
ne jamais laisser un tenant dans un état à moitié provisionné.

Prérequis :
    pip install psycopg2-binary bcrypt

Réf. rapport 04-78 : section 3.1.1 (Provisioning), NFR-SCAL-02
"""

import logging
import re
import secrets
import string
from dataclasses import dataclass
from pathlib import Path

import bcrypt
import psycopg2
import psycopg2.extras
import psycopg2.sql

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

# Dossier contenant les 3 fichiers Flyway tenant (V1, V2, V3), dans l'ordre
BASE_DIR = Path(__file__).resolve().parent
DOSSIER_MIGRATIONS_TENANT = BASE_DIR

FICHIERS_MIGRATIONS_TENANT = [
    "V1__init_tenant_socle.sql",
    "V2__add_password_history.sql",
    "V3__add_login_attempts.sql",
]


@dataclass
class ConnexionInfo:
    """Paramètres de connexion à l'instance PostgreSQL (superuser de provisioning)."""
    host: str
    port: int
    user: str
    password: str


class ErreurProvisioning(Exception):
    """Erreur levée à n'importe quelle étape du provisioning."""


def _nom_base_tenant(code_tenant: str) -> str:
    """
    Construit un nom de base PostgreSQL valide à partir du code tenant.
    Ex. 'TEN-001' -> 'ycc_tenant_ten_001'
    """
    code_normalise = re.sub(r"[^a-z0-9]", "_", code_tenant.lower())
    return f"ycc_tenant_{code_normalise}"


def _generer_mot_de_passe_temporaire(longueur: int = 16) -> str:
    """Génère un mot de passe temporaire aléatoire (NFR-SEC-08)."""
    alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
    return "".join(secrets.choice(alphabet) for _ in range(longueur))


def _hacher_mot_de_passe(mot_de_passe: str) -> str:
    """Hash bcrypt du mot de passe (NFR-SEC-22 : jamais de mot de passe en clair)."""
    return bcrypt.hashpw(mot_de_passe.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def creer_base_tenant(conn_info: ConnexionInfo, nom_base: str) -> None:
    """
    Étape 1 : crée la base PostgreSQL vide du tenant.
    CREATE DATABASE ne peut pas s'exécuter dans une transaction —
    la connexion doit être en autocommit.
    """
    logger.info("Étape 1/5 — Création de la base %s", nom_base)
    conn = psycopg2.connect(
        host=conn_info.host, port=conn_info.port,
        user=conn_info.user, password=conn_info.password,
        dbname="postgres",
    )
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute(psycopg2.sql.SQL("CREATE DATABASE {}").format(
                psycopg2.sql.Identifier(nom_base)
            ))
    except psycopg2.errors.DuplicateDatabase as exc:
        raise ErreurProvisioning(f"La base {nom_base} existe déjà") from exc
    finally:
        conn.close()


def appliquer_migrations_tenant(conn_info: ConnexionInfo, nom_base: str) -> None:
    """
    Étape 2 : applique les migrations Flyway V1, V2, V3 dans l'ordre,
    sur la base tenant nouvellement créée.

    Note : en production, on appellerait ici le CLI Flyway réel
    (subprocess.run(["flyway", "migrate", ...])) pour bénéficier de sa
    table flyway_schema_history (traçabilité des versions appliquées).
    Cette version exécute directement les fichiers SQL pour rester
    autonome et testable sans dépendance externe.
    """
    logger.info("Étape 2/5 — Application des migrations sur %s", nom_base)
    conn = psycopg2.connect(
        host=conn_info.host, port=conn_info.port,
        user=conn_info.user, password=conn_info.password,
        dbname=nom_base,
    )
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            for nom_fichier in FICHIERS_MIGRATIONS_TENANT:
                chemin = DOSSIER_MIGRATIONS_TENANT / nom_fichier
                logger.info("  -> %s", nom_fichier)
                sql = chemin.read_text(encoding="utf-8")
                cur.execute(sql)
    except Exception as exc:
        raise ErreurProvisioning(f"Échec migration sur {nom_base} : {exc}") from exc
    finally:
        conn.close()


def enregistrer_tenant_database(
    conn_info: ConnexionInfo,
    nom_base_control_plane: str,
    tenant_id: str,
    nom_base_tenant: str,
    host_tenant: str,
    port_tenant: int,
) -> None:
    """Étape 3 : enregistre la référence de la base dans control_plane.tenant_databases."""
    logger.info("Étape 3/5 — Enregistrement dans tenant_databases")
    conn = psycopg2.connect(
        host=conn_info.host, port=conn_info.port,
        user=conn_info.user, password=conn_info.password,
        dbname=nom_base_control_plane,
    )
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO tenant_databases (tenant_id, db_name, db_host, db_port, db_status)
                VALUES (%s, %s, %s, %s, 'PROVISIONNEE')
                """,
                (tenant_id, nom_base_tenant, host_tenant, port_tenant),
            )
        conn.commit()
    except Exception as exc:
        conn.rollback()
        raise ErreurProvisioning(f"Échec enregistrement tenant_databases : {exc}") from exc
    finally:
        conn.close()


def creer_premier_admin(conn_info: ConnexionInfo, nom_base_tenant: str, email_admin: str) -> str:
    """
    Étape 4 : crée le compte Admin Client dans la base tenant, avec un
    mot de passe temporaire (renouvellement forcé à la 1ère connexion,
    déjà activé par défaut sur la colonne mot_de_passe_a_changer).
    Retourne le mot de passe en clair, à transmettre par email hors bande
    (jamais journalisé, jamais stocké en clair côté serveur).
    """
    logger.info("Étape 4/5 — Création du compte Admin Client (%s)", email_admin)
    mot_de_passe_temporaire = _generer_mot_de_passe_temporaire()
    hash_mdp = _hacher_mot_de_passe(mot_de_passe_temporaire)

    conn = psycopg2.connect(
        host=conn_info.host, port=conn_info.port,
        user=conn_info.user, password=conn_info.password,
        dbname=nom_base_tenant,
    )
    try:
        with conn.cursor() as cur:
            # Rôle système "Admin Client" : droits complets (Root administrator, section 1.2)
            cur.execute(
                """
                INSERT INTO roles (nom, description, est_systeme)
                VALUES ('Administrateur Client', 'Root administrator du tenant', TRUE)
                RETURNING id
                """
            )
            role_admin_id = cur.fetchone()[0]

            # Attribution des 6 permissions sur tous les modules pour ce rôle
            cur.execute(
                """
                INSERT INTO role_permissions (role_id, permission_id, module_id)
                SELECT %s, p.id, m.id FROM permissions p CROSS JOIN modules m
                """,
                (role_admin_id,),
            )

            cur.execute(
                """
                INSERT INTO users (email, mot_de_passe_hash, nom, prenom, type_utilisateur)
                VALUES (%s, %s, 'Administrateur', 'Client', 'INTERNE')
                RETURNING id
                """,
                (email_admin, hash_mdp),
            )
            user_admin_id = cur.fetchone()[0]

            cur.execute(
                "INSERT INTO user_roles (user_id, role_id) VALUES (%s, %s)",
                (user_admin_id, role_admin_id),
            )
        conn.commit()
    except Exception as exc:
        conn.rollback()
        raise ErreurProvisioning(f"Échec création Admin Client : {exc}") from exc
    finally:
        conn.close()

    return mot_de_passe_temporaire


def initialiser_quota_ia(
    conn_info: ConnexionInfo,
    nom_base_control_plane: str,
    tenant_id: str,
    formule: str,
) -> None:
    """Étape 5 : crée la ligne de quota IA du mois en cours pour ce tenant."""
    logger.info("Étape 5/5 — Initialisation du quota IA (formule=%s)", formule)
    quotas_par_formule = {"TRIAL": 100, "STANDARD": 1000, "ENTERPRISE": 10000}
    quota_mensuel = quotas_par_formule.get(formule, 100)

    conn = psycopg2.connect(
        host=conn_info.host, port=conn_info.port,
        user=conn_info.user, password=conn_info.password,
        dbname=nom_base_control_plane,
    )
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO ia_quotas (tenant_id, formule, periode, quota_mensuel)
                VALUES (%s, %s, date_trunc('month', now())::DATE, %s)
                """,
                (tenant_id, formule, quota_mensuel),
            )
        conn.commit()
    except Exception as exc:
        conn.rollback()
        raise ErreurProvisioning(f"Échec initialisation quota IA : {exc}") from exc
    finally:
        conn.close()


def _supprimer_base_tenant(conn_info: ConnexionInfo, nom_base: str) -> None:
    """Nettoyage en cas d'échec : supprime la base tenant créée à l'étape 1."""
    logger.warning("Rollback — suppression de la base %s", nom_base)
    conn = psycopg2.connect(
        host=conn_info.host, port=conn_info.port,
        user=conn_info.user, password=conn_info.password,
        dbname="postgres",
    )
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            # Coupe les connexions actives avant DROP (sinon DROP DATABASE échoue)
            cur.execute(
                """
                SELECT pg_terminate_backend(pid) FROM pg_stat_activity
                WHERE datname = %s AND pid <> pg_backend_pid()
                """,
                (nom_base,),
            )
            cur.execute(psycopg2.sql.SQL("DROP DATABASE IF EXISTS {}").format(
                psycopg2.sql.Identifier(nom_base)
            ))
    finally:
        conn.close()


def provisionner_tenant(
    conn_info: ConnexionInfo,
    nom_base_control_plane: str,
    tenant_id: str,
    code_tenant: str,
    email_admin: str,
    formule: str = "TRIAL",
    host_tenant: str | None = None,
    port_tenant: int = 5432,
) -> dict:
    """
    Orchestre les 5 étapes de provisioning. Le tenant_id doit déjà
    exister dans control_plane.tenants (créé lors de l'inscription,
    avant appel de cette fonction).

    Retourne un dict avec le nom de la base créée et le mot de passe
    temporaire de l'Admin Client (à transmettre hors bande, jamais loggé).
    """
    host_tenant = host_tenant or conn_info.host
    nom_base = _nom_base_tenant(code_tenant)

    logger.info("=== Début provisioning tenant %s (%s) ===", code_tenant, nom_base)

    # IMPORTANT : le rollback ne doit supprimer la base QUE si c'est CETTE
    # exécution qui l'a créée. Si creer_base_tenant() échoue parce que la
    # base existe déjà (ex. relance après incident, ou tenant déjà
    # provisionné), il ne faut surtout pas supprimer une base légitime
    # créée par un run précédent — ce serait une perte de données client.
    base_creee_par_ce_run = False

    try:
        creer_base_tenant(conn_info, nom_base)
        base_creee_par_ce_run = True

        appliquer_migrations_tenant(conn_info, nom_base)
        enregistrer_tenant_database(
            conn_info, nom_base_control_plane, tenant_id, nom_base, host_tenant, port_tenant
        )
        mot_de_passe_temporaire = creer_premier_admin(conn_info, nom_base, email_admin)
        initialiser_quota_ia(conn_info, nom_base_control_plane, tenant_id, formule)
    except ErreurProvisioning:
        if base_creee_par_ce_run:
            logger.error("Échec du provisioning après création de la base — nettoyage en cours")
            _supprimer_base_tenant(conn_info, nom_base)
        else:
            logger.error(
                "Échec avant toute création (%s existe probablement déjà) — "
                "aucun nettoyage effectué, la base existante n'est PAS touchée",
                nom_base,
            )
        raise

    logger.info("=== Provisioning terminé avec succès : %s ===", nom_base)
    return {"db_name": nom_base, "mot_de_passe_temporaire": mot_de_passe_temporaire}


if __name__ == "__main__":
    conn_info = ConnexionInfo(
        host="localhost",
        port=5432,
        user="postgres",
        password="yamess"
    )

    resultat = provisionner_tenant(
        conn_info=conn_info,
        nom_base_control_plane="ycc_control_plane",
        tenant_id="00000000-0000-0000-0000-000000000002",
        code_tenant="DEMO002",
        email_admin="admin@demo2-entreprise.bf",
        formule="STANDARD",
    )
    print(resultat)
