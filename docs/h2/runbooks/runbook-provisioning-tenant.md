# Runbook — Provisioning d'un nouveau tenant

**Projet** : yCogniCore Cloud
**Sprint** : H2 — BL-021
**Durée** : ~5 minutes

## Objectif
Créer un nouvel espace client complet : base PostgreSQL dédiée,
migrations Flyway, premier Admin Client, quota IA.

**Référence** : NFR-SCAL-02, NFR-OPS-04.

## Prérequis
- Docker opérationnel (4 services healthy)
- Vault initialisé (`ycc-mfa-key` présente)
- Accès superuser PostgreSQL

## Étapes

### 1. Créer la ligne tenant dans le control plane
Exécuter dans psql sur `ycc_control_plane` :

    INSERT INTO tenants (code, nom, email_contact, pays, statut, formule)
    VALUES ('DEMO003', 'Entreprise Démo 3', 'contact@demo003.bf',
            'Burkina Faso', 'TRIAL', 'TRIAL')
    RETURNING id;

Noter l'UUID retourné.

### 2. Lancer le provisioning Python

    cd ~/projets/ycognicore-cloud/scripts
    python3 provisioning_tenant.py \
      --tenant-id <UUID> \
      --code-tenant DEMO003 \
      --email-admin admin@demo003.bf \
      --formule TRIAL \
      --send-email

### 3. Vérifier la base

    psql -h localhost -U postgres -d ycc_tenant_demo003 -c "\dt"

Attendu : 14 tables.

## Rollback
Le script Python supprime automatiquement la base si échec.

**Fin du runbook**
