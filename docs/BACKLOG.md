# BACKLOG — yCogniCore Cloud

**Registre de la dette technique maîtrisée**
Plateforme ERP SaaS · 37 points · Sprint H0 et H1 clôturés

---

## Légende

| Champ | Valeurs possibles |
|---|---|
| **Horizon** | H0 (bloquant), H1 (Phase 1.1), H2 (Phase 1.2), H3 (Phase 2), H4 (Phase 3) |
| **Risque** | Critique · Majeur · Modéré · Faible · Négligeable |
| **Trigger** | Événement mesurable déclenchant la reprise |
| **Statut** | Terminé · En cours · À faire · Bloqué |

---

## Vue d'ensemble

| Horizon | Nombre de points | Statut global |
|---|---|---|
| H0 | 6 | **Terminé (6/6)** — 30/09/2026 |
| H1 | 8 | **Terminé (8/8)** — 01/10/2026 |
| H2 | 8 | À faire |
| H3 | 7 | À faire |
| H4 | 8 | À faire |
| **Total** | **37** | **14 terminés · 23 à faire** |

Progression globale : **14 / 37 points (38 %)**
Avancement global Phase 1 : **~92 %**
Prochain horizon : **H2 (Consolidation)**

---

## H0 — Bloquant Phase 1 (clôturé le 30/09/2026)

| ID | Point | Trigger / Décision | Risque | Statut |
|---|---|---|---|---|
| BL-001 | Exécuter les tests de migration CP + Tenant | Immédiat | Critique | **Terminé** |
| BL-002 | Décision Spring Boot 4 vs 3.5 LTS | Spring Boot 4.1.1 | — | **Terminé** |
| BL-003 | Décision Angular 22 vs 20 LTS | Angular 22.2.0 LTS | — | **Terminé** |
| BL-004 | Intégration Flyway côté Spring Boot | Immédiat | Critique | **Terminé** |
| BL-005 | Planifier @Scheduled pour partitions | Immédiat | Critique | **Terminé** |
| BL-006 | Docker Compose complet (PG+Redis+Vault+MinIO) | Immédiat | Critique | **Terminé** |

---

## H1 — Phase 1.1 Backend socle (clôturé le 01/10/2026)

**Cible** : 01/10/2026 → 25/10/2026
**Statut** : **8/8 points clôturés**
**Tag Git** : `v0.3.0-phase1-h1-complete`

| ID | Point | Trigger | Risque | Statut |
|---|---|---|---|---|
| BL-007 | Entités JPA Control Plane (21 tables) | Flyway intégré | Majeur | **Terminé** |
| BL-008 | Entités JPA Tenant (14 tables) | Flyway intégré | Majeur | **Terminé** |
| BL-009 | Repositories Spring Data (35) | BL-007 et BL-008 | Majeur | **Terminé** |
| BL-010 | Multi-tenant routing (ADR-006) | BL-007 | Critique | **Terminé** |
| BL-011 | Auth Dispatcher + JWT | BL-010 | Critique | **Terminé** |
| BL-012 | MFA service (Vault + TOTP) | BL-011 | Majeur | **Terminé** |
| BL-013 | RBAC interceptor (6 × 16) | BL-011 | Majeur | **Terminé** |
| BL-014 | Audit Trail AOP | BL-013 | Majeur | **Terminé** |

### Livrables BL-007 → BL-014

- **116 fichiers** créés / modifiés (~5 300 lignes)
- **22 entités CP** + 2 enums + 3 IdClass
- **14 entités Tenant** + 4 IdClass
- **35 repositories** Spring Data (21 CP + 14 Tenant)
- **2 EntityManagerFactory** (CP + Tenant multi-tenant)
- **Endpoints REST** : auth (login/refresh/me), MFA (setup/verify), RBAC test, audit test, POC tenant
- **1 migration SQL** : `V8__add_tenant_mfa.sql`
- **4 dépendances** : jjwt 0.12.6, googleauth 1.5.0, aspectjweaver 1.9.22, spring-boot-starter-aop

### Validation

