# Bloc 1.2 — Module CRM

**Projet** : yCogniCore Cloud
**Phase** : 2 — Modules métier
**Bloc** : 1.2 — Module CRM
**Date** : 07 octobre 2026
**Statut** : En cours de conception

---

## Objet du bloc

Concevoir et implémenter le premier module métier de la Phase 2 : le CRM (Customer Relationship Management).

Le CRM est le point d'entrée du flux commercial de la plateforme. Il gère le cycle complet de prospection, depuis l'identification d'un prospect jusqu'à sa conversion en client.

---

## Livrables du bloc

- `01-mcd.md` — Modèle Conceptuel de Données (8 tables, 14 relations)
- `02-diagramme-etat.md` — Cycles de vie des pistes et opportunités
- `03-dictionnaire-donnees.md` — Documentation colonne par colonne des 8 tables
- `04-regles-metier.md` — Règles fonctionnelles, workflow, scoring
- `05-diagramme-sequence.md` — Flux Piste vers Client (5 étapes)
- `06-tests.md` — Plan de tests complets (~40 tests)
- `07-sql-v9.md` — Migration Flyway V9__init_crm.sql

---

## Prérequis

- Bloc 1.1 (MCD Haut Niveau) terminé et commité
- Socle V8 (27 ENUMs + fonctions) appliqué
- Directives de conception BDD prises en compte

---

## Conventions appliquées

- Clé primaire UUID (sauf référentiel `crm_pipeline_etapes` en SERIAL)
- Colonnes techniques : `created_at`, `created_by`, `updated_at`, `updated_by`, `deleted_at`, `version`
- Soft delete obligatoire
- Verrouillage optimiste via `version`
- FK RESTRICT par défaut
- Contraintes CHECK sur données métier
- Index sur FK et colonnes de recherche
- Multi-tenant transparent (aucun `tenant_id`)

---

## Progression

- MCD global : Terminé
- Diagramme d'état : Terminé
- Dictionnaire de données : Terminé
- Règles métier : Terminé
- Diagramme de séquence : Terminé
- Tests : Terminé
- SQL V9 : Terminé
- Commit et tag : À faire
