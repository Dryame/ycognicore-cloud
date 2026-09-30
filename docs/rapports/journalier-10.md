
<div align="center">

![Logo yCogniCore Cloud](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/assets/logo.png)

# **yCogniCore Cloud**

### Plateforme ERP SaaS multi-tenant

---

## Rapport Journalier n°10

**Sprint H0 — Socle Invariable**

**Auteur :** Yameogo Idrissa
**Date :** 30 septembre 2026
**Version :** 2.0

---

*Document produit dans le cadre du stage à SOCIETE BENJEDDOU TECHNOLOGIE*

</div>

\newpage

---

## Table des matières

1. [Contexte de la journée](#1-contexte-de-la-journée)
2. [Tâches réalisées et leur déroulement](#2-tâches-réalisées-et-leur-déroulement)
3. [Fonctionnalités développées, modifiées, corrigées ou testées](#3-fonctionnalités-développées-modifiées-corrigées-ou-testées)
4. [Modélisation des données et architecture](#4-modélisation-des-données-et-architecture)
5. [Résolution de problèmes détaillée](#5-résolution-de-problèmes-détaillée)
6. [Résultats obtenus](#6-résultats-obtenus)
7. [Bilan et prochaines étapes](#7-bilan-et-prochaines-étapes)

---
<div align="center">

![Logo yCogniCore Cloud](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/assets/logo.png)

# **yCogniCore Cloud**

## Plateforme ERP SaaS multi-tenant

---

### Rapport Journalier n°10

**Sprint H0 — Socle Invariable**

---

**Auteur :** Yameogo Idrissa
**Date :** 30 septembre 2026
**Version :** 2.0

---

*Document confidentiel — Stage SOCIETE BENJEDDOU TECHNOLOGIE*

</div>

\newpage



## 1. Contexte de la journée

### 1.1. Situation d'entrée

À l'issue de la journée du 29 septembre 2026 (Rapport n°09), le socle invariant de la Phase 1 était **produit** mais **non validé**.

| Élément | Statut au 29/09 |
|---|---|
| 13 migrations SQL | Produites |
| Script provisioning Python | Produit |
| Seeds de test | Produits |
| 7 ADR (001 à 007) | Produits |
| BACKLOG (37 points, 5 horizons) | Produit |
| **Sprint H0** | **1/6 points validés (BL-001)** |

Le socle SQL était validé (BL-001) mais les **5 autres points bloquants** du Sprint H0 restaient à traiter pour permettre le démarrage de l'implémentation Spring Boot.

### 1.2. Objectifs de la journée

**Objectif principal :** clôturer les 5 points restants du Sprint H0.

| # | Point | Description |
|---|---|---|
| BL-002 | Décision Spring Boot | Trancher Spring Boot 4 vs 3.5 LTS |
| BL-003 | Décision Angular | Trancher Angular 22 vs 20 LTS |
| BL-004 | Intégration Flyway | Piloter le schéma par Flyway |
| BL-005 | Planification partitions | Automatiser la création des partitions |
| BL-006 | Docker Compose complet | PG + Redis + Vault + MinIO |

**Enjeu stratégique :** le Sprint H0 conditionne l'intégralité du Sprint H1 (Backend socle). Sans la clôture de H0, aucun développement Spring Boot ne peut démarrer.

### 1.3. Contraintes imposées

- Sauvegarde préalable obligatoire de tout l'existant
- Traçabilité totale des décisions (ADR)
- Documentation systématique des problèmes rencontrés
- Preuves visuelles pour chaque étape validée

---

## 2. Tâches réalisées et leur déroulement

La journée s'est organisée en **7 blocs séquentiels**, chacun avec des objectifs mesurables et des livrables précis.

### Vue d'ensemble

| Bloc | Horaire | Objet | Durée |
|---|---|---|---|
| BLOC 0 | 08h30 → 09h00 | Briefing, arborescence, sauvegarde | 30 min |
| BLOC 1 | 09h00 → 10h30 | Reconstruction des 13 migrations | 1h30 |
| BLOC 2 | 10h30 → 11h30 | Décisions technologiques (ADR-008, ADR-009) | 1h |
| BLOC 3 | 11h30 → 12h30 | Intégration Flyway (BL-004) | 1h |
| BLOC 4 | 12h30 → 13h30 | Maintenance partitions (BL-005) | 1h |
| BLOC 5 | 13h30 → 15h00 | Docker Compose complet (BL-006) | 1h30 |
| BLOC 6 | 15h00 → 15h30 | Nettoyage, tags, clôture | 30 min |

---

### Tâche 1 — Briefing et sauvegarde initiale (BLOC 0)

**Objectif :** préparer l'environnement et sécuriser l'existant avant toute manipulation.

**Déroulement :**

1. **Vérification de l'environnement** : Docker actif, conteneur `pg-ycc` en `Up`, PostgreSQL 16.11 accessible, port 5432 exposé.

2. **Vérification de l'arborescence initiale** : `tree db/ -L 3` → 6 fichiers seulement (V1-V3 CP, V1-V3 Tenant).

3. **Création d'une sauvegarde horodatée** : `db.backup-20260930-094319/`.

![Arborescence initiale](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/04-13-migrations.png)

*Figure 1 — Arborescence initiale : 6 fichiers SQL.*

![Sauvegarde et reconstruction](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/04-13-migrations.png)

*Figure 2 — Création de la sauvegarde + reconstruction de l'arborescence.*

**Résultat :** environnement préparé, sauvegarde créée, arborescence propre.

![Création de la sauvegarde horodatée db.backup-20260930-094319/.](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/03-sauvegarde.png)

*Création de la sauvegarde horodatée db.backup-20260930-094319/.*


![Arborescence initiale : 6 fichiers SQL (V1-V3 CP + V1-V3 Tenant).](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/02-arborescence-initiale.png)

*Arborescence initiale : 6 fichiers SQL (V1-V3 CP + V1-V3 Tenant).*


![État des conteneurs Docker au démarrage de la journée.](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/01-docker-ps.png)

*État des conteneurs Docker au démarrage de la journée.*


**Durée effective :** 30 minutes.

![État final Git : historique des commits et tags de la journée.](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/51-etat-final-git.png)

*État final Git : historique des commits et tags de la journée.*


![Commit BL-004 : intégration Flyway + ADRs 008/009/010.](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/49-commit-bl004.png)

*Commit BL-004 : intégration Flyway + ADRs 008/009/010.*


---

### Tâche 2 — Reconstruction des 13 migrations SQL (BLOC 1)

**Objectif :** reconstruire proprement les 13 migrations SQL selon l'Approche A.

**Déroulement :**

1. **Control Plane (6 migrations)** : V1 à V6 (socle, abonnements, quotas IA, transversales, sécurité Superadmin, enrichissements).

2. **Tenant (7 migrations)** : V1 à V7 (socle RBAC, password history, login attempts, extensions, enrichissements, verrouillage).

3. **Vérification par fichier** : comptage des `CREATE TABLE`, `CREATE FUNCTION`, `CREATE TRIGGER`, `CREATE INDEX`.

**Résultat :** 13 fichiers SQL (6 CP + 7 Tenant) + 1 vérificateur.

![Compteurs par migration (CREATE TABLE, FUNCTION, TRIGGER, lignes).](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/05-recap-migrations.png)

*Compteurs par migration (CREATE TABLE, FUNCTION, TRIGGER, lignes).*


![13 migrations finales](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/04-13-migrations.png)

*Figure 3 — Vérification finale : 6 migrations CP + 7 Tenant = 13.*

**Durée effective :** 1 heure 30.

---

### Tâche 3 — Décisions technologiques (BLOC 2)

#### 3.1. ADR-008 — Choix de Spring Boot 4

**Décision :** adoption de **Spring Boot 4.1.1**.

**Justifications :**

1. Version déjà opérationnelle dans le projet
2. Support LTS jusqu'en 2031
3. Compatibilité avec Spring Cloud 2026.0
4. Support d'Hibernate 7 (multi-tenant natif — ADR-006)

#### 3.2. ADR-009 — Choix d'Angular 22 LTS

**Décision :** adoption d'**Angular 22.2.0 LTS**.

**Justifications :**

1. Version déjà opérationnelle (rapport 08-78)
2. Support LTS jusqu'à fin 2027
3. Signals + Standalone Components stables
4. Compilateur Vite (performance accrue)

**Durée effective :** 1 heure.

---

### Tâche 4 — Intégration Flyway (BLOC 3 — BL-004)

**Objectif :** faire piloter le schéma Control Plane par Flyway.

#### 4.1. Ajout des dépendances

Ajout de `flyway-core` et `flyway-database-postgresql` dans `pom.xml`.

![Indentation TAB](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/08-tab-detection.png)

*Figure 4 — Diagnostic : indentation TAB détectée dans le pom.xml.*

![Dépendances pom.xml](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/09-flyway-pom.png)

*Figure 5 — Ajout des dépendances Flyway + vérification visuelle.*

#### 4.2. Validation et compilation

![Validation OK](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/10-validation-compilation.png)

*Figure 6 — XML valide + compilation OK.*

#### 4.3. Configuration application.yml

![application.yml](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/11-application-yml.png)

*Figure 7 — application.yml créé (49 lignes).*

#### 4.4. Problème : Spring Boot 4 sans starter Flyway

![Starters Boot 4](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/16-boot4-starters.png)

*Figure 8 — Diagnostic : aucun starter Flyway n'existe pour Boot 4.*

#### 4.5. Résultat — 6 puis 7 migrations appliquées

![Flyway history](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/19-flyway-history.png)

*Figure 9 — flyway_schema_history : 7 migrations (V1 à V7).*

**Durée effective :** 1 heure.

---

### Tâche 5 — Maintenance automatique des partitions (BLOC 4 — BL-005)

**Objectif :** automatiser la création des partitions mensuelles.

#### 5.1. Création de la migration V7

Table `partition_maintenance_log` avec traçabilité complète.

![V7 créé](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/23-v7-created.png)

*Figure 10 — V7__add_partition_maintenance.sql créé.*

#### 5.2. Succès — 12 partitions créées

![Endpoint success](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/30-endpoint-success.png)

*Figure 11 — POST /api/admin/partitions/run : **nbPartitionsCreees: 12, nbErreurs: 0**.*

#### 5.3. Vérification en base

![Partitions demo001](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/31-partitions-demo001.png)

*Figure 12 — demo001 : 30 objets (3 audit_log + 3 login_attempts + index hérités).*

#### 5.4. Journal de traçabilité

![Journal CP](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/33-journal-cp.png)

*Figure 13 — partition_maintenance_log : SUCCES=12, ECHEC=12.*

**Durée effective :** 1 heure.

---

### Tâche 6 — Docker Compose complet (BLOC 5 — BL-006)

**Objectif :** provisionner 4 services sans perte de données.

#### 6.1. Analyse des volumes et ports

![Volumes Docker](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/35-volumes.png)

*Figure 14 — Volume `pg_ycc_data` (85 Mo) identifié pour réutilisation.*

#### 6.2. Fichiers d'infrastructure + validation

![Validation YAML](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/38-validation-yaml.png)

*Figure 15 — YAML docker-compose validé.*

#### 6.3. Démarrage de la stack

![Docker compose up](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/41-docker-up.png)

*Figure 16 — Démarrage : 4 services, 1 réseau, 3 volumes.*

#### 6.4. Récapitulatif infrastructure

![Récapitulatif BL-006](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/48-recap-bl006.png)

*Figure 17 — Les 4 services opérationnels + Vault + MinIO + Redis + PostgreSQL.*

**Durée effective :** 1 heure 30.

---

### Tâche 7 — Nettoyage et clôture (BLOC 6)

**Actions :**

1. Exclusion des `.backup` du dépôt Git
2. Commit final
3. Tag `v0.2.0-phase1-h0-complete`

**Commits de la journée :**

| Commit | Description |
|---|---|
| `33170d5` | BL-004 — Flyway + ADRs 008/009/010 |
| `cd6c4fb` | Chore : exclusion `.backup` |
| `2b1b9fc` | BL-005 — Maintenance partitions |
| `b91c7d5` | BL-006 — Docker Compose complet |
| `0f37c82` | Chore : nettoyage + correction vault/init.sh |

**Durée effective :** 30 minutes.

---

## 3. Fonctionnalités développées, modifiées, corrigées ou testées

### 3.1. Fonctionnalités développées (nouvelles)

#### F-01 — Maintenance automatique des partitions

**Description :** job planifié qui crée automatiquement les partitions mensuelles `audit_log` et `login_attempts` sur toutes les bases tenant.

**Composants créés :**
- Migration V7 : table `partition_maintenance_log`
- Entité `PartitionMaintenanceLog.java`
- Repository `PartitionMaintenanceLogRepository.java`
- Service `PartitionMaintenanceService.java` (~150 lignes)
- Scheduler `PartitionMaintenanceScheduler.java` (cron mensuel)
- Controller `PartitionMaintenanceController.java` (2 endpoints)

#### F-02 — Configuration Flyway explicite

**Composants créés :** `FlywayConfig.java` (~60 lignes).

#### F-03 — Configuration Spring Security minimale

**Composants créés :** `SecurityConfig.java` (~40 lignes).

#### F-04 — Infrastructure Docker complète

**Composants créés :** `infra/docker-compose.yml`, `infra/Makefile`, `infra/vault/init.sh`, `infra/minio/init.sh`.

#### F-05 — Activation du scheduling Spring

**Composants créés :** `BackendApplication.java` modifié (@EnableScheduling).

### 3.2. Fonctionnalités modifiées

| Fichier | Modification |
|---|---|
| `backend/pom.xml` | Ajout `flyway-core`, `flyway-database-postgresql` |
| `backend/src/main/resources/application.yml` | Créé |
| `backend/src/main/java/.../BackendApplication.java` | Ajout `@EnableScheduling` |
| `infra/vault/init.sh` | `docker exec` au lieu de `vault` direct |
| `infra/minio/init.sh` | boto3 au lieu de `mc` |
| `tenant_databases` | db_user = postgres |

### 3.3. Fonctionnalités testées

| Test | Résultat |
|---|---|
| Migrations Control Plane | 9/9 ✅ |
| Migrations Tenant | 13/13 ✅ |
| Flyway contrôle schéma | 7/7 ✅ |
| Maintenance partitions | 12/12 succès ✅ |
| Docker healthchecks | 4/4 healthy ✅ |
| Vault transit | `ycc-mfa-key` ✅ |
| MinIO buckets | 3/3 ✅ |
| Redis PING | PONG ✅ |
| PostgreSQL préservation | 3 bases intactes ✅ |

![Test 12 Tenant : NOTICE OK — password_history append-only.](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/61-test12-tenant.png)

*Test 12 Tenant : NOTICE OK — password_history append-only.*


![Test 10 Tenant : NOTICE OK — VERROUILLE après 5 échecs.](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/60-test10-tenant.png)

*Test 10 Tenant : NOTICE OK — VERROUILLE après 5 échecs.*


![Test 6 CP : 6 fonctions critiques créées.](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/55-test6-cp.png)

*Test 6 CP : 6 fonctions critiques créées.*


![Test 5 CP : 6 triggers d'immuabilité actifs.](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/54-test5-cp.png)

*Test 5 CP : 6 triggers d'immuabilité actifs.*


![Test 4 CP : 11 colonnes critiques vérifiées.](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/53-test4-cp.png)

*Test 4 CP : 11 colonnes critiques vérifiées.*


![Test 3 CP : 0 table manquante (toutes présentes).](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/52-test3-cp.png)

*Test 3 CP : 0 table manquante (toutes présentes).*


**Tests Control Plane :**

**Tests Tenant :**

---

## 4. Modélisation des données et architecture

### 4.1. Schéma Control Plane (21 tables + 2 partitions)

| Version | Description | Tables |
|---|---|---|
| V1 | Socle | 5 |
| V2 | Abonnements | 2 |
| V3 | Quotas IA | 1 |
| V4 | Transversales | 9 |
| V5 | Sécurité Superadmin | 4 + 2 partitions |
| V6 | Enrichissements | (ALTER) |
| V7 | Maintenance partitions | 1 |
| **Total** | | **21 + 2** |

### 4.2. Schéma Tenant (14 tables + 8 partitions)

| Version | Description | Tables |
|---|---|---|
| V1 | Socle RBAC + audit | 8 + 2 partitions |
| V2 | Password history | 1 |
| V3 | Login attempts | 1 + 3 partitions |
| V4 | Extensions | 4 |
| V5 | Enrichissements | (ALTER) |
| V6 | Enrichissements | (ALTER) |
| V7 | Verrouillage | (TRIGGER) |
| **Total** | | **14 + 8** |

### 4.3. Architecture Docker

4 services orchestrés : PostgreSQL 16, Redis 7-alpine, Vault 1.17.6, MinIO (pgsty).

### 4.4. Architecture Spring Boot

8 composants Java (Application, Config, Controller, Entity, Repository, Scheduler, Service, Security).

---

## 5. Résolution de problèmes détaillée

**11 problèmes rencontrés et résolus au cours de la journée.**

### Problème 1 — Indentation TAB dans le pom.xml

**Solution :** regex robuste `([ \t]*)</dependencies>`.

### Problème 2 — Flyway ne s'exécute pas (Boot 4)

**Solution (ADR-010) :** bean `Flyway` explicite.

### Problème 3 — Conflit Flyway / migrations manuelles

**Solution :** drop + recreate de la base

![Structure partition_maintenance_log](/home/idrissa_yameogo/projets/ycognicore-cloud/docs/rapports/captures/10/24-partition-table.png)

*Figure — Structure de la table partition_maintenance_log.*
.

### Problème 4 — Endpoint 401 Unauthorized

**Solution :** `SecurityConfig.java`.

### Problème 5 — 0 tenants détectés

**Solution :** INSERT dans `tenant_databases`.

### Problème 6 — 12 erreurs password

**Solution :** `ALTER ROLE ycc_tenant_app WITH PASSWORD 'postgres'`.

### Problème 7 — DDL CREATE interdit

**Solution (ADR-011) :** passage à `db_user = 'postgres'`.

### Problème 8 — Image MinIO retirée

**Solution (ADR-013) :** `pgsty/minio`.

### Problème 9 — Healthcheck Vault IPv6

**Solution (ADR-012) :** `127.0.0.1`.

### Problème 10 — boto3 absent

**Solution :** conteneur `python:3.11-alpine` éphémère.

### Problème 11 — mc non téléchargeable

**Solution :** boto3.

---

## 6. Résultats obtenus

### 6.1. Livrables produits

| Livrable | Localisation | Statut |
|---|---|---|
| 13 migrations SQL | `db/migration/` | ✅ |
| Script provisioning Python | `db/scripts/provisioning_tenant.py` | ✅ |
| 3 fichiers de seeds | `db/seeds/` | ✅ |
| 6 ADRs (008-013) | `docs/adr/` | ✅ |
| 8 fichiers Java | `backend/src/main/java/` | ✅ |
| 4 fichiers infra/ | `infra/` | ✅ |
| `application.yml` | `backend/src/main/resources/` | ✅ |
| 3 dumps SQL | `database/dumps/` | ✅ |

### 6.2. Statistiques de la journée

| Indicateur | Valeur |
|---|---|
| Commits Git | 5 |
| Tags créés | 1 |
| Services Docker opérationnels | 4 |
| Bases PostgreSQL | 3 |
| Tables logiques | 35 |
| Migrations Flyway appliquées | 7 |
| Partitions créées automatiquement | 12 |
| Tests réussis | 22 |

---

## 7. Bilan et prochaines étapes

### 7.1. Sprint H0 — Clôturé (6/6)

| # | Point | Statut |
|---|---|---|
| BL-001 | Tests migrations | ✅ |
| BL-002 | Décision Spring Boot | ✅ |
| BL-003 | Décision Angular | ✅ |
| BL-004 | Flyway intégré | ✅ |
| BL-005 | Partitions automatiques | ✅ |
| BL-006 | Docker Compose complet | ✅ |

### 7.2. Avancement global Phase 1

| Chantier | Avant | Après |
|---|---|---|
| Scripts SQL | 95 % | **100 %** |
| Infrastructure Docker | 0 % | **100 %** |
| Flyway | 0 % | **100 %** |
| Backend Spring Boot | 5 % | **30 %** |
| **Phase 1 globale** | **~72 %** | **~82 %** |

### 7.3. Reste à faire

**Sprint H1 — Backend socle (8 points) :**

| # | Point | Description |
|---|---|---|
| BL-007 | Entités JPA Control Plane | 21 tables |
| BL-008 | Entités JPA Tenant | 14 tables |
| BL-009 | Repositories Spring Data | 35 repositories |
| BL-010 | Multi-tenant routing | ADR-006 |
| BL-011 | Auth Dispatcher + JWT | NFR-SEC-06/11 |
| BL-012 | MFA service | ADR-002 + ADR-005 |
| BL-013 | RBAC interceptor | 6 × 16 |
| BL-014 | Audit Trail AOP | NFR-SEC-16 |

### 7.4. Conformité aux directives du 29/09/2026

| Directive | Respectée |
|---|---|
| Présentation soignée | ✅ |
| Preuves visuelles (54 figures) | ✅ |
| Travaux et Déroulement | ✅ |
| Fonctionnalités développées | ✅ |
| Résolution de Problèmes (11 problèmes) | ✅ |
| Résultats Obtenus & Avancement | ✅ |
| Reste à Faire | ✅ |
| Format éditable (Markdown) | ✅ |

---

**Fin du rapport journalier n°10**

**Auteur :** Yameogo Idrissa
**Date :** 30 septembre 2026
**Bilan :** Sprint H0 clôturé (6/6), Phase 1 à ~82 %
