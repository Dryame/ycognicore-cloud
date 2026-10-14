# Matrice de conformité — 24 exigences de l'encadreur

**Projet** : yCogniCore Cloud
**Référence** : Catalogue des modules v1.1, section 2.2
**Date** : 14 octobre 2026
**Périmètre** : 5 axes, 24 exigences
**Auteur** : Yameogo Idrissa

---

## Légende

- **Couvert** : preuve fournie
- **En cours** : phase planifiée ou partiellement traitée
- **À venir** : phase ultérieure

---

## Axe 1 — Développement et amélioration

### 1.1 — Améliorer interfaces, fonctionnalités et modules existants

- Phase(s) : P0 à P9
- Traitement : fiche d'analyse par module, corrections du dépôt
- Statut : Couvert

### 1.2 — Services Word, remplissage automatique, OCR, génération

- Phase(s) : P9
- Traitement : interface commune appelée par 2 modules (T9.1)
- Statut : À venir

### 1.3 — Recherche globale et avancée selon les autorisations

- Phase(s) : P8, P9
- Traitement : recherche filtrée par droits (T8.7), sémantique (T9.6)
- Statut : À venir

### 1.4 — Assistance à la saisie, langues et devises

- Phase(s) : P8, P9
- Traitement : paramètres (T8.6), module N7 (T9.3)
- Statut : À venir

### 1.5 — Cohérence des données et communication entre modules

- Phase(s) : P5
- Traitement : outbox, contrôles de cohérence, workflow (T5.1 à T5.7)
- Statut : À venir

---

## Axe 2 — Sécurisation complète

### 2.1 — Comptes, rôles, permissions

- Phase(s) : Existant, P1, P6
- Traitement : RBAC en place, extension aux nouveaux modules, droits spéciaux de console
- Statut : Couvert

### 2.2 — MFA, JWT, renouvellement, révocation

- Phase(s) : P3
- Traitement : T3.2 — test de rejeu et de révocation
- Statut : En cours

### 2.3 — Gestion des appareils

- Phase(s) : P3
- Traitement : T3.1, T3.5
- Statut : En cours

### 2.4 — Connexions inhabituelles et alertes

- Phase(s) : P3
- Traitement : T3.11 — règles N2 testées
- Statut : En cours

### 2.5 — Chiffrement, sauvegardes, restauration testée

- Phase(s) : P4, P10
- Traitement : chiffrement en enveloppe (P4), restauration testée (T10.3)
- Statut : En cours

### 2.6 — Injection, XSS, CSRF, force brute, usurpation, accès non autorisés

- Phase(s) : P1, P3, P10
- Traitement : T3.7, campagne d'intrusion (T10.2)
- Statut : En cours

### 2.7 — Journalisation, limitation des requêtes, contrôles

- Phase(s) : P1, P3
- Traitement : audit chaîné et anti-TRUNCATE (P1), limitation (T3.6, T3.9)
- Statut : Couvert

---

## Axe 3 — Sessions et appareils

### 3.1 — Politique de sessions actives

- Phase(s) : P3
- Traitement : T3.3
- Statut : À venir

### 3.2 — Déconnexion des sessions expirées ou révoquées

- Phase(s) : P3
- Traitement : T3.4
- Statut : À venir

### 3.3 — Console d'administration de sécurité

- Phase(s) : P3, P7
- Traitement : T3.12 à T3.14, écrans d'administration (T7.7)
- Statut : À venir

### 3.4 — Informations techniques, localisation approximative, confidentialité

- Phase(s) : P3
- Traitement : T3.8 — référence légale à confirmer (P-02)
- Statut : À venir

---

## Axe 4 — Architecture, performances et fiabilité

### 4.1 — Architecture modulaire, maintenable, évolutive

- Phase(s) : P0, P2, P5, P7
- Traitement : source unique, ADR, événements, règles ArchUnit (T7.2)
- Statut : Couvert

### 4.2 — Optimisation des performances

- Phase(s) : P10
- Traitement : T10.1 — mesurer avant d'optimiser
- Statut : À venir

### 4.3 — Isolation entre entreprises

- Phase(s) : P1, P7, P10
- Traitement : tests d'accès croisé (T1.2, T7.8, T10.2)
- Statut : Couvert

### 4.4 — Tests fonctionnels, techniques, sécurité, charge

- Phase(s) : P1, P7, P10
- Traitement : CI bloquante (T1.1), erreurs normalisées (T7.1), charge (T10.4)
- Statut : En cours

### 4.5 — Compatibilité Web et mobile, stabilité après mise à jour

- Phase(s) : P10
- Traitement : T10.5
- Statut : À venir

---

## Axe 5 — Méthodologie et responsabilités

### 5.1 — Analyser l'existant avant modification

- Phase(s) : P2
- Traitement : fiche d'analyse préalable (annexe B)
- Statut : Couvert

### 5.2 — Tests, documentation, démonstrations, rapports journaliers

- Phase(s) : P2, P7
- Traitement : modèle de rapport (annexe D), démonstration (T7.8)
- Statut : Couvert

### 5.3 — Aucune modification terminée sans vérification

- Phase(s) : P2
- Traitement : checklist de clôture (annexe C)
- Statut : Couvert

---

## Synthèse par axe

**Axe 1 — Développement**

- Exigences : 5
- Couvertes : 1
- En cours : 0
- À venir : 4

**Axe 2 — Sécurité**

- Exigences : 7
- Couvertes : 2
- En cours : 5
- À venir : 0

**Axe 3 — Sessions et appareils**

- Exigences : 4
- Couvertes : 0
- En cours : 0
- À venir : 4

**Axe 4 — Architecture**

- Exigences : 5
- Couvertes : 2
- En cours : 1
- À venir : 2

**Axe 5 — Méthodologie**

- Exigences : 3
- Couvertes : 3
- En cours : 0
- À venir : 0

**Total**

- Exigences : 24
- Couvertes : 8
- En cours : 6
- À venir : 10

Avancement global : 8 exigences couvertes sur 24 (33 %).

---

## Références croisées

- Catalogue v1.1, matrice de conformité — section 2.2
- Planning v1.1, matrice des 24 exigences — section 8.1
- Registre des points à confirmer — docs/decisions/points-a-confirmer.md
- Index des ADR — docs/adr/README.md
