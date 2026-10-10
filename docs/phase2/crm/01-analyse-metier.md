---
title: "Module CRM — Analyse métier"
module: "CRM (Customer Relationship Management)"
version: "1.0"
status: "VALIDÉ"
last_updated: "2026-10-09"
author: "Yameogo Idrissa"
reference: "Design Bible Phase 2, proposition V6 validée"
---

# Module CRM — Analyse métier

**Projet** : yCogniCore Cloud
**Bloc** : V12 — CRM refondu
**Phase** : 1.1 — Analyse métier
**Référence** : Design Bible Phase 2

---

## 1. Contexte et périmètre

### 1.1 Objet

Le module CRM gère le cycle commercial complet : prospection, qualification, conversion, suivi, automatisation. Il remplace l'ancien V9 CRM (8 tables, legacy).

### 1.2 Position dans l'architecture

- **Dépendances** : V9 (Fichiers), V10 (Tiers), V11 (Articles)
- **Consommé par** : Ventes (V13), Comptabilité (V16), Projets (V18)

### 1.3 Périmètre — 14 tables en 4 sous-modules

**Acteurs (4 tables)** :

- `prospects` — Contacts commerciaux non qualifiés, avec score IA et consentement
- `contacts` — Contacts rattachés aux tiers (canal préféré, langue)
- `campagnes` — Campagnes marketing
- `campagne_cibles` — Cibles d'une campagne (N-N)

**Pipeline (4 tables)** :

- `pipelines` — Configuration de pipelines (standard + custom par tenant)
- `pipeline_etapes` — Étapes d'un pipeline (configurable)
- `opportunites` — Opportunités commerciales (probabilité humaine + IA)
- `opportunites_historique_etapes` — Historique des transitions de pipeline

**Suivi (4 tables)** :

- `activites` — Travail planifié (appels, RDV, tâches)
- `interactions` — Journal multicanal avec sentiment IA
- `rendez_vous` — Rendez-vous avec participants multiples
- `rendez_vous_participants` — Participants d'un RDV

**Workflow (2 tables)** :

- `crm_regles_automatisation` — Règles d'automatisation configurables
- `crm_regles_executions` — Historique d'exécution des règles

### 1.4 Exclu

- Comptes clients (Tiers V10)
- Facturation (Ventes V13)
- Devis et commandes (Ventes V13)

---

## 2. Règles de gestion

### 2.1 Prospects (RG-01 à RG-06)

- RG-01 — Un prospect n'a pas d'IFU ni de conditions de paiement
- RG-02 — Un prospect peut être converti en Tiers (V10)
- RG-03 — Le score IA d'un prospect est distinct du jugement humain
- RG-04 — Le consentement (opt-in / opt-out) par canal est obligatoire
- RG-05 — Un prospect sans consentement ne peut pas être contacté automatiquement
- RG-06 — La source du prospect est tracée (WEB, SALON, RECOMMANDATION, etc.)

### 2.2 Contacts (RG-07 à RG-10)

- RG-07 — Un contact est rattaché à un Tiers (V10)
- RG-08 — Plusieurs contacts par Tiers
- RG-09 — Le canal préféré est obligatoire (EMAIL, SMS, WHATSAPP, APPEL)
- RG-10 — La langue préférée est obligatoire

### 2.3 Campagnes (RG-11 à RG-13)

- RG-11 — Une campagne a une période (date_debut, date_fin)
- RG-12 — Les cibles d'une campagne sont multiples (N-N)
- RG-13 — Une campagne peut cibler des prospects, des contacts ou les deux

### 2.4 Pipeline (RG-14 à RG-18)

- RG-14 — Le pipeline est configurable par tenant
- RG-15 — Le pipeline standard contient 6 étapes préchargées
- RG-16 — Une étape a un ordre et un pourcentage de probabilité par défaut
- RG-17 — Une opportunité progresse d'étape en étape
- RG-18 — Chaque transition d'étape est historisée

### 2.5 Opportunités (RG-19 à RG-24)

- RG-19 — Une opportunité est rattachée à un Tiers
- RG-20 — La probabilité humaine et la probabilité IA sont distinctes
- RG-21 — Le montant estimé est obligatoire
- RG-22 — La date de clôture prévue est obligatoire
- RG-23 — L'abandon automatique après 90 jours d'inactivité (paramétrable)
- RG-24 — Les transitions de statut sont : OUVERTE → EN_NEGOCIATION → GAGNEE/PERDUE/ABANDONNEE

