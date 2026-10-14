# ADR-034 — Profils Spring et externalisation des secrets

## Statut
Acceptée (P1, 13 octobre 2026)

## Contexte
- Constat C5 : `application.yml` contenait 4 secrets par défaut (mot de passe PostgreSQL, jeton Vault, secret JWT, mot de passe admin), visibles dans le dépôt public.

## Décision
1. Séparation en 3 fichiers :
   - `application.yml` : configuration de base, secrets externalisés (`${VAR}` sans fallback).
   - `application-dev.yml` : valeurs de développement locales.
   - `application-prod.yml` : aucune valeur par défaut.
2. Création de `.env.example` (15 variables documentées).
3. Le secret JWT doit faire ≥ 64 octets (contrainte HS512).

## Conséquences
- Aucun secret en clair dans le dépôt public.
- Le démarrage échoue si une variable requise est absente (fail-fast).

## Références
- Planning v1.1 §5, modifications M06, M32
- Constat C5
- Commit 3d6ff37
