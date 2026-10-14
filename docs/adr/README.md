# Index des décisions d'architecture (ADR)

**Référence** : planning prévisionnel v1.1, §6.5 (M62)
**Date d'inventaire** : 14 octobre 2026

---

## ADR présents

| Réf. | Fichier | Objet présumé |
|---|---|---|
| ADR-006 | ADR-006.md | Multi-tenant routing (BL-007) |
| ADR-008 | ADR-008.md | Spring Boot 4.1.1 LTS |
| ADR-009 | ADR-009.md | Angular 22.2.0 LTS |
| ADR-010 | ADR-010.md | Flyway (7 migrations control plane) |
| ADR-011 | ADR-011.md | Partitionnement PostgreSQL |
| ADR-012 | ADR-012.md | PostgreSQL 16 |
| ADR-013 | ADR-013.md | Docker Compose (pg, redis, vault, minio) |
| ADR-018-020 | ADR-018-020-sprint-h2-j3-j8.md | Sprint H2 J3-J8 |
| ADR-023 | ADR-023.md | À préciser |
| ADR-024 | ADR-024.md | Conventions transversales |
| ADR-025 | ADR-025.md | À préciser |
| ADR-026 | ADR-026.md | À préciser |
| ADR-027 | ADR-027.md | Soft delete |
| ADR-030 | ADR-030-convention-migrations-flyway.md | Convention Flyway |
| ADR-031 | ADR-031-ci-bloquante-gitleaks.md | CI bloquante + gitleaks |
| ADR-032 | ADR-032-protection-audit-truncate.md | Protection audit_log contre TRUNCATE |
| ADR-033 | ADR-033-rbac-strict-soft-delete.md | RBAC strict |
| ADR-034 | ADR-034-profils-spring-externalisation-secrets.md | Profils Spring et secrets |

---

## ADR manquants (trous historiques)

Ces ADR sont **cités** dans la documentation existante mais **absents** du dépôt.
Le contenu n'a pas pu être reconstruit à partir des sources disponibles.

| Réf. | Référence existante | Contenu | Statut |
|---|---|---|---|
| ADR-007 | BACKLOG l.247 (Rapport 06-78) | Non identifiable | TROU |
| ADR-014 | Aucune | Non identifiable | TROU |
| ADR-015 | BACKLOG l.366 | Non identifiable | TROU |
| ADR-016 | BACKLOG l.372 + F20-F24.md (BL-015, NFR-SEC-06/11) | Partiel | TROU |
| ADR-017 | BACKLOG l.378 + F20-F24.md (BL-016, NFR-SEC-06) | Partiel | TROU |
| ADR-021 | BACKLOG l.396 | Non identifiable | TROU |
| ADR-022 | BACKLOG l.396 | Non identifiable | TROU |
| ADR-028 | BACKLOG v1.8 (cité pour écart E12) | ENUM etape_pipeline non utilisé | TROU |

### Principe de traitement

Un ADR ne peut pas être **reconstruit** sans son contexte d'origine :

- Les décisions ADR-007, 014 à 017, 021, 022 concernent la **Phase 1** (clôturée).
  Leur contenu est **implicite** dans le code existant mais aucun énoncé d'origine
  n'est disponible.
- ADR-028 est lié à l'écart **E12** (ENUM `etape_pipeline` non utilisé en V9 CRM).
  Le correctif a déjà été appliqué (V9 refondu), l'ADR peut être considéré comme **obsolète**.

### Décision

- **Ne pas rédiger** d'ADR rétroactif inventé.
- **Corriger** les références mortes dans le BACKLOG (tâche T2.6).
- **Documenter** les trous (ce tableau).

---

## Convention de nommage

- Format : `ADR-NNN-<slug-court>.md`
- NNN : numéro à 3 chiffres
- slug : description courte en kebab-case

## Cycle de vie

- **Proposée** : en cours de rédaction
- **Acceptée** : validée et appliquée
- **Remplacée** : remplacée par un ADR ultérieur (référence croisée)
- **Obsolète** : plus applicable, conservée pour mémoire