### 2.6 Activités (RG-25 à RG-28)

- RG-25 — Une activité peut être planifiée ou réalisée
- RG-26 — Les types d'activité : APPEL, EMAIL, RDV, VISITE, TACHE, NOTE
- RG-27 — Une activité est rattachée à au moins une entité (prospect, contact, opportunité, campagne)
- RG-28 — Le statut d'une activité : PLANIFIEE, EN_COURS, TERMINEE, ANNULEE

### 2.7 Interactions (RG-29 à RG-32)

- RG-29 — Une interaction est un échange réalisé (pas planifié)
- RG-30 — Les interactions sont multicanal (EMAIL, APPEL, SMS, WHATSAPP, etc.)
- RG-31 — Le résumé IA et le sentiment IA sont calculés automatiquement
- RG-32 — Les interactions sont append-only (jamais modifiées)

### 2.8 Rendez-vous (RG-33 à RG-35)

- RG-33 — Un RDV a un lieu, une date début, une date fin
- RG-34 — Un RDV a plusieurs participants
- RG-35 — Un participant peut être interne (user) ou externe (contact)

### 2.9 Workflow CRM (RG-36 à RG-40)

- RG-36 — Les règles d'automatisation sont configurables par l'Admin Client
- RG-37 — Une règle a une condition et une action
- RG-38 — Les actions possibles : créer tâche, envoyer email, changer statut, assigner user
- RG-39 — Chaque exécution de règle est historisée
- RG-40 — Une règle peut être activée/désactivée sans suppression

---

## 3. Cas d'utilisation

- UC-01 — Créer un prospect
- UC-02 — Qualifier un prospect (changement de statut)
- UC-03 — Convertir un prospect en Tiers
- UC-04 — Créer une opportunité
- UC-05 — Faire progresser une opportunité dans le pipeline
- UC-06 — Planifier une activité
- UC-07 — Enregistrer une interaction
- UC-08 — Créer un rendez-vous
- UC-09 — Créer une campagne
- UC-10 — Configurer une règle d'automatisation

---

## 4. Exigences fonctionnelles

- EF-01 — Gérer les prospects avec score IA et consentement (Must)
- EF-02 — Gérer les contacts rattachés aux Tiers (Must)
- EF-03 — Gérer les campagnes marketing (Should)
- EF-04 — Pipelines configurables (Must)
- EF-05 — Opportunités avec probabilité humaine + IA (Must)
- EF-06 — Historique des transitions pipeline (Must)
- EF-07 — Activités planifiées (Must)
- EF-08 — Interactions multicanal avec sentiment IA (Must)
- EF-09 — Rendez-vous avec participants multiples (Should)
- EF-10 — Workflow d'automatisation configurable (Should)
- EF-11 — Conversion prospect → Tiers (Must)
- EF-12 — Recherche floue prospects/contacts (Must)

---

## 5. Exigences non-fonctionnelles

- ENF-01 — Audit complet (created_at, updated_at, version)
- ENF-02 — Soft delete obligatoire
- ENF-03 — Verrouillage optimiste
- ENF-04 — Index sur statut, dates, Tiers
- ENF-05 — Recherche floue (pg_trgm)
- ENF-06 — Isolation Database-per-Tenant
- ENF-07 — Aucun FLOAT pour montants
- ENF-08 — TIMESTAMPTZ
- ENF-09 — Statuts en VARCHAR + CHECK
- ENF-10 — Interactions append-only (trigger)

---

## 6. Glossaire

- **Prospect** — Contact commercial non qualifié
- **Pipeline** — Séquence d'étapes de vente
- **Opportunité** — Vente potentielle identifiée
- **Activité** — Action planifiée ou réalisée
- **Interaction** — Échange réalisé (email, appel, message)
- **Rendez-vous** — Réunion planifiée avec participants
- **Campagne** — Action marketing ciblée
- **Score IA** — Évaluation algorithmique d'un prospect
- **Sentiment IA** — Analyse automatique du ton d'une interaction
- **Consentement** — Autorisation de contact (RGPD-like)

---

## Historique

| Version | Date | Modification |
|---|---|---|
| 1.0 | 2026-10-09 | Création initiale |
