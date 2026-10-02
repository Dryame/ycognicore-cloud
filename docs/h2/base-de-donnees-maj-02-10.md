# Base de données — Mises à jour du 02/10/2026

**Projet** : yCogniCore Cloud
**Sprint** : H2 (Consolidation)
**Date** : 02/10/2026
**Changements** : Ajout rôle "Administrateur Client" + fix hash bcrypt

---

## 1. Vue d'ensemble des modifications

| # | Base | Table | Changement |
|---|---|---|---|
| 1 | `ycc_tenant_demo001` | `roles` | Ajout du rôle "Administrateur Client" |
| 2 | `ycc_tenant_demo001` | `role_permissions` | Ajout de 96 permissions (6 × 16) |
| 3 | `ycc_tenant_demo001` | `users` | Création de `admin@demo001.bf` |
| 4 | `ycc_tenant_demo001` | `user_roles` | Attribution du rôle à l'admin |
| 5 | `ycc_control_plane` | `superadmin_users` | Fix hash bcrypt |

---

## 2. Ajout du rôle "Administrateur Client"

### 2.1 Contexte

En Sprint H1, les seeds ne créaient que les **4 rôles métier préconfigurés** :
- Responsable Commercial
- Responsable Financier et Comptable
- Responsable des Stocks et Magasinier
- Responsable Achats

Le rôle **"Administrateur Client"** (Root administrator du tenant) était **absent**. Sans lui, impossible de distinguer un Admin d'un commercial.

### 2.2 Script SQL

```sql
-- 1. Créer le rôle
INSERT INTO roles (nom, description, est_systeme, scope, statut, date_creation)
VALUES ('Administrateur Client',
        'Root administrator du tenant - droits complets',
        TRUE,
        '{"global": true}'::jsonb,
        'ACTIF',
        now())
ON CONFLICT (nom) DO NOTHING;

-- 2. Attribuer les 6 permissions × 16 modules
INSERT INTO role_permissions (role_id, permission_id, module_id, date_attribution)
SELECT r.id, p.id, m.id, now()
  FROM roles r, permissions p, modules m
 WHERE r.nom = 'Administrateur Client'
ON CONFLICT DO NOTHING;

-- 3. Créer l'utilisateur admin
INSERT INTO users (email, mot_de_passe_hash, nom, prenom, type_utilisateur, statut,
                   mfa_enabled, mot_de_passe_a_changer, langue_preferee,
                   date_expiration_mot_de_passe, date_creation)
VALUES ('admin@demo001.bf',
        '<BCRYPT_HASH>',
        'ADMIN', 'Client', 'INTERNE', 'ACTIF',
        FALSE, TRUE, 'fr',
        (CURRENT_DATE + INTERVAL '90 days')::DATE, now())
ON CONFLICT (email) DO NOTHING;

-- 4. Attribuer le rôle à l'admin
INSERT INTO user_roles (user_id, role_id, date_attribution, statut)
SELECT u.id, r.id, now(), 'ACTIF'
  FROM users u, roles r
 WHERE u.email = 'admin@demo001.bf'
   AND r.nom = 'Administrateur Client'
ON CONFLICT DO NOTHING;
```

### 2.3 Vérification

```sql
SELECT u.email, r.nom AS role
  FROM users u
  JOIN user_roles ur ON ur.user_id = u.id
  JOIN roles r ON r.id = ur.role_id
 WHERE u.email = 'admin@demo001.bf';
```

**Résultat** :
```
     email       |         role
-----------------+----------------------
 admin@demo001.bf| Administrateur Client
```

---

## 3. Fix du hash bcrypt Superadmin

### 3.1 Contexte

Le hash bcrypt du Superadmin était **tronqué** (58 chars au lieu de 60), suite à une mauvaise interprétation bash des `$` lors du copier-coller.

### 3.2 Script Python (préféré pour éviter les problèmes d'échappement)

```python
import bcrypt
import subprocess

hash_val = bcrypt.hashpw(b"SuperAdmin@2026!", bcrypt.gensalt(rounds=12)).decode()

sql = f"""UPDATE superadmin_users SET mot_de_passe_hash = '{hash_val}' WHERE email = 'superadmin@ycognicore.bf';
SELECT email, LENGTH(mot_de_passe_hash) AS hash_len FROM superadmin_users WHERE email = 'superadmin@ycognicore.bf';
"""

with open("/tmp/fix_sa.sql", "w") as f:
    f.write(sql)

subprocess.run(["psql", "-h", "localhost", "-U", "postgres", "-d", "ycc_control_plane", "-f", "/tmp/fix_sa.sql"])
```

### 3.3 Vérification

