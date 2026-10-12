# ADR-030 — Convention de nommage des migrations Flyway

## Statut
Acceptée (P0, 12 octobre 2026)

## Contexte
Les migrations tenant V1 à V13 ont été appliquées par script Python sans
respecter la convention Flyway. Lors de l'adoption de Flyway pour les tenants
(T0.9), V14 a été initialement nommée `V14_add_tenant_mfa.sql` (simple
underscore), et a été **skippée** par Flyway (C37).

## Décision
Toutes les migrations tenant et control plane **doivent** respecter :

    V<version>__<description>.sql

- Double underscore obligatoire entre version et description.
- Version entière croissante (V1, V2, ..., V14, ...).
- Description en minuscules avec underscores.

## Conséquences
- V14 renommée `V14__add_tenant_mfa.sql` (commit T0.10).
- V1 à V13 restent inchangées (immuables, baselinées à V13).
- Un contrôle CI en P1 vérifiera la conformité des nouvelles migrations.

## Références
- C37 (registre des constats)
- M30 (runner Flyway multi-tenant)
- Règle fondamentale sur les migrations
