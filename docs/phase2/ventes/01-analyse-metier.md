---
title: "Module Ventes — Analyse métier"
module: "Ventes (chaîne commerciale complète)"
version: "1.0"
status: "VALIDÉ"
last_updated: "2026-10-09"
author: "Yameogo Idrissa"
---

# Module Ventes — Analyse métier

**Projet** : yCogniCore Cloud
**Bloc** : V13 — Ventes refondu
**Phase** : 1.1 — Analyse métier
**Périmètre** : 13 tables en 5 sous-modules

---

## 1. Contexte et périmètre

### 1.1 Objet

Le module Ventes gère la chaîne documentaire commerciale complète : devis, commande, bon de livraison, facture, avoir, retour. Il remplace l'ancien V10 Ventes (12 tables, legacy) par une architecture unifiée.

### 1.2 Innovation architecturale — Documents unifiés

Au lieu de 6 tables séparées par type de document (`devis`, `commandes_clients`, `bons_livraison`, `factures_clients`, `avoirs_clients`, retours), une seule table `documents_vente` avec un champ `type_document`. Ce pattern, inspiré d'Odoo et SAP, évite la duplication massive et permet les conversions transverses (devis → commande → BL → facture).

### 1.3 Position dans l'architecture

- **Amont** : V9 (Fichiers), V10 (Tiers), V11 (Articles), V12 (CRM)
- **Aval** : V14 (Achats), V15 (Stocks), V16 (Comptabilité), V17 (Trésorerie), V18 (Projets)

### 1.4 Périmètre — 13 tables

**Documents (4)** : `documents_vente`, `documents_vente_lignes`, `documents_vente_liens`, `documents_vente_historique_statuts`

**Tarifs (3)** : `listes_prix`, `lignes_tarif`, `promotions`

**Workflow (2)** : `circuits_validation`, `validations_documents`

**Encaissement (3)** : `paiements`, `paiements_allocations`, `relances_factures`

**Numérotation (1)** : `sequences_documents`

### 1.5 Exclu

- Numérotation legacy (`numero_sequences` de V4) → conservée mais non utilisée
- Mouvements de stock → V15 Stocks
- Écritures comptables → V16 Comptabilité

---

## 2. Règles de gestion

### 2.1 Documents unifiés (RG-01 à RG-10)

- RG-01 — Un document a un type : DEVIS, COMMANDE, BL, FACTURE, AVOIR, RETOUR
- RG-02 — Un document a un numéro unique par type et par année
- RG-03 — Un document est rattaché à un Tiers (CLIENT)
- RG-04 — Les lignes d'un document référencent un article (V11)
- RG-05 — Le total TTC = total HT + total TVA (CHECK)
- RG-06 — Un devis accepté peut être converti en commande (lien N-N)
- RG-07 — Une commande peut générer plusieurs BL (livraisons partielles)
- RG-08 — Une facture peut être émise depuis une commande ou un BL
- RG-09 — Un avoir référence toujours une facture
- RG-10 — Un retour référence un BL

### 2.2 Cycle de vie (RG-11 à RG-15)

- RG-11 — Statuts devis : BROUILLON, ENVOYE, ACCEPTE, REFUSE, EXPIRE, CONVERTI
- RG-12 — Statuts commande : BROUILLON, CONFIRMEE, EN_PREPARATION, EXPEDIEE, LIVREE, ANNULEE
- RG-13 — Statuts BL : PREPARATION, EXPEDITION, LIVREE, RETOURNEE
- RG-14 — Statuts facture : BROUILLON, EMISE, PARTIELLEMENT_PAYEE, PAYEE, IMPAYEE, ANNULEE
- RG-15 — Chaque transition de statut est historisée

### 2.3 Tarifs (RG-16 à RG-19)

- RG-16 — Une liste de prix a une période de validité
- RG-17 — Une ligne de tarif lie un article à un prix
- RG-18 — Les listes peuvent être ciblées par Tiers
- RG-19 — Les promotions sont transverses (période, remise)

### 2.4 Workflow (RG-20 à RG-23)

- RG-20 — Circuits de validation configurables
- RG-21 — Une validation a un seuil (montant minimum)
- RG-22 — Les validateurs sont des users avec rôle
- RG-23 — Chaque validation est historisée

### 2.5 Encaissement (RG-24 à RG-30)

- RG-24 — Un paiement peut être alloué à plusieurs factures
- RG-25 — Un paiement a un mode (ESPECES, VIREMENT, MOBILE_MONEY, etc.)
- RG-26 — Le cumul des paiements ≤ total_ttc de la facture
- RG-27 — Les paiements validés sont immuables
- RG-28 — Les relances ont des niveaux (1, 2, 3)
- RG-29 — Une relance référence une facture impayée
- RG-30 — Les relances sont historisées

### 2.6 Numérotation (RG-31 à RG-33)

- RG-31 — Table `sequences_documents` : une ligne par (type_document, annee)
- RG-32 — Fonction `prochain_numero_document()` en SECURITY DEFINER
- RG-33 — Format : `{PREFIXE}-{ANNEE}-{NUMERO:06d}`

### 2.7 Traçabilité (RG-34 à RG-36)

- RG-34 — Audit complet (created_at, updated_at, version)
- RG-35 — Soft delete obligatoire
- RG-36 — Historique des statuts append-only

---

## 3. Cas d'utilisation (12)

- UC-01 — Créer un devis
- UC-02 — Convertir un devis en commande
- UC-03 — Confirmer une commande
- UC-04 — Émettre un bon de livraison
- UC-05 — Émettre une facture
- UC-06 — Créer un avoir
- UC-07 — Créer un retour
- UC-08 — Créer une liste de prix
- UC-09 — Créer une promotion
- UC-10 — Valider un document via circuit
- UC-11 — Enregistrer un paiement
- UC-12 — Allouer un paiement à plusieurs factures

---

## 4. Exigences fonctionnelles (15)

- EF-01 — Chaîne documentaire unifiée (Must)
- EF-02 — Conversions N-N (Must)
- EF-03 — Historique statuts (Must)
- EF-04 — Listes de prix (Must)
- EF-05 — Promotions (Should)
- EF-06 — Circuits de validation configurables (Should)
- EF-07 — Paiements multi-factures (Must)
- EF-08 — Allocations paiement (Must)
- EF-09 — Relances automatiques (Should)
- EF-10 — Numérotation sécurisée (Must)
- EF-11 — Calcul auto des totaux (Must)
- EF-12 — Remises ligne + globale (Must)
- EF-13 — Multi-devises (Should)
- EF-14 — Recherche documents (Must)
- EF-15 — Export PDF (Could)

---

## 5. Exigences non-fonctionnelles (10)

- ENF-01 à ENF-10 : audit, soft delete, verrouillage, index, recherche, isolation, NUMERIC, TIMESTAMPTZ, VARCHAR+CHECK, SECURITY DEFINER

---

## 6. Glossaire

- **Document unifié** — Table unique pour tous les types
- **Conversion N-N** — Lien entre deux documents de types différents
- **Allocation** — Répartition d'un paiement sur plusieurs factures
- **Relance** — Action de recouvrement niveau 1, 2 ou 3
- **Circuit validation** — Workflow d'approbation configurable
- **Liste de prix** — Référentiel de prix par article

---

## Historique

| Version | Date | Modification |
|---|---|---|
| 1.0 | 2026-10-09 | Création initiale |
