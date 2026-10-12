# Rapport journalier — T0.10

## Travaux réalisés
- Runner Flyway multi-tenant exécuté sur demo001 et demo002
- Contournement Spring Boot : MigrateTenantsMain (standalone JDBC + Flyway API)
- Correction convention Flyway : V14_add_tenant_mfa.sql → V14__add_tenant_mfa.sql

## Résultats obtenus
- demo001 : baseline V13 + V14, version_schema V7 → V14
- demo002 : baseline V13 + V14, version_schema V7 → V14
- flyway_schema_history créée pour les 2 tenants

## Difficultés rencontrées
- C36 : runner Spring ne se déclenche pas dans le contexte complet
- C37 : convention Flyway violée → fichier skipped

## Suite prévue
- T0.11 : documentation (README, BACKLOG, ADR), tag v0.5.1-assainissement
- P1 : corriger C36, brancher Vault
