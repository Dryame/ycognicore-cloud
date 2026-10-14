# ADR-031 — CI bloquante avec analyse de secrets (gitleaks)

## Statut
Acceptée (P1, 13 octobre 2026)

## Contexte
- Constat C4 : la CI restait verte en cas d'échec de test (`continue-on-error: true`, compilation `-DskipTests`).
- Constat C5 : secrets par défaut dans `application.yml`, image MinIO en tag `latest`.

## Décision
1. Suppression de `continue-on-error: true` sur l'étape de tests.
2. Compilation en trois étapes : `clean compile` → `test` → `package -DskipTests`.
3. Ajout d'un service PostgreSQL 16 avec healthcheck `pg_isready`.
4. Ajout d'un job `security` utilisant `gitleaks/gitleaks-action@v2`.
5. Extension du job `summary` à quatre dépendances : `backend`, `frontend`, `quality`, `security`.

## Conséquences
- Un test cassé volontairement fait échouer la CI (preuve : workflow #24).
- Aucun secret en clair ne peut être fusionné sans échec.

## Références
- Planning v1.1 §5, modification M08
- Constats C4, C5
- Commits : 5bcccf9, 8b1676e
