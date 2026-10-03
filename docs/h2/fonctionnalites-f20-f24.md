# Sprint H2 — Fonctionnalités développées et modifiées (03/10/2026)

## Fonctionnalités développées (nouvelles)

### F-20 — Frontend Angular Core

Description : Structure complète du frontend Angular 22 avec authentification JWT, guards, layouts et routing 4 profils.

Références : BL-015, ADR-016, NFR-SEC-06, NFR-SEC-11

Composants créés :
- src/app/core/models/login.model.ts (LoginRequest, LoginResponse, UserInfo, RefreshResponse)
- src/app/core/models/user.model.ts (UserType, CurrentUser)
- src/app/core/auth/auth.service.ts (login, refresh, logout, BehaviorSubject)
- src/app/core/auth/auth.guard.ts (CanActivateFn)
- src/app/core/auth/role.guard.ts (CanActivateFn avec data.roles)
- src/app/core/http/jwt.interceptor.ts (HttpInterceptorFn)
- src/app/layout/main-layout/main-layout.component.ts (header + outlet)
- src/app/layout/auth-layout/auth-layout.component.ts (centré)
- src/app/features/dashboard/dashboard.component.ts (placeholder)
- src/app/app.config.ts (provideZonelessChangeDetection)
- src/app/app.routes.ts (4 profils + lazy loading)
- src/environments/environment.ts (dev)
- src/environments/environment.prod.ts (prod)
- angular.json (fileReplacements)

Tests : 4 profils validés visuellement dans le navigateur.

### F-21 — Page login (LoginComponent)

Description : Formulaire de connexion unique avec gestion erreurs et redirection automatique.

Références : BL-016, NFR-SEC-06, ADR-017

Composants créés :
- src/app/features/auth/login/login.component.ts

Fonctionnalités :
- 3 champs : email, password, tenantCode (optionnel)
- Validation Angular (form valid)
- Gestion loading (signal)
- Gestion erreur (signal)
- Redirection vers user.redirectUrl après login

Tests : message Unauthorized affiché pour mauvais mot de passe.

### F-22 — CI/CD GitHub Actions

Description : Pipeline automatisé sur push (build backend + frontend + quality).

Références : BL-017, NFR-MAINT-04, NFR-OPS-01

Composants créés :
- .github/workflows/ci.yml (104 lignes)
- README.md (badges CI + stack + démarrage rapide)

Fonctionnalités :
- Déclenchement : push main/develop + PR + workflow_dispatch
- Job backend : JDK 21 + Maven + build + tests
- Job frontend : Node 22 + Angular build production
- Job quality : vérification structure
- Job summary : statut global
- Artifacts : JAR backend + dist frontend (7 jours de rétention)

Tests : pipeline vert dès le premier run (commit 6e6398e).

### F-23 — Worker jobs_async

Description : Consommateur de la table jobs_async (control plane) avec dispatch par handler et retry exponentiel.

Références : BL-019, NFR-OPS-04

Composants créés :
- src/main/java/bf/ycognicore/backend/worker/JobHandler.java (interface)
- src/main/java/bf/ycognicore/backend/worker/JobAsyncWorker.java
- src/main/java/bf/ycognicore/backend/worker/JobAsyncScheduler.java
- src/main/java/bf/ycognicore/backend/worker/LogJobHandler.java

Fonctionnalités :
- Sélection par priorité (ORDER BY priorite, date_creation)
- BATCH_SIZE = 10
- Dispatch vers JobHandler selon type_job
- Retry avec backoff 2^n secondes
- max_tentatives par défaut = 3
- Statuts : EN_ATTENTE → EN_COURS → TERMINE / ECHOUE
- Utilise controlPlaneDataSource (jobs_async est dans le CP)

Tests validés :
- Job LOG → TERMINE avec timestamps
- Job UNKNOWN_TYPE → ECHOUE avec erreur "Handler introuvable"

### F-24 — Worker notifications multicanal

Description : Consommateur de la table notifications_queue (control plane) avec dispatch par canal.

Références : BL-018, NFR-UX-07

Composants créés :
- src/main/java/bf/ycognicore/backend/worker/notification/NotificationSender.java (interface)
- src/main/java/bf/ycognicore/backend/worker/notification/EmailNotificationSender.java (mock)
- src/main/java/bf/ycognicore/backend/worker/notification/SmsNotificationSender.java (mock)
- src/main/java/bf/ycognicore/backend/worker/notification/NotificationWorker.java
- src/main/java/bf/ycognicore/backend/worker/notification/NotificationScheduler.java

Fonctionnalités :
- Sélection par ordre de création (date_creation ASC)
- BATCH_SIZE = 20
- Dispatch vers NotificationSender selon canal
- Retry avec backoff 2^n secondes
- MAX_TENTATIVES = 3
- Statuts : EN_ATTENTE → ENVOYEE / ECHOUEE
- Canaux supportés : EMAIL, SMS (WhatsApp, Telegram à venir)

Tests validés :
- 3 notifications envoyées (1 EMAIL + 2 SMS)
- Tentatives = 1, statut = ENVOYEE

## Fonctionnalités modifiées

### SecurityConfig.java — Ajout CORS

Modification : ajout d'un bean CorsConfigurationSource + activation dans la filter chain.

Détail :
- Origines autorisées : http://localhost:4200, http://127.0.0.1:4200
- Méthodes : GET, POST, PUT, PATCH, DELETE, OPTIONS
- Headers : tous
- Credentials : true
- maxAge : 3600s
- Preflight OPTIONS : permitAll

Références : ADR-017

### AuthDispatcherService.java — URLs de redirection

Modification : retrait du suffixe /dashboard dans les 4 URLs.

Avant / Après :
- /superadmin/dashboard → /superadmin
- /admin/dashboard → /admin
- /employee/dashboard → /employee
- /portal/dashboard → /portal

Cause : les routes Angular attendaient /superadmin (sans /dashboard).

### README.md — Créé

Modification : création d'un README à la racine avec badges CI + stack + démarrage rapide.

## Fonctionnalités supprimées

Aucune fonctionnalité supprimée aujourd'hui.

## Fonctionnalités testées

Tests frontend :
- Login Superadmin → redirection /superadmin (OK)
- Login Admin → redirection /admin + badge ADMIN (OK)
- Login Commercial → redirection /employee + badge INTERNE (OK)
- Mauvais mot de passe → Unauthorized (OK)

Tests CI/CD :
- Pipeline GitHub Actions → vert (OK)

Tests worker jobs_async :
- Job LOG → TERMINE (OK)
- Job UNKNOWN_TYPE → ECHOUE (OK)

Tests worker notifications :
- Notification EMAIL → ENVOYEE (OK)
- Notification SMS (×2) → ENVOYEE (OK)

---

Fin du document Fonctionnalités — 3 octobre 2026