- **14/14 tests E2E** PASS (POC, Auth, MFA, RBAC, Audit)
- **Isolation multi-tenant** : 0 fuite DEMO001 ↔ DEMO002
- **Flyway CP** : V1-V7 toutes `success = t`
- **Tag Git** : `v0.3.0-phase1-h1-complete` (poussé sur origin/main)

---

## H2 — Phase 1.2 Consolidation (8 points)

**Cible** : 26/10/2026 → 30/11/2026
**Statut** : **À faire**

| ID | Point | Trigger | Risque | Owner | Statut |
|---|---|---|---|---|---|
| BL-015 | Frontend Angular — Core module | BL-011 | Majeur | Lead Frontend | À faire |
| BL-016 | Page login Auth Dispatcher (frontend) | BL-015 | Majeur | Lead Frontend | À faire |
| BL-017 | CI/CD pipeline | 2ᵉ dev OU 1ʳᵉ mise en prod | Majeur | DevOps | À faire |
| BL-018 | Workers notifications multicanal | 1ᵉʳ module émettant des notifs | Modéré | Lead Backend | À faire |
| BL-019 | Worker jobs_async | BL-005 | Modéré | Lead Backend | À faire |
| BL-020 | Tests d'intrusion cross-tenant | Avant 1ʳᵉ mise en prod | Majeur | Backend + Auditeur | À faire |
| BL-021 | Documentation technique (runbooks) | 1ᵉʳ déploiement prod | Modéré | Lead Backend | À faire |
| BL-022 | Matrice traçabilité NFR → Test → Code | Fin H1 | Modéré | Lead Qualité | À faire |

### Points reportés de H1 vers H2

| ID | Point | Cause | Action |
|---|---|---|---|
| **BL-013.1** | RBAC réel (vérification en base) | Mode log-only en BL-013 | Implémenter la vérification `role_permissions` via repository tenant |
| **BL-010.1** | Refactor `PartitionMaintenanceService` | Utilise `DriverManager` direct | Migrer vers `MultiTenantConnectionProvider` |
| **BL-011.1** | Endpoint `/api/auth/refresh` | Retourne 501 | Implémenter le refresh complet |
| **BL-011.2** | Distinction ADMIN vs INTERNE | Rôle non extrait du JWT | Ajouter les rôles dans le claim JWT |
| **BL-015.1** | Mapping JSONB (JsonNode) | Actuellement String | Migrer les entités tenant vers `JsonNode` |

---

## H3 — Phase 2 Modules métier (7 points)

**Statut** : À faire

| ID | Point | Trigger | Risque | Owner |
|---|---|---|---|---|
| BL-023 | Générateur PDF + QR Code | Sprint « Ventes / Factures » | Faible | Lead Backend |
| BL-024 | OCR factures fournisseurs | Sprint « Comptabilité » | Faible | Lead IA |
| BL-025 | Rapprochement bancaire automatique | Sprint « Trésorerie » | Faible | Lead Backend |
| BL-026 | Séparation des tâches (SoD) | Sprint « RBAC avancé » | Modéré | Lead Backend |
| BL-027 | Multi-langues complet | Sprint « UX / i18n » | Faible | Lead Frontend |
| BL-028 | Mode hors-ligne (scan QR) | Sprint « Stocks » | Faible | Lead Frontend |
| BL-029 | Politique de retry webhook avancée | Intégration PayDunya/Ligdicash prod | Modéré | Lead Backend |

---

## H4 — Phase 3 Industrialisation (8 points)

**Statut** : À faire

| ID | Point | Trigger | Risque | Owner |
|---|---|---|---|---|
| BL-030 | Kubernetes (production) | 50ᵉ tenant actif | Négligeable | DevOps |
| BL-031 | Feature flags | 100ᵉ tenant actif | Négligeable | DevOps |
| BL-032 | Blue/Green deployment | 100ᵉ tenant actif | Négligeable | DevOps |
| BL-033 | HSM dédié pour chiffrement | 1000ᵉ tenant actif | Négligeable | Sécurité |
| BL-034 | Event Sourcing complet | Besoin reconstruction temporelle | Négligeable | Lead Backend |
| BL-035 | Multi-région | 10 000ᵉ tenant actif | Négligeable | DevOps |
| BL-036 | Recueil NFR v2 (12 lacunes) | Q1 2027 | Modéré | Lead Qualité |
| BL-037 | Gouvernance NFR (versioning, deprecation) | Q1 2027 | Modéré | Lead Qualité |

