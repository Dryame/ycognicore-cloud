# PLAN DE SPRINT H2 — Consolidation

**Projet** : yCogniCore Cloud — Plateforme ERP SaaS
**Sprint** : H2 (Phase 1.2 — Consolidation)
**Durée** : 15 jours ouvrés
**Début** : 02/10/2026
**Fin prévue** : 22/10/2026
**Tag de clôture** : v0.4.0-phase1-h2-complete

---

## 1. Contexte et objectifs

### 1.1 Situation d'entrée

| Élément | Statut au 02/10 |
|---|---|
| Sprint H0 — Socle Invariable | Clôturé (6/6) |
| Sprint H1 — Backend socle | Clôturé (8/8) |
| Points BACKLOG soldés | 14/37 (38 %) |
| Phase 1 globale | ~92 % |
| Tests E2E | 14/14 PASS |
| Documentation H1 | Finalisée |

### 1.2 Objectif du Sprint H2

Transformer le backend fonctionnel (H1) en socle industriel : consolider les points reportés, construire l'interface frontend, automatiser les pipelines, préparer la sortie en production.

### 1.3 Enjeu stratégique

Le Sprint H2 conditionne le démarrage de la Phase 2 (conception BDD métier, ~75 tables).

---

## 2. Périmètre du Sprint H2

### 2.1 Blocs BACKLOG (H2 officiel)

| # | Bloc | Priorité | Risque |
|---|---|---|---|
| BL-015 | Frontend Angular Core | Haute | Moyen |
| BL-016 | Page login Auth Dispatcher | Haute | Faible |
| BL-017 | CI/CD pipeline | Moyenne | Moyen |
| BL-018 | Workers notifications multicanal | Moyenne | Moyen |
| BL-019 | Worker jobs_async | Moyenne | Faible |
| BL-020 | Tests d'intrusion cross-tenant | Haute | Élevé |
| BL-021 | Documentation technique (runbooks) | Basse | Faible |
| BL-022 | Matrice traçabilité NFR → Test → Code | Moyenne | Faible |

### 2.2 Points reportés H1

| # | Bloc | Priorité | Risque |
|---|---|---|---|
| BL-013.1 | RBAC réel | Haute | Moyen |
| BL-010.1 | Refactor PartitionMaintenanceService | Moyenne | Faible |
| BL-011.1 | Endpoint /api/auth/refresh | Moyenne | Faible |
| BL-011.2 | Distinction ADMIN vs INTERNE | Moyenne | Moyen |
| BL-015.1 | Mapping JSONB → JsonNode | Basse | Moyen |

---

## 3. Planning détaillé

### Semaine 1 — Fondations + Frontend

#### J1 (02/10) — Fondations backend 1/2

| Créneau | Tâche |
|---|---|
| Matin | BL-013.1 — RBAC réel |
| Après-midi | BL-010.1 — Refactor PartitionMaintenanceService |
| Fin | Tests + commit + rapport n°12 |

#### J2 (03/10) — Fondations backend 2/2

| Créneau | Tâche |
|---|---|
| Matin | BL-011.1 — Endpoint /api/auth/refresh |
| Après-midi | BL-011.2 — Distinction ADMIN vs INTERNE |
| Fin | Tests + commit + rapport n°13 |

#### J3 (04/10) — Mapping JSONB + Setup Frontend

| Créneau | Tâche |
|---|---|
| Matin | BL-015.1 — Mapping JSONB → JsonNode |
| Après-midi | BL-015 (Part 1) — Setup Angular : routing, intercepteurs |
| Fin | Tests + commit + rapport n°14 |

#### J4 (05/10) — Frontend Angular Core

| Créneau | Tâche |
|---|---|
| Matin | BL-015 (Part 2) — AuthService, JwtInterceptor, guards |
| Après-midi | BL-016 — Page login Auth Dispatcher |
| Fin | Tests + commit + rapport n°15 |

#### J5 (06/10) — Repos et point d'étape

| Créneau | Tâche |
|---|---|
| Matin | Tests login 4 profils |
| Après-midi | Revue Semaine 1 |
| Fin | Tag intermédiaire v0.4.0-rc1 |

### Semaine 2 — Infrastructure + Quality

#### J6 (09/10) — CI/CD Pipeline

| Créneau | Tâche |
|---|---|
| Matin | BL-017 — GitHub Actions workflow |
| Après-midi | Jobs backend + frontend + tests E2E |
| Fin | Commit + rapport n°16 |

#### J7 (10/10) — Workers jobs_async

| Créneau | Tâche |
|---|---|
| Matin | BL-019 — Worker jobs_async |
| Après-midi | Tests d'intégration + monitoring |
| Fin | Commit + rapport n°17 |

#### J8 (11/10) — Notifications multicanal

| Créneau | Tâche |
|---|---|
| Matin | BL-018 (Part 1) — Notifier Email + SMS |
| Après-midi | BL-018 (Part 2) — Notifier WhatsApp + retry |
| Fin | Commit + rapport n°18 |

#### J9 (12/10) — Tests d'intrusion

