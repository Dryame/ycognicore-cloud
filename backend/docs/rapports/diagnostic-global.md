# Rapport de diagnostic global — yCogniCore Cloud

- Date : 2026-10-20 14:45:44 GMT
- Hôte : LAPTOP-GQKVU7JJ
- Utilisateur : idrissa_yameogo
- Dépôt : /home/idrissa_yameogo/projets/ycognicore-cloud/backend


## 1. ÉTAT GIT

[INFO] Branche : main
[INFO] Dernier commit : b9eb9a8 fix(crypto): Runner definit TenantContext avant migrate (P4 L3.3)
[INFO] Tag le plus récent : v0.8.0-phase3
[WARN] Working tree : 2 fichier(s) modifié(s) / non suivi(s)
[OK] Tag v0.8.0-phase3 présent

## 2. INFRASTRUCTURE DOCKER

[OK] Conteneur pg-ycc : running
[OK] Conteneur vault-ycc : running
[OK] Conteneur redis-ycc : running
[OK] Conteneur minio-ycc : running
[OK] Conteneur prometheus-ycc : running
[OK] Conteneur grafana-ycc : running
[OK] Port 5432 ouvert
[OK] Port 8200 ouvert
[OK] Port 6379 ouvert
[OK] Port 8080 ouvert
[OK] Vault : déscellé

## 3. BASE DE DONNÉES (PostgreSQL)

[OK] Connexion ycc_control_plane OK
[OK] Connexion ycc_tenant_demo001 OK
[OK] Table cles_tenant présente (Control Plane V9)
[OK] tiers.ifu_hmac présent
[OK] tiers.rccm_hmac présent
[OK] tiers.telephone_hmac présent
[OK] tiers.email_hmac présent
[OK] users.mfa_secret_package présent

## 4. BACKEND (Spring Boot)

[OK] Java : 21
[KO] Fichier DataEncryptionService.java absent
[KO] Fichier HmacService.java absent
[KO] Fichier VaultTransitService.java absent
[KO] Fichier VaultStartupGuard.java absent

## 5. FRONTEND (Angular)

[OK] Node.js : v22
[WARN] frontend/node_modules absent (npm install requis)

## 6. CONFIGURATION ET SÉCURITÉ

[KO] .env.example absent
[KO] application.yml absent
[KO] GeoIP : data/geoip/ absent ou vide

## RÉSUMÉ

- Total OK   : 22
- Total KO   : 7
- Total WARN : 2
- Total      : 31
