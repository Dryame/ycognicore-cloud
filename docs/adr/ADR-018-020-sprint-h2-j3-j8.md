# ADR du 03/10/2026 — Sprint H2 (J3 à J8)

Trois décisions structurantes formalisées ce jour.

---

## ADR-018 — Pipeline CI/CD avec GitHub Actions

Statut : Accepté
Date : 03/10/2026
Domaine : Infrastructure / DevOps
Références : BL-017, NFR-MAINT-04, NFR-OPS-01

### Contexte

Le projet nécessite une automatisation du build et des tests pour :
- Détecter les régressions le plus tôt possible
- Assurer la qualité à chaque push sur main
- Préparer la mise en production (CI/CD complet)
- Documenter l'état du projet via badges

Trois plateformes étaient envisageables :
1. GitHub Actions (intégré au repo)
2. GitLab CI (nécessite un miroir GitLab)
3. Jenkins (nécessite un serveur dédié)

### Décision

Adoption de GitHub Actions avec un workflow unique de 4 jobs :
- backend : JDK 21 + Maven + build + tests
- frontend : Node 22 + Angular build production
- quality : vérification structure projet
- summary : statut global

Déclenchement :
- push sur main/develop
- pull_request vers main/develop
- workflow_dispatch (manuel)

### Conséquences

Positives :
- Intégration native au repo GitHub
- Gratuit pour les repos publics (2000 min/mois pour privé)
- Cache Maven et npm automatique
- Artifacts téléchargeables (JAR + dist)
- Badges intégrables dans le README

Négatives :
- Dépendance à GitHub (si GitHub tombe, pipeline indisponible)
- 2-3 min par run (mitigé par le cache pour les runs suivants)
- Configuration YAML à maintenir

Neutres :
- En production, on pourra ajouter des jobs de déploiement (staging, prod)

### Alternatives rejetées

GitLab CI : rejetée car nécessite un miroir GitLab (complexité infrastructure).
Jenkins : rejetée car nécessite un serveur dédié (coût + maintenance).

### Mise en œuvre

Fichiers livrés :
- .github/workflows/ci.yml (104 lignes)
- README.md avec badges

Test validé : pipeline vert dès le premier run (commit 6e6398e).

---

## ADR-019 — Pattern Worker extensible (Handler / Sender interfaces)

Statut : Accepté
Date : 03/10/2026
Domaine : Architecture / Backend
Références : BL-018, BL-019, NFR-OPS-04, NFR-UX-07

### Contexte

Deux workers ont été développés en parallèle :
- Worker jobs_async (traitement par type de job)
- Worker notifications (traitement par canal)

Sans abstraction, chaque worker aurait un bloc if/else ou switch sur le type :
```java
if ("LOG".equals(type)) { ... }
else if ("EMAIL".equals(type)) { ... }
else if ("SMS".equals(type)) { ... }
