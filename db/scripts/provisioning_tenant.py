#!/usr/bin/env python3
"""
=====================================================================
provisioning_tenant.py — Phase 1
=====================================================================
Automatise la création complète d'un espace client (tenant), sans
intervention humaine, conformément à NFR-SCAL-02 (délai < 5 minutes).

Séquence des 5 étapes :
  1. Création de la base PostgreSQL dédiée (ycc_tenant_<code>)
  2. Enregistrement de la ligne 'EN_COURS' dans tenant_databases
  3. Application des 7 migrations tenant (V1 → V7)
  4. Création du premier compte Admin Client
  5. Initialisation du quota IA du mois en cours

Rollback : si une étape échoue, la base créée est supprimée et la
ligne tenant_databases est basculée en 'ERREUR' (jamais supprimée).

Dépendances : psycopg2-binary, bcrypt
Réf. : Rapport 04-78 §3.1.1 / NFR-SCAL-02 / NFR-SEC-08 / NFR-IA-01
=====================================================================
"""

import argparse
import json
import logging
import os
import re
import secrets
import string
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import bcrypt
import psycopg2
import psycopg2.errors
import psycopg2.extras
import psycopg2.sql

# ---------------------------------------------------------------------
# Configuration du logging
# ---------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("provisioning")


# ---------------------------------------------------------------------
# Configuration des migrations
# ---------------------------------------------------------------------
RACINE_PROJET = Path(__file__).resolve().parent.parent.parent
DOSSIER_MIGRATIONS_TENANT = RACINE_PROJET / os.environ.get(
    "MIGRATIONS_TENANT_DIR", "db/migration/tenant"
)

FICHIERS_MIGRATIONS_TENANT = [
    "V1__init_tenant_socle.sql",
    "V2__add_password_history.sql",
    "V3__add_login_attempts.sql",
    "V4__add_tenant_extensions.sql",
    "V5__enrich_users_roles.sql",
    "V6__enrich_audit_sessions.sql",
    "V7__add_verrouillage_auto.sql",
]


# ---------------------------------------------------------------------
# Exceptions & Dataclasses
# ---------------------------------------------------------------------
class ErreurProvisioning(Exception):
    """Erreur levée à n'importe quelle étape du provisioning."""


@dataclass
class ConnexionInfo:
    """Paramètres de connexion à l'instance PostgreSQL (superuser)."""
    host: str
    port: int
    user: str
    password: str


# ---------------------------------------------------------------------
# Fonctions utilitaires
# ---------------------------------------------------------------------
def _nom_base_tenant(code_tenant: str) -> str:
    """Construit un nom de base PostgreSQL valide à partir du code tenant."""
    code_normalise = re.sub(r"[^a-z0-9]", "_", code_tenant.lower())
    return f"ycc_tenant_{code_normalise}"


def _generer_mot_de_passe_temporaire(longueur: int = 16) -> str:
    """Génère un mot de passe temporaire (NFR-SEC-08)."""
    alphabet = (
        "ABCDEFGHJKLMNPQRSTUVWXYZ"
        "abcdefghijkmnopqrstuvwxyz"
        "23456789"
        "!@#$%^&*-_=+"
    )
    return "".join(secrets.choice(alphabet) for _ in range(longueur))


def _hacher_mot_de_passe(mot_de_passe: str) -> str:
    """Hash bcrypt (NFR-SEC-22)."""
    return bcrypt.hashpw(
        mot_de_passe.encode("utf-8"), bcrypt.gensalt(rounds=12)
    ).decode("utf-8")


def _executer_sql_fichier(conn, chemin: Path) -> None:
    """Exécute un fichier SQL en une seule transaction."""
    sql = chemin.read_text(encoding="utf-8")
    with conn.cursor() as cur:
        cur.execute(sql)


# ---------------------------------------------------------------------
# Étape 1 — Création de la base tenant
# ---------------------------------------------------------------------
def creer_base_tenant(conn_info: ConnexionInfo, nom_base: str) -> None:
    logger.info("Étape 1/5 — Création de la base %s (host=%s)", nom_base, conn_info.host)

    conn = psycopg2.connect(
        host=conn_info.host, port=conn_info.port,
        user=conn_info.user, password=conn_info.password, dbname="postgres",
    )
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute(
                psycopg2.sql.SQL("CREATE DATABASE {}").format(
                    psycopg2.sql.Identifier(nom_base)
                )
            )
    except psycopg2.errors.DuplicateDatabase as exc:
        raise ErreurProvisioning(
            f"La base {nom_base} existe déjà — pas de rollback automatique"
        ) from exc
    except psycopg2.Error as exc:
        raise ErreurProvisioning(f"Échec création base {nom_base} : {exc}") from exc
    finally:
        conn.close()


