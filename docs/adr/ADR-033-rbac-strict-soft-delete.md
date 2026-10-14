# ADR-033 — RBAC strict : révocation du privilège DELETE

## Statut
Acceptée (P1, 13 octobre 2026)

## Contexte
- Constat C31 : 7 tables du socle possèdent un `GRANT DELETE` accordé par les migrations V1 (l.235), V4 (l.98) et V5 (l.58) — toutes immuables (règle fondamentale).
- Tables concernées : `users`, `roles`, `role_permissions`, `user_roles`, `sessions_history`, `numero_sequences`, `user_invitations`.
- Design retenu : soft delete (`deleted_at`) — aucune suppression physique ne doit être autorisée.

## Décision
Créer la migration `V16__revoke_delete_strict_rbac.sql` qui :
1. Révoque `DELETE` sur les 7 tables pour `ycc_tenant_app`.
2. Est défensive (tolère l'absence du rôle en test).
3. Est idempotente (REVOKE est naturellement idempotent).
4. Vérifie qu'aucun GRANT DELETE ne subsiste.

## Conséquences
- Le rôle applicatif ne peut plus supprimer physiquement de lignes.
- Le soft delete est la seule voie de suppression.

## Références
- Planning v1.1 §5, modification M11
- Constat C31
- Migration V16
- Commit 451528f
