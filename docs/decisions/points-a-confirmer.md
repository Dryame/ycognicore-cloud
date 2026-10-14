# Points à confirmer avec l'encadreur

## Décisions techniques (P0)

### T0.8 — Version PostgreSQL de référence
- **Décision** : PostgreSQL 16
- **Justification** : conteneur pg-ycc, docker-compose.yml, bases tenant
- **Écart** : rapport n°06 mentionne 18.6 — à corriger (M07)

## Constats de l'audit du dépôt (12 octobre 2026)

### C19 — Nom indexé ≠ nom HEAD (Git)
Contournement : utiliser `git ls-files` au lieu de `git mv` sur ces chemins.

### C27 — `REPO_DIR` en dur dans `consolidate_all.sh`
- **Ligne** : 13 (`$HOME/projets/ycognicore-cloud`)
- **Correction P1** : variable d'environnement

### C31 — GRANT DELETE sur 7 tables (RBAC strict différé P1)
- **Tables** : users, roles, role_permissions, user_roles, sessions_history,
  numero_sequences, user_invitations
- **Origine** : V1 (l.235), V4 (l.98), V5 (l.58) — migrations immuables
- **Conflit** : design soft delete (deleted_at) vs GRANT DELETE
- **Correction P1** : V15 = REVOKE + anti-TRUNCATE

### C32 — Test V12 T-23 (règle d'automatisation vide)
- **Constat** : crm_regles_automatisation = 0 ligne après TRUNCATE-bypass
- **Origine** : stash T0.2 incomplet
- **Correction P1** : seed crm_regles_automatisation

### C34 — `MultiTenantConnectionProviderImpl` (Vault)
- `dbUser = "postgres"` en dur, fallback `ycc.partition.db-password`
- **Correction P1** : brancher Vault via db_secret_ref

### C36 — Runner Spring ne se déclenche pas
- `TenantMigrationRunner` (ApplicationRunner + @ConditionalOnProperty)
  n'apparaît pas dans les logs malgré `ycc.migration.runner=true`
- **Contournement P0** : MigrateTenantsMain (standalone JDBC)
- **Correction P1** : investiguer ordre d'exécution, @EventListener

### C37 — Convention Flyway non respectée
- Migrations tenant au format `V<n>_<desc>.sql` (simple underscore)
- Flyway exige `V<n>__<desc>.sql` (double underscore)
- **Correction P0** : V14 renommé `V14__add_tenant_mfa.sql`
- **Report P1** : documenter la convention + contrôle CI

## Points en attente (catalogue 7.1)
- Seuils de performance (ET2, ET4, F4)
- Référence légale IP (F9)
- Fréquence des tests de restauration (4.16)
- Liste des champs sensibles (5.5.3)
- Périmètre workflow (5.10)
- Permission de console (5.3)
- Technologie recherche sémantique (5.7)
- Modules RBAC (Phase 6)
- Fournisseur LLM (HYP-01, HYP-04)

---

# Points à confirmer avec l'encadreur

**Référence** : catalogue des modules v1.1, section 7.1
**Statut** : en attente de validation
**Date d'ouverture** : 14 octobre 2026

---

## P-01 — Valeurs cibles des seuils

- **Objet** : seuils de performance, de charge et de durée de session
- **Références** : ET2 (performances), ET4 (tests), F4 (sessions)
- **Point de départ** : cibles NFR-PERF du rapport n°04
- **Impact** : Phases 3, 10

## P-02 — Référence légale applicable à la collecte d'adresse IP

- **Objet** : référence légale de la collecte d'adresse IP et de la localisation approximative
- **Référence** : F9 (informations de connexion)
- **Impact** : Phase 3

## P-03 — Fréquence des tests de restauration

- **Objet** : fréquence des tests de restauration à réaliser
- **Référence** : 4.16 (sauvegarde)
- **Impact** : Phase 10

## P-04 — Liste des champs sensibles

- **Objet** : liste des champs soumis au chiffrement applicatif
- **Candidats** : secret MFA, identifiants fiscaux des tiers, coordonnées bancaires, téléphone
- **Référence** : 5.5.3 (chiffrement)
- **Impact** : Phase 4

## P-05 — Périmètre minimal du workflow sans code

- **Objet** : déclencheurs, conditions et actions autorisés
- **Référence** : 5.10 (workflow no-code)
- **Impact** : Phase 5

## P-06 — Mécanisme de la permission d'accès à la console

- **Objet** : mécanisme de permission distincte des six permissions RBAC
- **Proposition** : D-11 (tables droits_speciaux et role_droits_speciaux)
- **Référence** : 5.3 (console de sécurité)
- **Impact** : Phase 3

## P-07 — Technologie de recherche sémantique

- **Objet** : technologie retenue pour la recherche sémantique et exclusion des champs chiffrés
- **Proposition** : D-14 (index vectoriel PostgreSQL)
- **Référence** : 5.7 (recherche globale)
- **Impact** : Phase 9

## P-08 — Périmètre des modules RBAC

- **Objet** : parmi les 30 modules du catalogue, lesquels deviennent des modules RBAC
- **Référence** : catalogue v1.1, section 4
- **Impact** : Phase 6

## P-09 — Fournisseur de modèle de langage et hébergement

- **Objet** : fournisseur LLM et hébergement pour l'assistant IA
- **Références** : HYP-01, HYP-04
- **Impact** : Phase 9

## P-10 — Courtier de messages

- **Objet** : courtier retenu pour les événements inter-modules
- **Hypothèse actuelle** : RabbitMQ
- **Référence** : catalogue v1.1, N5
- **Impact** : Phase 5

---

## Suivi

| Réf. | Objet | Responsable | Échéance |
|---|---|---|---|
| P-01 | Seuils de performance et charge | Encadreur | Avant P3 |
| P-02 | Référence légale IP | Encadreur | Avant P3 |
| P-03 | Fréquence tests restauration | Encadreur | Avant P10 |
| P-04 | Liste des champs sensibles | Encadreur | Avant P4 |
| P-05 | Périmètre du workflow | Encadreur | Avant P5 |
| P-06 | Permission de console | Encadreur | Avant P3 |
| P-07 | Recherche sémantique | Encadreur | Avant P9 |
| P-08 | Modules RBAC | Encadreur | Avant P6 |
| P-09 | Fournisseur LLM | Encadreur | Avant P9 |
| P-10 | Courtier de messages | Encadreur | Avant P5 |
