# Base de données — Mises à jour du 03/10/2026

## Vue d'ensemble

Aucune nouvelle migration SQL créée aujourd'hui.

Les tables jobs_async et notifications_queue (control plane) ont été exploitées par les nouveaux workers (BL-018, BL-019).

## Tables utilisées par les nouveaux workers

### jobs_async (control plane)

Origine : Migration V4 CP (30/09/2026)

Utilisée par : F-23 Worker jobs_async

Colonnes utilisées :
- id (BIGSERIAL, PK)
- type_job (VARCHAR 100)
- tenant_id (UUID, nullable)
- payload (JSONB)
- statut (EN_ATTENTE, EN_COURS, TERMINE, ECHOUE)
- priorite (SMALLINT 1-10)
- tentatives (SMALLINT)
- max_tentatives (SMALLINT, défaut 3)
- next_retry_at (TIMESTAMPTZ)
- date_creation (TIMESTAMPTZ)
- date_debut (TIMESTAMPTZ)
- date_fin (TIMESTAMPTZ)
- erreur (TEXT)

Requêtes exécutées par le worker :
- SELECT : jobs EN_ATTENTE + next_retry_at null ou expiré
- UPDATE EN_COURS : statut + date_debut + tentatives++
- UPDATE TERMINE : statut + date_fin
- UPDATE ECHOUE : statut + date_fin + erreur
- UPDATE RETRY : statut EN_ATTENTE + next_retry_at + erreur

### notifications_queue (control plane)

Origine : Migration V4 CP (30/09/2026)

Utilisée par : F-24 Worker notifications

Colonnes utilisées :
- id (BIGSERIAL, PK)
- tenant_id (UUID, nullable)
- destinataire (VARCHAR 255)
- canal (EMAIL, SMS, WHATSAPP, TELEGRAM, PUSH, FACEBOOK)
- sujet (VARCHAR 255, nullable)
- contenu (TEXT)
- statut (EN_ATTENTE, ENVOYEE, ECHOUEE, ANNULEE)
- tentatives (SMALLINT)
- next_retry_at (TIMESTAMPTZ)
- date_creation (TIMESTAMPTZ)
- date_envoi (TIMESTAMPTZ)
- erreur (TEXT)
- metadata (JSONB)

Requêtes exécutées par le worker :
- SELECT : notifications EN_ATTENTE + next_retry_at null ou expiré
- UPDATE ENVOYEE : statut + date_envoi + tentatives++
- UPDATE ECHOUEE : statut + tentatives++ + erreur
- UPDATE RETRY : tentatives++ + next_retry_at + erreur

## Données de test insérées

### Jobs de test

Job 1 (LOG) :
- type_job : LOG
- payload : {"message": "hello worker", "source": "test"}
- statut : TERMINE
- tentatives : 1

Job 2 (UNKNOWN_TYPE) :
- type_job : UNKNOWN_TYPE
- payload : {"test": "retry"}
- statut : ECHOUE
- tentatives : 1
- erreur : "Handler introuvable : UNKNOWN_TYPE"

### Notifications de test

Notification 1 (EMAIL) :
- destinataire : test@demo001.bf
- canal : EMAIL
- sujet : Bienvenue
- contenu : Votre compte a ete cree
- statut : ENVOYEE
- tentatives : 1

Notification 2 (SMS) :
- destinataire : +226 70 00 00 00
- canal : SMS
- contenu : Code de verification : 123456
- statut : ENVOYEE
- tentatives : 1

## Modifications structurelles

Aucune modification structurelle (ALTER TABLE) en date du 03/10.

## Migrations appliquées

Control Plane :
- V1 à V7 appliquées

Tenant DEMO001 et DEMO002 :
- V1 à V8 appliquées

## Triggers actifs

- trg_tenants_code_immuable (tenants)
- trg_permissions_immuables (permissions)
- trg_audit_log_immuable (audit_log)
- trg_password_history_append_only (password_history)
- trg_sa_pwd_history_append_only (superadmin_password_history)
- trg_sa_audit_immuable (superadmin_audit_log)
- trg_verrouillage_auto (login_attempts)
- trg_verrouillage_sa (superadmin_login_attempts)

## Fonctions PL/pgSQL

- incrementer_consommation_ia(UUID, INTEGER) — CP
- prochain_numero(VARCHAR, INTEGER) — CP + Tenant
- creer_partition_mensuelle_audit_log(DATE) — Tenant
- creer_partition_mensuelle_login_attempts(DATE) — Tenant

---

Fin du document Base de données — 3 octobre 2026