| Créneau | Tâche |
|---|---|
| Matin | BL-020 (Part 1) — Scénarios d'attaque |
| Après-midi | BL-020 (Part 2) — Audit + corrections |
| Fin | Commit + rapport n°19 |

#### J10 (13/10) — Point d'étape

| Créneau | Tâche |
|---|---|
| Matin | Préparation runbooks |
| Après-midi | Revue Sprint H2 mi-parcours |
| Fin | Récap intermédiaire |

### Semaine 3 — Finalisation + Clôture

#### J11 (16/10) — Runbooks

| Créneau | Tâche |
|---|---|
| Matin | BL-021 — 5 runbooks |
| Après-midi | Tests procédures + ajustements |
| Fin | Commit + rapport n°20 |

#### J12 (17/10) — Matrice traçabilité

| Créneau | Tâche |
|---|---|
| Matin | BL-022 — Extraction NFR Must-have |
| Après-midi | Mapping NFR → Test → Code |
| Fin | Commit + rapport n°21 |

#### J13 (18/10) — Tests E2E complets

| Créneau | Tâche |
|---|---|
| Matin | Relance script E2E complet |
| Après-midi | Tests intégration frontend + backend |
| Fin | Commit + rapport n°22 |

#### J14 (21/10) — Documentation et polish

| Créneau | Tâche |
|---|---|
| Matin | Documentation utilisateur |
| Après-midi | Mise à jour BACKLOG + ADR |
| Fin | Commit + rapport n°23 |

#### J15 (22/10) — Clôture Sprint H2

| Créneau | Tâche |
|---|---|
| Matin | Checklist Definition of Done |
| Après-midi | Tag v0.4.0-phase1-h2-complete + push |
| Fin | Rapport journalier n°24 |

---

## 4. Critères d'acceptation

### Un bloc est Done si

- Le code compile sans erreur (BUILD SUCCESS)
- Les tests unitaires passent
- Les tests E2E associés passent
- Aucune régression sur les 14 tests E2E existants
- Documentation mise à jour
- Commit Git propre
- Preuve d'exécution fournie

### Le Sprint H2 est clôturé si

- 13/13 points soldés
- 100 % des tests E2E passent
- 0 vulnérabilité critique
- 100 % NFR Must-have tracées
- 5 runbooks publiés
- Pipeline CI/CD vert
- Tag v0.4.0-phase1-h2-complete poussé

---

## 5. Risques et mitigations

| # | Risque | Probabilité | Impact | Mitigation |
|---|---|---|---|---|
| 1 | BL-013.1 casse RBAC | Moyenne | Élevé | Tests progressifs, rollback |
| 2 | BL-015.1 (JsonNode) casse entités | Moyenne | Élevé | Compiler + tester entité par entité |
| 3 | BL-017 pipeline échoue | Faible | Moyen | Test local avant push |
| 4 | BL-018 email SMTP bloqué | Faible | Moyen | Mock en dev |
| 5 | BL-020 faille critique | Faible | Critique | Patch immédiat |
| 6 | Angular 22 incompatible | Faible | Moyen | Validé en H0 |
| 7 | Régression E2E | Moyenne | Élevé | Relancer 14 tests à chaque bloc |

---

## 6. Jalons

| # | Jalon | Date | Livrable |
|---|---|---|---|
| M1 | Fondations backend soldées | J2 (03/10) | 4 points |
| M2 | Frontend opérationnel | J5 (06/10) | Login 4 profils |
| M3 | Infrastructure industrielle | J10 (13/10) | CI/CD + workers |
| M4 | Sprint H2 clôturé | J15 (22/10) | Tag v0.4.0 |

---

## 7. Après H2 — Transition Phase 2

### Étape critique : Conception BDD Phase 2 (5 jours)

| # | Livrable |
|---|---|
| 1 | MCD haut niveau (7 modules, ~75 tables) |
| 2 | Dictionnaire de données v2 |
| 3 | Migrations SQL préparées |
| 4 | Validation encadreur |

### Modules Phase 2

| Ordre | Module | Tables |
|---|---|---|
| 1 | Ventes | ~15 |
| 2 | Achats | ~12 |
| 3 | Stocks | ~10 |
| 4 | CRM | ~8 |
| 5 | Comptabilité SYSCOHADA | ~15 |
| 6 | Trésorerie | ~8 |
| 7 | Projets | ~7 |

---

## 8. Récapitulatif

| Indicateur | Valeur |
|---|---|
| Durée | 15 jours ouvrés |
| Points à solder | 13 |
| Livrables | ~40 fichiers |
| Tests E2E finaux | >= 20 |
| Tag de clôture | v0.4.0-phase1-h2-complete |
| Avancement Phase 1 après H2 | ~98 % |

---

## 9. Checklist de démarrage

- Documentation H1 finalisée et commitée
- Tag v0.3.0-phase1-h1-complete poussé
- Docker pg-ycc healthy
- Docker vault-ycc healthy
- Tests E2E baseline : 14/14 PASS
- Branche main synchronisée avec origin/main
- BACKLOG.md à jour