# ---------------------------------------------------------------------
# Étape 2 — Enregistrement dans tenant_databases
# ---------------------------------------------------------------------
def enregistrer_tenant_database(
    conn_info: ConnexionInfo, nom_base_control_plane: str,
    tenant_id: str, nom_base_tenant: str, host_tenant: str, port_tenant: int,
) -> None:
    logger.info("Étape 2/5 — Enregistrement EN_COURS dans tenant_databases")

    conn = psycopg2.connect(
        host=conn_info.host, port=conn_info.port,
        user=conn_info.user, password=conn_info.password, dbname=nom_base_control_plane,
    )
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO tenant_databases
                    (tenant_id, db_name, db_host, db_port, db_status)
                VALUES (%s, %s, %s, %s, 'EN_COURS')
                """,
                (tenant_id, nom_base_tenant, host_tenant, port_tenant),
            )
        conn.commit()
    except Exception as exc:
        conn.rollback()
        raise ErreurProvisioning(f"Échec enregistrement tenant_databases : {exc}") from exc
    finally:
        conn.close()


# ---------------------------------------------------------------------
# Étape 3 — Application des migrations
# ---------------------------------------------------------------------
def appliquer_migrations_tenant(conn_info: ConnexionInfo, nom_base: str) -> None:
    logger.info("Étape 3/5 — Application des migrations sur %s", nom_base)

    if not DOSSIER_MIGRATIONS_TENANT.exists():
        raise ErreurProvisioning(
            f"Dossier migrations introuvable : {DOSSIER_MIGRATIONS_TENANT}"
        )

    conn = psycopg2.connect(
        host=conn_info.host, port=conn_info.port,
        user=conn_info.user, password=conn_info.password, dbname=nom_base,
    )
    conn.autocommit = False
    try:
        for nom_fichier in FICHIERS_MIGRATIONS_TENANT:
            chemin = DOSSIER_MIGRATIONS_TENANT / nom_fichier
            if not chemin.exists():
                raise ErreurProvisioning(f"Fichier migration manquant : {chemin}")
            logger.info("  -> %s", nom_fichier)
            _executer_sql_fichier(conn, chemin)
        conn.commit()
    except Exception as exc:
        conn.rollback()
        raise ErreurProvisioning(f"Échec migrations sur {nom_base} : {exc}") from exc
    finally:
        conn.close()


# ---------------------------------------------------------------------
# Étape 4 — Création du premier Admin Client
# ---------------------------------------------------------------------
def creer_premier_admin(
    conn_info: ConnexionInfo, nom_base_tenant: str, email_admin: str,
    nom_admin: str = "Administrateur", prenom_admin: str = "Client",
) -> str:
    logger.info("Étape 4/5 — Création du compte Admin Client (%s)", email_admin)

    mot_de_passe_temporaire = _generer_mot_de_passe_temporaire()
    hash_mdp = _hacher_mot_de_passe(mot_de_passe_temporaire)

    conn = psycopg2.connect(
        host=conn_info.host, port=conn_info.port,
        user=conn_info.user, password=conn_info.password, dbname=nom_base_tenant,
    )
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO roles (nom, description, est_systeme, scope, statut)
                VALUES ('Administrateur Client',
                        'Root administrator du tenant — droits complets',
                        TRUE, '{"global": true}'::jsonb, 'ACTIF')
                RETURNING id
                """
            )
            role_admin_id = cur.fetchone()[0]

            cur.execute(
                """
                INSERT INTO role_permissions (role_id, permission_id, module_id, date_attribution)
                SELECT %s, p.id, m.id, now()
                FROM permissions p CROSS JOIN modules m
                """,
                (role_admin_id,),
            )

            cur.execute(
                """
                INSERT INTO users (
                    email, mot_de_passe_hash, nom, prenom,
                    type_utilisateur, statut, mfa_enabled, mot_de_passe_a_changer,
                    langue_preferee, fuseau_horaire, date_expiration_mot_de_passe
                ) VALUES (%s, %s, %s, %s, 'INTERNE', 'ACTIF', FALSE, TRUE,
                          'fr', 'Africa/Ouagadougou',
                          (CURRENT_DATE + INTERVAL '90 days')::DATE)
                RETURNING id
                """,
                (email_admin, hash_mdp, nom_admin, prenom_admin),
            )
            user_admin_id = cur.fetchone()[0]

            cur.execute(
                "INSERT INTO user_roles (user_id, role_id, statut) VALUES (%s, %s, 'ACTIF')",
                (user_admin_id, role_admin_id),
            )

            cur.execute(
                "INSERT INTO password_history (user_id, hash, motif) VALUES (%s, %s, 'FORCE')",
                (user_admin_id, hash_mdp),
            )

        conn.commit()
    except Exception as exc:
        conn.rollback()
        raise ErreurProvisioning(f"Échec création Admin Client : {exc}") from exc
    finally:
        conn.close()

    return mot_de_passe_temporaire


