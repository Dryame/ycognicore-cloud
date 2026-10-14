# ADR-032 — Protection du registre d'audit contre TRUNCATE

## Statut
Acceptée (P1, 13 octobre 2026)

## Contexte
- Constat C3 : `audit_log` et les tables append-only sont protégées contre `UPDATE` et `DELETE` par des triggers de niveau ligne, mais **pas contre `TRUNCATE`**.
- `TRUNCATE` contourne les triggers `FOR EACH ROW`.

## Décision
1. Fonction `forbid_truncate()` avec `RAISE EXCEPTION` (ERRCODE 42501).
2. Trigger `BEFORE TRUNCATE` au niveau `STATEMENT` sur `audit_log`, ses 4 partitions et 5 tables append-only.
3. `REVOKE TRUNCATE` pour le rôle applicatif `ycc_tenant_app`.
4. Migration défensive et idempotente (`V15__protect_audit_log_from_truncate.sql`).

## Conséquences
- Toute tentative de `TRUNCATE` sur `audit_log` échoue avec un code SQL 42501.
- Les scripts de test doivent utiliser une procédure de nettoyage dédiée.

## Références
- Planning v1.1 §5, modification M11
- Constat C3
- Migration V15
- Commit 451528f