---

## Statistiques

### Par horizon

| Horizon | Points | Terminés | À faire | Taux |
|---|---|---|---|---|
| H0 | 6 | 6 | 0 | 100 % |
| H1 | 8 | 8 | 0 | 100 % |
| H2 | 8 | 0 | 8 | 0 % |
| H3 | 7 | 0 | 7 | 0 % |
| H4 | 8 | 0 | 8 | 0 % |
| **Total** | **37** | **14** | **23** | **38 %** |

### Par risque

| Risque | Points | Terminés | Ouverts |
|---|---|---|---|
| Critique | 6 | 6 | 0 |
| Majeur | 10 | 8 | 2 |
| Modéré | 8 | 0 | 8 |
| Faible | 5 | 0 | 5 |
| Négligeable | 6 | 0 | 6 |
| Non évalué (décisions) | 2 | 2 | 0 |
| **Total** | **37** | **16** | **21** |

---

## Historique des modifications

| Date | Modification | Auteur |
|---|---|---|
| 29/09/2026 | Création du BACKLOG (37 points) | Yameogo Idrissa |
| 30/09/2026 | H0 clôturé (6/6) | Yameogo Idrissa |
| **01/10/2026** | **H1 clôturé (8/8) · 5 points reportés en H2** | **Yameogo Idrissa** |

---


---
title: "BACKLOG — yCogniCore Cloud"
version: "1.7"
last_updated: "2026-10-09"
author: "Yameogo Idrissa"
status: "ACTIF"
---

# BACKLOG — yCogniCore Cloud

**Registre de la dette technique maîtrisée**
**Plateforme ERP SaaS · Phase 1 clôturée · Phase 2 en cours**
**Dernière mise à jour** : 09 octobre 2026

---

## Vue d'ensemble

- **Horizon H0** — Socle invariant : 6/6 points — Clôturé le 30/09/2026
- **Horizon H1** — Backend socle : 8/8 points — Clôturé le 01/10/2026
- **Horizon H2** — Consolidation : 13/13 points — Clôturé le 05/10/2026
- **Horizon PREP** — Préparation inter-phase : 2/2 points — Clôturé le 06/10/2026
- **Horizon H3** — Conception BDD métier : 3/10 points — En cours
- **Horizon H4** — Industrialisation : 0/13 points — À venir
- **Total** : 32/51 points (63 %)

---

## Légende

### Horizons

- **H0** — Bloquant Phase 1 (Sprint Socle Invariable)
- **H1** — Backend socle (Sprint Consolidation 1)
- **H2** — Consolidation (Sprint 2)
- **PREP** — Préparation inter-phase (APM + A11y)
- **H3** — Conception BDD métier (7 blocs)
- **H4** — Industrialisation (production)

### Risques

- **Critique** — Bloque la production
- **Majeur** — Impact fort
- **Modéré** — Impact moyen
- **Faible** — Impact limité
- **Négligeable** — Peut attendre

### Statuts

- **Terminé** — Livré et validé
- **En cours** — Travail actif
- **À faire** — Non démarré
- **Bloqué** — Dépendance externe

---

# HORIZON H0 — Bloquant Phase 1 (clôturé 30/09/2026)

## BL-001 — Tests migrations CP + Tenant

- Description : Exécution de `test_migrations.sql` et `test_migrations_tenant.sql`
- Risque : Critique
- Référence : ADR-007, Rapport 06-78
- Critère de clôture : 22 tests réussis
- Statut : Terminé le 29/09/2026

## BL-002 — Décision Spring Boot

