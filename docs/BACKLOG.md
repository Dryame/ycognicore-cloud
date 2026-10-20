# BACKLOG — yCogniCore Cloud

| Champ | Valeur |
|---|---|
| Version | 3.3 |
| Date | 20 octobre 2026 |
| Commit de référence | `57c08bf` |
| Branche | `main` |
| Dernier tag | `v0.8.0-phase3` |
| Phase en cours | P5 — Événements et workflow (à venir) |

---

## 1. Vue d'ensemble

- Phases clôturées : 5 (P0, P1, P2, P3, P4)
- Phase en cours : P5 — Événements et workflow
- Phases restantes : 5 (P6 à P10)
- Migrations tenant : V1 à V18
- Migrations control plane : V1 à V9
- Tests backend : 113 (110 réussis, 3 ignorés)
- Constats résolus : 34
- Constats documentés : 9
- ADR actifs : 24
- Points encadreur : 10 (P-01 à P-10)

---

## 2. Phases du planning

- P0 — Assainissement du dépôt — Clôturée — v0.5.1-assainissement
- P1 — Fiabilisation (CI, tests, secrets) — Clôturée — v0.6.1-fiabilisation
- P2 — Méthode et registre des décisions — Clôturée — v0.7.0-phase2
- P3 — Sécurité des accès et audit chaîné — Clôturée — v0.8.0-phase3
- **P4 — Chiffrement des champs sensibles — Clôturée**
- P5 — Événements et workflow — À venir
- P6 — Référentiel des modules — À venir
- P7 — Tranche verticale commerciale — À venir
- P8 — Modules métier restants — À venir
- P9 — Documents intelligents et IA — À venir
- P10 — Industrialisation et conformité — À venir

---

## 6. Phase 3 — Sécurité des accès et audit chaîné
*(Clôturée le 19 octobre 2026 — Tag v0.8.0-phase3 — voir archive)*

---

## 7. Phase 4 — Chiffrement des champs sensibles

Statut : Clôturée le 20 octobre 2026
Fiche d'analyse : docs/analyses/fiche-analyse-P4.md v1.1

### 7.1 — Décisions tranchées

- P-04 — Liste champs sensibles (ifu, rccm, telephone, conditions_reglement, email)
- D-P4-1 — Vault Transit datakey
- D-P4-2 — Format vault:vN:base64
- D-P4-3 — Colonnes dédiées HMAC
- D-P4-4 — Clé HMAC distincte via datakey
- D-P4-5 — Rotation manuelle à double lecture
- D-P4-6 — Garde-fou prod et Vault -dev
- D-P4-7 — Cache Caffeine in-process (TTL 5 min)
- D-P4-8 — Correction C40
- D-P4-9 — Fail-closed Vault KO sur champs sensibles
- D-P4-10 — mfa_secret_package reste via ycc-mfa-key (exception)
- D-P4-11 — Journalisation lectures
- D-P4-12 — Privilèges cles_tenant restrictifs

### 7.2 — Lots réalisés

- **L0** — Préparation (C40, VaultStartupGuard, ycc-master-key) — Clos
- **L1** — Migrations V9 (cles_tenant) et V18 (colonnes HMAC) — Clos
- **L2** — DataEncryptionService et HmacService — Clos
- **L3** — Extension VaultTransitService et intégration JPA (UserService, TiersService, AuthController, RefreshService, MfaService) — Clos
- **L4** — Rotation de clé (EncryptionKeyRotationService), batch de rechiffrement paginé (EncryptionMigrationService) et API (EncryptionController) — Clos
- **L5** — Tests (DataEncryptionService, EncryptionKeyRotation, HmacService, VaultStartupGuard) — Clos

### 7.3 — Constats résolus

- C40 — db_user=postgres codé en dur (corrigé via ycc_tenant_app)
- P4-8 — Email non traité (chiffré et HMAC ajouté)
- P4-9 — Normalisation HMAC (ajouté dans HmacService)
- P4-11 — Journalisation des lectures ajoutée

### 7.4 — Constats versés P4 (restants)

- C45 — Workflow CI intrusion : seed demo incomplet
- C52 — demo002 baselined V13 sans tables V9-V13 (tenant minimal)

---

## 9. Registre des constats (extrait)

### 9.1 — Constats résolus (34)

*(Voir phases précédentes)*
- P4 — C40, P4-8, P4-9, P4-11

### 9.2 — Constats documentés, en attente

- C19, C23, C27, C32, C34, C36, C39, C43, C44, C45, C46, C47, C48, C49, C50, C52

---

Fin du BACKLOG v3.3

Auteur : Yameogo Idrissa
Date : 20 octobre 2026
Prochain jalon : Phase 5 (Événements et workflow)
