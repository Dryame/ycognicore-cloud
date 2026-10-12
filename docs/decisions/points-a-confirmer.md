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
