# Runbook — Restauration d'une sauvegarde

**Projet** : yCogniCore Cloud
**Sprint** : H2 — BL-021
**Durée** : ~15 minutes

## Objectif
Restaurer une base PostgreSQL (RTO < 4h, RPO < 1h).

**Référence** : NFR-DISPO-04 à 08.

## Étapes

### 1. Identifier le backup

    ls -lh /backups/ | grep ycc

### 2. Couper les connexions actives

    psql -h localhost -U postgres -d postgres -c "
    SELECT pg_terminate_backend(pid) FROM pg_stat_activity
     WHERE datname = 'ycc_control_plane' AND pid <> pg_backend_pid();"

### 3. Sauvegarder l'état actuel

    pg_dump -h localhost -U postgres -d ycc_control_plane | gzip > /tmp/pre-restore.sql.gz

### 4. DROP + CREATE

    psql -h localhost -U postgres -c "DROP DATABASE ycc_control_plane;"
    psql -h localhost -U postgres -c "CREATE DATABASE ycc_control_plane;"

### 5. Restaurer

    gunzip -c /backups/ycc_control_plane_YYYYMMDD.sql.gz \
      | psql -h localhost -U postgres -d ycc_control_plane

### 6. Vérifier

    SELECT COUNT(*) FROM tenants;

**Fin du runbook**