```sql
SELECT email, LENGTH(mot_de_passe_hash) AS hash_len
  FROM superadmin_users
 WHERE email = 'superadmin@ycognicore.bf';
```

**Résultat** :
```
      email                | hash_len
---------------------------+----------
 superadmin@ycognicore.bf  |       60
```

---

## 4. État final des données

### 4.1 Control Plane (`ycc_control_plane`)

| Table | Enregistrements |
|---|---|
| `tenants` | 2 (DEMO001, DEMO002) |
| `superadmin_users` | 1 |
| `formule_caracteristiques` | 3 (TRIAL, STANDARD, ENTERPRISE) |
| `modules` | 16 |
| `subscriptions` | 0 |

### 4.2 Tenant DEMO001 (`ycc_tenant_demo001`)

| Table | Enregistrements |
|---|---|
| `users` | 5 (admin + commercial + comptable + magasinier + acheteur) |
| `roles` | 5 (4 métier + 1 Administrateur Client) |
| `permissions` | 6 |
| `modules` | 16 |
| `role_permissions` | ~176 (5 rôles × 6 permissions × 16 modules) |
| `audit_log` | Plusieurs entrées (tests AOP) |
| `numero_sequences` | 5 (DEVIS, BC, BL, FAC, AVOIR) |

### 4.3 Tenant DEMO002 (`ycc_tenant_demo002`)

| Table | Enregistrements |
|---|---|
| `users` | 4 (commercial, comptable, magasinier, acheteur) |
| `roles` | 4 (métier uniquement) |
| `permissions` | 6 |
| `modules` | 16 |

---

## 5. Migrations appliquées

### Control Plane (7 migrations)

| Version | Description |
|---|---|
| V1 | Socle initial |
| V2 | Abonnements |
| V3 | Quotas IA |
| V4 | Tables transversales |
| V5 | Sécurité Superadmin |
| V6 | Enrichissements |
| V7 | Maintenance partitions |

### Tenant DEMO001 (8 migrations)

| Version | Description |
|---|---|
| V1 | Socle RBAC + audit |
| V2 | Password history |
| V3 | Login attempts |
| V4 | Extensions (numérotation, paiements) |
| V5 | Enrichissements users/roles |
| V6 | Enrichissements audit/sessions |
| V7 | Verrouillage auto |
| **V8** | **MFA tenant (BL-012)** |

---

## 6. Triggers actifs

| Trigger | Table | Rôle |
|---|---|---|
| `trg_tenants_code_immuable` | tenants | Immutabilité du code |
| `trg_permissions_immuables` | permissions | UPDATE/DELETE interdits |
| `trg_audit_log_immuable` | audit_log | Append-only |
| `trg_password_history_append_only` | password_history | Append-only |
| `trg_sa_pwd_history_append_only` | superadmin_password_history | Append-only |
| `trg_sa_audit_immuable` | superadmin_audit_log | Append-only |
| `trg_verrouillage_auto` | login_attempts | Verrouillage après 5 échecs |
| `trg_verrouillage_sa` | superadmin_login_attempts | Idem Superadmin |

---

## 7. Fonctions PL/pgSQL

| Fonction | Base | Rôle |
|---|---|---|
| `incrementer_consommation_ia(UUID, INTEGER)` | CP | Incrément atomique quota IA |
| `prochain_numero(VARCHAR, INTEGER)` | CP + Tenant | Numérotation légale |
| `creer_partition_mensuelle_audit_log(DATE)` | Tenant | Création partition |
| `creer_partition_mensuelle_login_attempts(DATE)` | Tenant | Création partition |

---

## 8. Commandes utiles

### Vérifier l'état RBAC d'un utilisateur

```sql
SELECT m.code AS module, p.code AS permission
  FROM user_roles ur
  JOIN role_permissions rp ON rp.role_id = ur.role_id
  JOIN modules m ON m.id = rp.module_id
  JOIN permissions p ON p.id = rp.permission_id
 WHERE ur.user_id = (SELECT id FROM users WHERE email = 'commercial@demo001.bf')
 ORDER BY m.code, p.code;
```

### Vérifier le hash bcrypt

```sql
SELECT email, LENGTH(mot_de_passe_hash) AS len, LEFT(mot_de_passe_hash, 15) AS debut
  FROM users
 WHERE email IN ('admin@demo001.bf', 'commercial@demo001.bf');
```

**Attendu** : `len = 60` et `debut = $2b$12$...`.

### Vérifier l'audit JSONB

```sql
SELECT action, niveau, succes, details
  FROM audit_log
 ORDER BY timestamp DESC
 LIMIT 5;
```

**Attendu** : colonne `details` = objet JSON valide.

---

**Documentation BDD v1.0 — 02/10/2026**
