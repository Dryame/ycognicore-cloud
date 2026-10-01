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

## Voir aussi

- `docs/adr/README.md` — Index des ADR
- `docs/adr/ADR-006.md` — Routage multi-tenant (Accepté)
- `docs/rapports/` — Rapports journaliers
