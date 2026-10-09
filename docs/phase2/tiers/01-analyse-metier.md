---
title: "Référentiel Tiers — Analyse métier"
module: "Référentiel transverse (client + fournisseur)"
version: "1.0"
status: "VALIDÉ"
last_updated: "2026-10-09"
author: "Yameogo Idrissa"
---

# Référentiel Tiers — Analyse métier

**Projet** : yCogniCore Cloud
**Bloc** : V10 — Référentiel Tiers
**Phase** : 1.1 — Analyse métier
**Référence** : Design Bible Phase 2, Décision Q1 (tiers unifié)

---

## 1. Contexte et périmètre

### 1.1 Objet

Le référentiel Tiers unifie clients et fournisseurs dans une table unique. Il remplace crm_comptes (Bloc 1.2, legacy) et clients (Bloc 1.3, legacy).

### 1.2 Justification

Une entreprise peut être simultanément cliente et fournisseur. La séparation crée trois problèmes : duplication des données, impossibilité de consolider les créances, non-conformité SYSCOHADA.

### 1.3 Position dans l'architecture

Consommé par : CRM (V12), Ventes (V13), Achats (V14), Comptabilité (V16), Trésorerie (V17), Projets (V18).

### 1.4 Périmètre

Inclus : 4 tables (tiers, role_tiers, contact_tiers, adresse_tiers).

Exclu : prospects (CRM), comptes bancaires (Trésorerie), documents scannés (V9 Fichiers).

---

## 2. Règles de gestion

### 2.1 Identification (RG-01 à RG-05)

- RG-01 — Code tiers unique et immuable, format TIE-{ANNEE}-{NUMERO:06d}
- RG-02 — IFU unique lorsqu'il est renseigné
- RG-03 — RCCM unique lorsqu'il est renseigné
- RG-04 — Type de tiers obligatoire : PERSONNE_PHYSIQUE ou PERSONNE_MORALE
- RG-05 — Un tiers peut avoir plusieurs rôles simultanément

### 2.2 Rôles (RG-06 à RG-09)

- RG-06 — Un tiers sans rôle ne peut pas être utilisé dans une transaction
- RG-07 — Le rôle est porté par role_tiers avec clé étrangère composite
- RG-08 — Les rôles CLIENT et FOURNISSEUR peuvent coexister
- RG-09 — Le retrait d'un rôle est interdit si des transactions actives y sont rattachées

### 2.3 Classification (RG-10 à RG-13)

- RG-10 — Catégorie obligatoire : PARTICULIER, ENTREPRISE, ADMINISTRATION, ONG, ASSOCIATION
- RG-11 — Secteur d'activité configurable
- RG-12 — Régime fiscal obligatoire : REEL_NORMAL, REEL_SIMPLIFIE, CONTRIBUTION_UNIQUE
- RG-13 — Le régime fiscal détermine les obligations déclaratives

### 2.4 Coordonnées (RG-14 à RG-17)

- RG-14 — Un tiers possède au moins une adresse
- RG-15 — Un tiers peut avoir plusieurs adresses (SIEGE, FACTURATION, LIVRAISON)
- RG-16 — Contact principal obligatoire pour les personnes morales
- RG-17 — Un contact peut être rattaché à plusieurs tiers

### 2.5 Conditions commerciales (RG-18 à RG-22)

- RG-18 — Délai de paiement par défaut : 30 jours
- RG-19 — Plafond d'encours facultatif
- RG-20 — Devise préférée : XOF par défaut
- RG-21 — Langue préférée : fr par défaut
- RG-22 — Conditions de règlement personnalisables

### 2.6 Cycle de vie (RG-23 à RG-26)

- RG-23 — Statut ACTIF par défaut
- RG-24 — Statut INACTIF possible
- RG-25 — Aucune suppression physique (soft delete)
- RG-26 — Un tiers référencé dans une transaction ne peut pas être archivé

### 2.7 Traçabilité (RG-27 à RG-30)

- RG-27 — Modification tracée : created_at, updated_at, version
- RG-28 — Soft delete via deleted_at
- RG-29 — Documents légaux (IFU, RCCM) stockés dans fichiers (V9)
- RG-30 — Historique des changements de rôle conservé

---

## 3. Cas d'utilisation

- UC-01 — Créer un tiers
- UC-02 — Convertir un prospect en tiers
- UC-03 — Ajouter un rôle
- UC-04 — Ajouter une adresse
- UC-05 — Ajouter un contact
- UC-06 — Désactiver un tiers

---

## 4. Exigences fonctionnelles

- EF-01 — Créer, modifier, consulter un tiers (Must)
- EF-02 — Gérer les rôles multiples (Must)
- EF-03 — Gérer les adresses multiples (Must)
- EF-04 — Gérer les contacts multiples (Must)
- EF-05 — Convertir un prospect en tiers (Must)
- EF-06 — Bloquer un tiers sans rôle (Must)
- EF-07 — Bloquer la suppression physique (Must)
- EF-08 — Vérifier le plafond d'encours (Should)
- EF-09 — Rechercher par code, nom, IFU, RCCM (Must)
- EF-10 — Importer en masse (Could)

---

## 5. Exigences non-fonctionnelles

- ENF-01 — Audit complet
- ENF-02 — Soft delete obligatoire
- ENF-03 — Verrouillage optimiste
- ENF-04 — Index sur IFU, RCCM, code
- ENF-05 — Recherche floue (pg_trgm)
- ENF-06 — Isolation Database-per-Tenant
- ENF-07 — Aucun FLOAT pour les montants
- ENF-08 — TIMESTAMPTZ
- ENF-09 — Statuts en VARCHAR + CHECK
- ENF-10 — FK composite pour typer les liens

---

## 6. Glossaire

- **Tiers** — Entité juridique ou physique avec relations commerciales
- **IFU** — Identifiant Financier Unique (Burkina Faso)
- **RCCM** — Registre du Commerce et du Crédit Mobilier
- **Rôle** — Fonction d'un tiers (CLIENT, FOURNISSEUR)
- **Prospect** — Contact commercial non qualifié
- **Plafond d'encours** — Montant maximum de créances

---

## Historique

| Version | Date | Modification |
|---|---|---|
| 1.0 | 2026-10-09 | Création initiale |
