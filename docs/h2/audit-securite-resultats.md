# Résultats — Tests d'intrusion cross-tenant

**Projet** : yCogniCore Cloud
**Sprint** : H2 — BL-020
**Date d'exécution** : 05/10/2026
**Durée d'exécution** : ~30 secondes

---

## Résumé exécutif

- **6 scénarios** testés
- **6 PASS** / **0 FAIL**
- **0 vulnérabilité critique** détectée
- **Conclusion** : l'isolation multi-tenant et le RBAC sont **inviolables** face aux attaques testées

---

## Détail par scénario

### Scénario 1 — Isolation BDD (JWT prioritaire sur header)

- **Attaque** : envoyer `X-Tenant-Code: DEMO002` avec un JWT valide de DEMO001
- **Résultat attendu** : `pgDatabase = ycc_tenant_demo001` (le JWT prime)
- **Résultat observé** : `[OK] JWT (DEMO001) prime sur header (DEMO002)`
- **Statut** : ✅ PASS

### Scénario 2 — Manipulation JWT (signature invalide)

- **Attaque** : token JWT avec signature bidon
- **Résultat attendu** : HTTP 401/403
- **Résultat observé** : `[OK] Signature invalide rejetee (HTTP 401)`
- **Statut** : ✅ PASS

### Scénario 3 — SQL Injection

- **Attaque** : email avec `' OR '1'='1`
- **Résultat attendu** : HTTP 400/401/500
- **Résultat observé** : `[OK] SQL Injection neutralisee (HTTP 400)`
- **Statut** : ✅ PASS

### Scénario 4 — RBAC bypass

- **Attaque** : commercial tente `COMPTABILITE.VALIDER` (non autorisé)
- **Résultat attendu** : HTTP 403
- **Résultat observé** : `[OK] Acces refuse sans permission`
- **Statut** : ✅ PASS

### Scénario 5 — RBAC autorisé (contrôle positif)

- **Attaque** : aucune — test de contrôle
- **Résultat attendu** : HTTP 200
- **Résultat observé** : `[OK] Acces autorise avec permission`
- **Statut** : ✅ PASS

### Scénario 6 — Escalade Superadmin

- **Attaque** : user tenant tente login sans tenantCode
- **Résultat attendu** : HTTP 401
- **Résultat observé** : `[OK] Escalade Superadmin refusee (HTTP 401)`
- **Statut** : ✅ PASS

---

## Analyse des 3 niveaux de défense

### Niveau 1 — Base de données ✅

- **Modèle** : Database-per-Tenant
- **Validé par** : Scénario 1
- **Garantie** : le JWT (claim `tenantCode`) prime sur le header HTTP, empêchant la falsification

### Niveau 2 — Backend (routage) ✅

- **Modèle** : MultiTenantConnectionProvider Hibernate 7
- **Validé par** : Scénario 1
- **Garantie** : le routeur utilise le JWT (non falsifiable) plutôt que le header

### Niveau 3 — RBAC ✅

- **Modèle** : 6 permissions × 16 modules
- **Validé par** : Scénarios 4 et 5
- **Garantie** : HTTP 403 si permission manquante

---

## Recommandations

1. **Renouveler** cet audit avant chaque mise en production majeure
2. **Automatiser** ces tests dans le pipeline CI/CD (Testcontainers)
3. **Ajouter** des scénarios en Phase 2 :
   - Attaque `alg=none` dans le JWT
   - Timing attack sur comparaison de hash
   - Force brute distribuée
   - Scan OWASP Dependency Check
4. **Documenter** chaque nouvelle faille trouvée et sa correction

---

## Conclusion

L'audit confirme que les **3 niveaux de défense** sont opérationnels :

1. Isolation Database-per-Tenant ✅
2. Routage JWT (non falsifiable) ✅
3. RBAC strict (403 sinon) ✅

**Aucune vulnérabilité critique** n'a été détectée sur les 6 scénarios testés.

---

**Fin du rapport de résultats — BL-020**
