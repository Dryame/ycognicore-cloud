# Diagnostic Sensible (BDD, Backend, Sécurité) — Phase 4
- Date : 2026-10-22 17:17:14


## 1. INFRASTRUCTURE SENSIBLE

- **[OK]** Conteneur PostgreSQL (pg-ycc) en cours d'exécution
- **[WARN]** Vault (vault-ycc) en cours d'exécution mais SCELLÉ

## 2. BASE DE DONNÉES (SCHÉMAS DE CHIFFREMENT)

- **[OK]** Table 'cles_tenant' présente (Control Plane V9)
- **[KO]** Colonnes HMAC manquantes sur 'tiers' (trouvées : ifu_hmacrccm_hmactelephone_hmacemail_hmac)
- **[OK]** Les 2 colonnes HMAC sont présentes sur la table 'users' (Tenant V18)
- **[WARN]** 5 email(s) en clair détecté(s) dans 'users' (migration non terminée ?)

## 3. BACKEND (CLASSES SENSIBLES)

- **[OK]** Classe DataEncryptionService.java présente
- **[OK]** Classe HmacService.java présente
- **[OK]** Classe EncryptionKeyRotationService.java présente
- **[OK]** Classe EncryptionController.java présente
- **[OK]** Classe VaultStartupGuard.java présente

## 4. BACKEND (COMPILATION ET TESTS)


## RÉSUMÉ DU DIAGNOSTIC

- **Total OK** : 10
- **Total KO** : 1
- **Total WARN** : 2