# ---------------------------------------------------------------------
# Étape 5 — Initialisation du quota IA
# ---------------------------------------------------------------------
def initialiser_quota_ia(
    conn_info: ConnexionInfo, nom_base_control_plane: str,
    tenant_id: str, formule: str,
) -> None:
    logger.info("Étape 5/5 — Initialisation du quota IA (formule=%s)", formule)

    conn = psycopg2.connect(
        host=conn_info.host, port=conn_info.port,
        user=conn_info.user, password=conn_info.password, dbname=nom_base_control_plane,
    )
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT quota_ia_mensuel
                FROM formule_caracteristiques
                WHERE formule = %s AND actif = TRUE
                ORDER BY date_effet DESC LIMIT 1
                """,
                (formule,),
            )
            row = cur.fetchone()
            if row is None:
                raise ErreurProvisioning(
                    f"Aucune formule active '{formule}' dans formule_caracteristiques"
                )
            quota_mensuel = row[0]

            cur.execute(
                """
                INSERT INTO ia_quotas
                    (tenant_id, formule, periode, quota_mensuel, consommation)
                VALUES (%s, %s, date_trunc('month', now())::DATE, %s, 0)
                ON CONFLICT (tenant_id, periode) DO NOTHING
                """,
                (tenant_id, formule, quota_mensuel),
            )
        conn.commit()
    except ErreurProvisioning:
        conn.rollback()
        raise
    except Exception as exc:
        conn.rollback()
        raise ErreurProvisioning(f"Échec initialisation quota IA : {exc}") from exc
    finally:
        conn.close()


# ---------------------------------------------------------------------
# Mise à jour du statut tenant_databases
# ---------------------------------------------------------------------
def marquer_tenant_database_statut(
    conn_info: ConnexionInfo, nom_base_control_plane: str,
    tenant_id: str, statut: str,
) -> None:
    if statut not in ("EN_COURS", "PROVISIONNEE", "ERREUR", "SUPPRIMEE"):
        raise ValueError(f"Statut invalide : {statut}")

    try:
        conn = psycopg2.connect(
            host=conn_info.host, port=conn_info.port,
            user=conn_info.user, password=conn_info.password, dbname=nom_base_control_plane,
        )
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE tenant_databases SET db_status = %s, date_maj = now() WHERE tenant_id = %s",
                    (statut, tenant_id),
                )
            conn.commit()
        except Exception:
            conn.rollback()
            logger.exception("Échec mise à jour statut tenant_databases -> %s", statut)
        finally:
            conn.close()
    except Exception:
        logger.exception("Impossible de se connecter pour mettre à jour le statut")


# ---------------------------------------------------------------------
# Rollback
# ---------------------------------------------------------------------
def _supprimer_base_tenant(conn_info: ConnexionInfo, nom_base: str) -> None:
    logger.warning("Rollback — suppression de la base %s", nom_base)

    conn = psycopg2.connect(
        host=conn_info.host, port=conn_info.port,
        user=conn_info.user, password=conn_info.password, dbname="postgres",
    )
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
                "WHERE datname = %s AND pid <> pg_backend_pid()",
                (nom_base,),
            )
            cur.execute(
                psycopg2.sql.SQL("DROP DATABASE IF EXISTS {}").format(
                    psycopg2.sql.Identifier(nom_base)
                )
            )
    finally:
        conn.close()


# ---------------------------------------------------------------------
# Envoi hors bande
# ---------------------------------------------------------------------
def envoyer_identifiants_hors_bande(email_admin: str, mot_de_passe_temporaire: str) -> None:
    """Envoi hors bande des identifiants (à implémenter en production).

    Le mot de passe ne doit JAMAIS être écrit sur disque ni journalisé.
    """
    raise NotImplementedError(
        "Brancher ici l'envoi transactionnel réel (SMTP/SES/SendGrid). "
        "Ne jamais journaliser ni afficher le mot de passe en clair."
    )


# ---------------------------------------------------------------------
# Orchestrateur principal
# ---------------------------------------------------------------------
def provisionner_tenant(
    conn_info: ConnexionInfo,
    nom_base_control_plane: str,
    tenant_id: str,
    code_tenant: str,
    email_admin: str,
    formule: str = "TRIAL",
    host_tenant: Optional[str] = None,
    port_tenant: int = 5432,
    nom_admin: str = "Administrateur",
    prenom_admin: str = "Client",
) -> dict:
    host_tenant = host_tenant or conn_info.host
    nom_base = _nom_base_tenant(code_tenant)

    logger.info("=" * 70)
    logger.info("Début provisioning tenant %s (%s)", code_tenant, nom_base)
    logger.info("=" * 70)

    base_creee_par_ce_run = False
    ligne_tenant_databases_creee = False

    try:
        creer_base_tenant(conn_info, nom_base)
        base_creee_par_ce_run = True

        enregistrer_tenant_database(
            conn_info, nom_base_control_plane, tenant_id,
            nom_base, host_tenant, port_tenant,
        )
        ligne_tenant_databases_creee = True

        appliquer_migrations_tenant(conn_info, nom_base)

        mot_de_passe_temporaire = creer_premier_admin(
            conn_info, nom_base, email_admin, nom_admin, prenom_admin
        )

        initialiser_quota_ia(conn_info, nom_base_control_plane, tenant_id, formule)

        marquer_tenant_database_statut(
            conn_info, nom_base_control_plane, tenant_id, "PROVISIONNEE"
        )

        logger.info("=" * 70)
        logger.info("Provisioning terminé avec succès : %s", nom_base)
        logger.info("=" * 70)

        return {
            "status": "SUCCESS",
            "db_name": nom_base,
            "admin_user": email_admin,
            "mot_de_passe_temporaire": mot_de_passe_temporaire,
        }

    except ErreurProvisioning:
        if base_creee_par_ce_run:
            logger.error("Échec après création — nettoyage")
            _supprimer_base_tenant(conn_info, nom_base)

        if ligne_tenant_databases_creee:
            marquer_tenant_database_statut(
                conn_info, nom_base_control_plane, tenant_id, "ERREUR"
            )
        else:
            logger.error(
                "Échec avant création (%s existe probablement) — aucun nettoyage",
                nom_base,
            )
        raise


# ---------------------------------------------------------------------
# Point d'entrée CLI
# ---------------------------------------------------------------------
def _main() -> int:
    parser = argparse.ArgumentParser(
        description="Provisioning automatisé d'un tenant yCogniCore Cloud"
    )
    parser.add_argument("--tenant-id", required=True)
    parser.add_argument("--code-tenant", required=True)
    parser.add_argument("--email-admin", required=True)
    parser.add_argument("--nom-admin", default="Administrateur")
    parser.add_argument("--prenom-admin", default="Client")
    parser.add_argument("--formule", default="TRIAL", choices=["TRIAL", "STANDARD", "ENTERPRISE"])
    parser.add_argument("--host-tenant", default=None)
    parser.add_argument("--port-tenant", type=int, default=5432)
    parser.add_argument("--send-email", action="store_true")
    parser.add_argument("--dry-run", action="store_true")

    args = parser.parse_args()

    conn_info = ConnexionInfo(
        host=os.environ.get("PG_HOST", "localhost"),
        port=int(os.environ.get("PG_PORT", "5432")),
        user=os.environ.get("PG_ADMIN_USER", "postgres"),
        password=os.environ.get("PG_ADMIN_PASSWORD", ""),
    )
    nom_base_cp = os.environ.get("CONTROL_PLANE_DB", "ycc_control_plane")

    if not conn_info.password:
        logger.error("PG_ADMIN_PASSWORD non défini")
        return 2

    if args.dry_run:
        logger.info("Mode dry-run — configuration :")
        logger.info("  Host PostgreSQL    : %s:%s", conn_info.host, conn_info.port)
        logger.info("  User               : %s", conn_info.user)
        logger.info("  Control plane DB   : %s", nom_base_cp)
        logger.info("  Tenant ID          : %s", args.tenant_id)
        logger.info("  Code tenant        : %s", args.code_tenant)
        logger.info("  Base tenant        : %s", _nom_base_tenant(args.code_tenant))
        logger.info("  Email admin        : %s", args.email_admin)
        logger.info("  Formule            : %s", args.formule)
        logger.info("  Dossier migrations : %s", DOSSIER_MIGRATIONS_TENANT)
        return 0

    try:
        resultat = provisionner_tenant(
            conn_info=conn_info,
            nom_base_control_plane=nom_base_cp,
            tenant_id=args.tenant_id,
            code_tenant=args.code_tenant,
            email_admin=args.email_admin,
            formule=args.formule,
            host_tenant=args.host_tenant,
            port_tenant=args.port_tenant,
            nom_admin=args.nom_admin,
            prenom_admin=args.prenom_admin,
        )
    except ErreurProvisioning as exc:
        logger.error("Échec du provisioning : %s", exc)
        return 1

    sortie = {
        "status": resultat["status"],
        "db_name": resultat["db_name"],
        "admin_user": resultat["admin_user"],
    }

    if args.send_email:
        envoyer_identifiants_hors_bande(
            email_admin=resultat["admin_user"],
            mot_de_passe_temporaire=resultat["mot_de_passe_temporaire"],
        )
        sortie["mot_de_passe_envoye_par_email"] = True
    else:
        logger.warning("Mode test : mot de passe affiché sur stdout")
        sortie["mot_de_passe_temporaire"] = resultat["mot_de_passe_temporaire"]

    print(json.dumps(sortie, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(_main())