- Description : Trancher entre Spring Boot 4.0 et 3.5 LTS
- Référence : ADR-008
- Décision : Spring Boot 4.1.1 (support LTS jusqu'en 2031)
- Statut : Terminé le 30/09/2026

## BL-003 — Décision Angular

- Description : Trancher entre Angular 22 et 20 LTS
- Référence : ADR-009
- Décision : Angular 22.2.0 LTS (Signals + Standalone)
- Statut : Terminé le 30/09/2026

## BL-004 — Intégration Flyway

- Description : Ajout dépendances + configuration + `FlywayConfig.java`
- Référence : ADR-010
- Critère de clôture : 7 migrations appliquées
- Statut : Terminé le 30/09/2026

## BL-005 — Planifier maintenance partitions

- Description : Service + Scheduler + Controller REST
- Référence : ADR-011
- Critère de clôture : 12 partitions créées automatiquement
- Statut : Terminé le 30/09/2026

## BL-006 — Docker Compose complet

- Description : 4 services orchestrés (PostgreSQL, Redis, Vault, MinIO)
- Référence : ADR-012, ADR-013
- Critère de clôture : 4 services healthy
- Statut : Terminé le 30/09/2026

**Tag Git** : `v0.2.0-phase1-h0-complete`

---

# HORIZON H1 — Backend socle (clôturé 01/10/2026)

## BL-007 — Entités JPA Control Plane

- Description : 22 entités JPA + 2 enums + 3 IdClass
- Risque : Majeur
- Statut : Terminé le 01/10/2026

## BL-008 — Entités JPA Tenant

- Description : 14 entités JPA + 4 IdClass
- Risque : Majeur
- Statut : Terminé le 01/10/2026

## BL-009 — Repositories Spring Data

- Description : 35 interfaces JpaRepository
- Risque : Majeur
- Statut : Terminé le 01/10/2026

## BL-010 — Multi-tenant routing

- Description : Hibernate 7 natif (MT Provider + 2 EMF + TenantContext)
- Référence : ADR-006
- Statut : Terminé le 01/10/2026

## BL-011 — Auth Dispatcher + JWT

- Description : Login + MFA + JWT HS512
- Statut : Terminé le 01/10/2026

## BL-012 — MFA service

- Description : Vault Transit AES-256-GCM + TOTP
- Référence : ADR-002, ADR-005
- Statut : Terminé le 01/10/2026

## BL-013 — RBAC interceptor

- Description : Intercepteur Spring Security sur 6×16
- Statut : Terminé le 01/10/2026

## BL-014 — Audit Trail AOP

- Description : Intercepteur AOP `@Auditable` → `audit_log`
- Statut : Terminé le 01/10/2026

**Tag Git** : `v0.3.0-phase1-h1-complete`

---

# HORIZON H2 — Consolidation (clôturé 05/10/2026)

## BL-013.1 — RBAC réel

- Description : Vérification SQL effective du RBAC
- Statut : Terminé le 02/10/2026

## BL-010.1 — Refactor PartitionMaintenanceService

- Description : Utilisation du MT Provider au lieu de DriverManager
- Statut : Terminé le 02/10/2026

## BL-011.1 — Endpoint /api/auth/refresh

- Description : Renouvellement JWT complet
- Statut : Terminé le 02/10/2026

## BL-011.2 — Distinction des profils

- Description : Distinction ADMIN / INTERNE / EXTERNE
- Statut : Terminé le 02/10/2026

## BL-015.1 — Mapping JSONB → JsonNode

- Description : Migration de 13 entités
- Référence : ADR-015
- Statut : Terminé le 02/10/2026

## BL-015 — Frontend Angular Core

- Description : Structure Angular + AuthService + Guards + Layouts
- Référence : ADR-016
- Statut : Terminé le 03/10/2026

## BL-016 — Page login

- Description : Page login Auth Dispatcher (frontend)
- Référence : ADR-017
- Statut : Terminé le 03/10/2026

## BL-017 — CI/CD pipeline

- Description : GitHub Actions (4 jobs)
- Référence : ADR-018
- Statut : Terminé le 03/10/2026

## BL-018 — Workers notifications multicanal

- Description : Email / SMS / WhatsApp / Telegram / Push
- Référence : ADR-019
- Statut : Terminé le 04/10/2026

## BL-019 — Worker jobs_async

- Description : Consommateur de la file avec retry exponentiel
- Référence : ADR-021, ADR-022
- Statut : Terminé le 04/10/2026

## BL-020 — Tests d'intrusion

- Description : 6 scénarios cross-tenant
- Critère de clôture : 6/6 PASS
- Statut : Terminé le 05/10/2026

## BL-021 — Documentation technique (runbooks)

- Description : 5 runbooks opérationnels
- Statut : Terminé le 05/10/2026

## BL-022 — Matrice traçabilité NFR

- Description : Tableau NFR → Test → Code
- Statut : Terminé le 05/10/2026

**Tag Git** : `v0.4.0-phase1-h2-complete`

---

# HORIZON PREP — Préparation inter-phase (clôturé 06/10/2026)

## PREP-01 — Instrumentation APM

- Description : Micrometer + Prometheus + Grafana
- Référence : NFR-MON-01, NFR-PERF-01, NFR-PERF-02
- Critère de clôture : ~590 métriques exposées, target Prometheus UP
- Statut : Terminé le 06/10/2026

## PREP-02 — Accessibilité A11y

- Description : Audit WCAG 2.1 AA sur LoginComponent + MainLayout
- Référence : NFR-UX-05
- Critère de clôture : 0 violation critique, audit pa11y validé
- Statut : Terminé le 06/10/2026

**Tags Git** :
- `v0.4.1-phase1-apm-complete`
- `v0.4.2-phase1-a11y-complete`
- `v0.4.3-phase1-prep-complete`

---

# HORIZON H3 — Conception BDD métier (en cours)

## BL-100 — Bloc 1.1 MCD Haut Niveau

- Description : Cadrage architectural de la Phase 2
- Référence : ADR-023, ADR-024, ADR-025, ADR-026, ADR-027
- Livrables :
  - Diagramme global des 7 modules
  - Matrice de dépendances (14 relations)
  - 10 conventions transversales
  - 27 types ENUM
  - Socle SQL V8
- Statut : Terminé le 06/10/2026
- Tag Git : `v0.5.0-phase2-bloc1.1`

## BL-101 — Bloc 1.2 Module CRM

- Description : Conception et implémentation du module CRM
- Livrables :
  - MCD global (8 tables, 14 relations)
  - Diagramme d'état piste et opportunité
  - Dictionnaire de données complet
  - Règles métier
  - Diagramme de séquence
  - Plan de tests (42 tests)
  - Migration SQL V9
  - Script de tests automatisés
- Critère de clôture : 42/42 tests passent
- Statut : Terminé le 07/10/2026
- Tags Git :
  - `v0.5.2-phase2-socle-fix`
  - `v0.5.3-phase2-bloc1.2`
  - `v0.5.4-phase2-bloc1.2-tests`

## BL-102 — Bloc 1.3 Module Ventes ✅ TERMINÉ

- Description : Conception et implémentation du module Ventes
- Dépendance : BL-101 (CRM fournit le référentiel `clients`)
- Livrables :
  - Analyse métier (46 RG, SSOT)
  - MCD (12 entités, 19 relations)
  - MLD (187 colonnes documentées, 3NF)
  - MPD (typage strict, 32 index, concurrence, sécurité)
  - Diagrammes d'état (6) et séquences (4)
  - Plan de 63 tests
  - Migration SQL V10
  - Script de tests automatisés (63/63 PASS)
  - Correctif E11 (collision numérotation BON_COMMANDE/AVOIR)
  - Patch `provisioning_tenant.py` (lecture dynamique V1→V10)
- Critère de clôture : 63/63 tests passent ✅
- Statut : **Terminé le 08/10/2026**
- Tags Git :
  - `v0.6.0-phase2-bloc1.3-preparation` (V10 + patch provisioning)
  - `v0.6.2-phase2-bloc1.3-tests` (63 tests)
  - `v0.6.1-phase2-bloc1.3-ventes` (documentation — à créer)
- Notes :
  - 12 tables créées sur `ycc_tenant_demo001`
  - 43 FK vérifiées individuellement (19 métier + 24 techniques)
  - 12 triggers actifs (6 audit_temporel + 6 no_hard_delete)
  - ENUM `type_facture` créé (NORMALE, ACOMPTE, SOLDE)
  - 2 séquences ajoutées (CLIENT, PAIEMENT_CLIENT)

## BL-103 — Bloc 1.4 Consolidation J1

- Description : Consolidation J1 — MCD consolidé Ventes + CRM
- Dépendance : BL-102
- Livrables attendus :
  - Vérification de cohérence inter-modules (CRM + Ventes)
  - Vérification des FK inter-tables
  - Matrice de traçabilité consolidée
  - Documentation consolidée
- Statut : **PROCHAIN BLOC**

## BL-104 — Bloc 2.1 Module Achats

- Description : Conception et implémentation du module Achats
- Dépendance : BL-103 (consolidation J1)
- Livrables attendus :
  - MCD Achats (~10 tables)
  - Migration SQL V11
  - 3-Way Matching (Facture → Commande → Réception)
- Statut : À faire

## BL-105 — Bloc 2.2 Module Stocks

- Description : Conception et implémentation du module Stocks
- Livrables attendus :
  - MCD Stocks (~15 tables)
  - Migration SQL V12
  - Multi-dépôts, lots, séries
  - FK ajoutées depuis Ventes (`article_id`)
- Statut : À faire

## BL-106 — Bloc 3.1 Module Comptabilité

- Description : Conception et implémentation du module Comptabilité
- Référence : SYSCOHADA révisé, DGI BF
- Livrables attendus :
  - MCD Comptabilité (~15 tables)
  - Migration SQL V13
  - Écritures automatiques depuis Ventes et Achats
- Statut : À faire

## BL-107 — Bloc 3.2 Module Trésorerie

- Description : Conception et implémentation du module Trésorerie
- Livrables attendus :
  - MCD Trésorerie (~8 tables)
  - Migration SQL V14
  - Encaissements / décaissements
- Statut : À faire

## BL-108 — Bloc 3.3 Module Projets

- Description : Conception et implémentation du module Projets
- Livrables attendus :
  - MCD Projets (~7 tables)
  - Migration SQL V15
  - FK ajoutée depuis Ventes (`projet_id`)
- Statut : À faire

## BL-109 — Bloc 3.4 Consolidation finale Phase 2

- Description : Validation, documentation et livraison
- Livrables attendus :
  - Dictionnaire de données v2 consolidé
  - MCD complet des 7 modules
  - Rapport de conception
  - Validation encadreur
- Statut : À faire

## BL-209 — Endpoints health/ready/live exposés

- Description : Exposer les endpoints Spring Boot Actuator nécessaires aux sondes externes (liveness, readiness, health applicative) et les documenter
- Horizon : H3 (Sprint Modules métier)
- Risque : Majeur
- Dépendance : Backend Spring Boot en place (BL-007 à BL-014)
- Référence : ADR-008 (Spring Boot 4), incident Prometheus `exit 127` du 09/10/2026
- Trigger : Démarrage du Sprint H3

### Livrables

**1. Endpoints Spring Boot Actuator à exposer**

| Endpoint | Rôle | Réponse attendue |
|---|---|---|
| `GET /actuator/health/liveness` | Le processus JVM est-il vivant ? | `{"status":"UP"}` |
| `GET /actuator/health/readiness` | Le service est-il prêt à recevoir du trafic ? | `{"status":"UP"}` |
| `GET /actuator/health` | État global (DB, Vault, MinIO, Redis) | `{"status":"UP","components":{...}}` |
| `GET /actuator/info` | Version, commit Git, date de build | `{"version":"...","git.commit":"..."}` |
| `GET /actuator/prometheus` | Métriques Prometheus | Format texte Prometheus |
| `GET /health/db` (custom) | Sonde applicative DB | `{"db":"UP","latencyMs":12}` |
| `GET /health/vault` (custom) | Sonde applicative Vault | `{"vault":"UP","transitKey":"ycc-mfa-key"}` |
| `GET /health/minio` (custom) | Sonde applicative MinIO | `{"minio":"UP","buckets":3}` |

**2. Configuration `application.yml`**

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
  endpoint:
    health:
      probes:
        enabled: true
      show-details: always
      show-components: always
  health:
    db:
      enabled: true
    diskspace:
      enabled: true
    redis:
      enabled: true
    livenessstate:
      enabled: true
    readinessstate:
      enabled: true


## Voir aussi

- `docs/adr/README.md` — Index des ADR
- `docs/adr/ADR-006.md` — Routage multi-tenant (Accepté)
- `docs/rapports/` — Rapports journaliers
