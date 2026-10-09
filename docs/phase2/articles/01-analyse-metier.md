---
title: "Référentiel Articles — Analyse métier"
module: "Référentiel transverse (articles + variantes)"
version: "1.0"
status: "VALIDÉ"
last_updated: "2026-10-09"
author: "Yameogo Idrissa"
reference: "Design Bible Phase 2, Décisions V11"
---

# Référentiel Articles — Analyse métier

**Projet** : yCogniCore Cloud
**Bloc** : V11 — Référentiel Articles
**Phase** : 1.1 — Analyse métier
**Référence** : Design Bible Phase 2

---

## 1. Contexte et périmètre

### 1.1 Objet

Le référentiel Articles centralise toutes les marchandises vendues ou achetées par l'entreprise. Il est transverse et sera consommé par Ventes, Achats, Stocks, Comptabilité, Projets.

### 1.2 Position dans l'architecture

Consommé par : Ventes (V13), Achats (V14), Stocks (V15), Comptabilité (V16), Projets (V18).

Dépendances : V9 (Fichiers pour images et documents), V10 (Tiers pour prix fournisseurs).

### 1.3 Périmètre

**Inclus** : 7 tables

- `familles_articles` — Référentiel hiérarchique (parent/enfant)
- `unites_mesure` — Référentiel (kg, L, pièce, m, m², m³, etc.)
- `marques` — Référentiel
- `taxes` — Référentiel (TVA 18 %, exonérations, droits d'accises)
- `articles` — Fiche principale
- `article_variantes` — Variantes (taille, couleur, modèle)
- `articles_fournisseurs` — Liaison N-N avec prix d'achat

**Exclu** :

- Lots et séries → V15 Stocks
- Stocks et mouvements → V15 Stocks
- Codes-barres multiples → V15 Stocks
- Prix de vente (listes) → V13 Ventes

### 1.4 Contraintes

- Conformité SYSCOHADA (comptes de stock)
- Réglementation BF (TVA 18 %, exonérations)
- Design Bible Phase 2 (aucun ENUM, soft delete, audit)

---

## 2. Règles de gestion

### 2.1 Identification (RG-01 à RG-05)

- RG-01 — Chaque article possède un `code` unique et immuable, format `ART-{ANNEE}-{NUMERO:06d}`
- RG-02 — Le code-barres (EAN-13 ou autre) est unique lorsqu'il est renseigné
- RG-03 — Un article peut avoir plusieurs codes-barres (EAN, UPC, code interne)
- RG-04 — Le type d'article est obligatoire : MARCHANDISE, SERVICE, PRODUIT_FINI, MATIERE_PREMIERE
- RG-05 — La famille d'article est obligatoire

### 2.2 Classification (RG-06 à RG-10)

- RG-06 — Les familles sont hiérarchiques (parent/enfant), profondeur max 5 niveaux
- RG-07 — La marque est facultative
- RG-08 — L'unité de mesure de base est obligatoire
- RG-09 — L'unité d'achat peut différer de l'unité de vente
- RG-10 — Un facteur de conversion entre unités est obligatoire si multi-unité

### 2.3 Variantes (RG-11 à RG-14)

- RG-11 — Un article peut avoir plusieurs variantes (taille, couleur, modèle)
- RG-12 — Chaque variante possède un code unique dérivé du code article
- RG-13 — Les variantes partagent les attributs de l'article parent
- RG-14 — Une variante peut avoir un code-barres propre

### 2.4 Fiscalité (RG-15 à RG-17)

- RG-15 — Chaque article est rattaché à une taxe (TVA, exonération)
- RG-16 — Le taux de TVA par défaut est 18 % (Burkina Faso)
- RG-17 — Les articles peuvent être soumis à des droits d'accises (alcool, tabac)

### 2.5 Prix et fournisseurs (RG-18 à RG-22)

- RG-18 — Un article peut être fourni par plusieurs fournisseurs (Tiers avec rôle FOURNISSEUR)
- RG-19 — Le prix d'achat peut varier par fournisseur
- RG-20 — Un fournisseur peut avoir un délai de livraison propre par article
- RG-21 — La référence fournisseur est unique par couple (article, fournisseur)
- RG-22 — Le prix de vente n'est pas stocké dans `articles` (géré dans V13 Ventes via `listes_prix`)

### 2.6 Cycle de vie (RG-23 à RG-26)

- RG-23 — Un article nouvellement créé est en statut ACTIF
- RG-24 — Un article peut être INACTIF (désactivé temporairement)
- RG-25 — Aucune suppression physique (soft delete uniquement)
- RG-26 — Un article référencé dans une transaction ne peut pas être archivé

### 2.7 Traçabilité (RG-27 à RG-30)

- RG-27 — Modification tracée : created_at, updated_at, version
- RG-28 — Soft delete via deleted_at
- RG-29 — Les images d'articles sont stockées dans `fichiers` (V9)
- RG-30 — L'historique des changements de prix fournisseurs est conservé

---

## 3. Cas d'utilisation

- UC-01 — Créer un article : code, désignation, famille, unité, taxe
- UC-02 — Ajouter une variante : taille, couleur, modèle
- UC-03 — Rattacher un fournisseur : référence, prix, délai
- UC-04 — Modifier le prix d'achat : historique conservé
- UC-05 — Ajouter une image : stockage via V9
- UC-06 — Désactiver un article : bloqué si transactions actives

---

## 4. Exigences fonctionnelles

- EF-01 — Créer, modifier, consulter un article (Must)
- EF-02 — Gérer les variantes (Must)
- EF-03 — Gérer les familles hiérarchiques (Must)
- EF-04 — Gérer les unités de mesure (Must)
- EF-05 — Gérer les taxes (Must)
- EF-06 — Rattacher plusieurs fournisseurs (Must)
- EF-07 — Gérer les prix d'achat par fournisseur (Must)
- EF-08 — Rechercher par code, code-barres, désignation (Must)
- EF-09 — Bloquer la suppression physique (Must)
- EF-10 — Import en masse (Could)

---

## 5. Exigences non-fonctionnelles

- ENF-01 — Audit complet
- ENF-02 — Soft delete obligatoire
- ENF-03 — Verrouillage optimiste
- ENF-04 — Index sur code, code-barres, famille
- ENF-05 — Recherche floue sur désignation (pg_trgm)
- ENF-06 — Isolation Database-per-Tenant
- ENF-07 — Aucun FLOAT pour les montants et quantités
- ENF-08 — TIMESTAMPTZ
- ENF-09 — Statuts en VARCHAR + CHECK
- ENF-10 — FK composites pour typer les liens

---

## 6. Glossaire

- **Article** — Marchandise ou service vendu/acheté
- **Famille** — Catégorie hiérarchique d'articles
- **Variante** — Déclinaison d'un article (taille, couleur)
- **Unité de mesure** — kg, L, pièce, m, m², m³
- **Taxe** — TVA 18 %, exonération, droits d'accises
- **Code-barres** — EAN-13, UPC, code interne
- **Référence fournisseur** — Code propre au fournisseur

---

## Historique

| Version | Date | Modification |
|---|---|---|
| 1.0 | 2026-10-09 | Création initiale |
