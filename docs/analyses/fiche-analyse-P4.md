# Fiche d'analyse — Phase 4

**Chiffrement applicatif des champs sensibles**

| Champ | Valeur |
|---|---|
| Version | 1.1 (corrigée le 19 octobre 2026) |
| Phase | P4 — Chiffrement des champs sensibles |
| Migrations prévues | V9 (control plane), V18 (tenant) |
| Tâches | T4.1 à T4.8 |
| Commit de référence | `a2367f0`, tag `v0.8.0-phase3` |
| Auteur | Yameogo Idrissa |
| Statut | Projet — en attente de validation encadreur |

---

## 1. Périmètre

### Objectif

Une copie de la base, une sauvegarde ou un accès disque **ne doit pas permettre de lire les champs sensibles sans les clés**. Chiffrement applicatif avec **une clé de données par entreprise**, elle-même protégée par Vault.

### Exigences visées

| Réf. | Intitulé |
|---|---|
| 2.5 | Chiffrement des données sensibles |
| Catalogue 5.5.3 | Chiffrement applicatif par entreprise |
| D-10 | Chiffrement en enveloppe |

### Hors périmètre

- TDE PostgreSQL (non disponible open source)
- Chiffrement des logs et backups → P10
- Chiffrement de `mfa_secret_package` (déjà chiffré via `ycc-mfa-key`, exception documentée)

---

## 2. État existant

### 2.1 — VaultTransitService

- Fonctionne (MfaServiceIT 4/4)
- **Mono-clé** : `ycc-mfa-key` en dur dans `VaultProperties`
- Signature : `encrypt(String)` / `decrypt(String)` — pas de paramètre tenant

### 2.2 — Vault

| Élément | État |
|---|---|
| Mode | `-dev` (mémoire) |
| Moteur Transit | ✅ Monté |
| Clé `ycc-mfa-key` | ✅ v1 (AES-256-GCM) |
| Clés par tenant | ❌ Aucune |
| Script init | ✅ `scripts/init-vault.sh` |

### 2.3 — Tables concernées

**`users`** :
- `mfa_secret_package` JSONB — chiffré via `ycc-mfa-key` (V14)
- `telephone` VARCHAR(30) — **non chiffré**
- `email` CITEXT — **non chiffré** (login + lookup)

**`tiers`** :
- `ifu`, `rccm`, `telephone` — **non chiffrés**
- `conditions_reglement` TEXT — **non chiffré**
- `email` CITEXT — **non chiffré** (lookup)

---

## 3. Problèmes identifiés

### 3.1 — P4-1 : VaultTransitService mono-clé
Une seule clé pour tous les chiffrements → viole D-10.

### 3.2 — P4-2 : Aucune table `cles_tenant`
Impossible de stocker plusieurs clés de données enveloppées.

### 3.3 — P4-3 : Aucune empreinte HMAC
Recherche impossible sur `ifu`, `rccm`, `telephone`, `email`.

### 3.4 — P4-4 : Champs sensibles en clair
Exposition données fiscales, bancaires, personnelles.

### 3.5 — P4-5 : Rotation non implémentée
Pas de mécanisme de rotation sans interruption.

### 3.6 — P4-6 : Vault `-dev` non persistant
Restart accidentel = données perdues.

### 3.7 — P4-7 (C40) : `db_user=postgres`
Contourne ADR-033. Un superuser peut lire `cles_tenant` + Vault → déchiffrer.

**Nouveaux constats intégrés (version 1.1)** :

### 3.8 — P4-8 : `email` non traité
`email` est utilisé pour login et lookup. Non chiffré et **non couvert par HMAC** → recherche par email reste en clair dans les logs de requête et les copies de base.

### 3.9 — P4-9 : Aucune normalisation HMAC
`" 123-456 "` vs `"123456"` produisent 2 HMAC différents → recherche cassée.

### 3.10 — P4-10 : Mécanisme de rotation non décrit
« Rechiffrement progressif » sans préciser : in-place, double lecture, fenêtre d'écriture ?

### 3.11 — P4-11 : Cache de clé non tranché
Appel Vault à chaque déchiffrement → latence × 10. Cache nécessaire mais non décidé.

### 3.12 — P4-12 : Garde-fou Vault `-dev` absent
Aucune validation au démarrage empêche `prod` de tourner avec Vault `-dev`.

### 3.13 — P4-13 : Journalisation des lectures absente
ADR-032 exige la traçabilité de chaque lecture de champ chiffré. `DataEncryptionService` ne journalise pas.

### 3.14 — P4-14 : Privilèges `cles_tenant` non spécifiés
Un SELECT large permet d'énumérer les versions de clés (metadata sensible).

---

## 4. Décisions

### D-P4-1 — Format de clé enveloppée : **A — Vault Transit `datakey`**

Clé AES-256 générée par Vault, stockée `wrapped` dans `cles_tenant`.

### D-P4-2 — Format ciphertext : **A — `vault:v<N>:<base64>`**

**Clarification (écart 4.1)** : le préfixe `vault:v1:` signifie **version de clé Vault**, pas version de schéma applicatif. Si le format applicatif doit évoluer, un **préfixe applicatif** sera ajouté : `v1:vault:v1:...`.

### D-P4-3 — Emplacement HMAC : **A — colonnes dédiées**

**Version 1.1 corrigée** : 4 colonnes HMAC par table concernée.

| Table | Colonnes HMAC |
|---|---|
| `tiers` | `ifu_hmac`, `rccm_hmac`, `telephone_hmac`, **`email_hmac`** |
| `users` | `telephone_hmac`, **`email_hmac`** |

### D-P4-4 — Clé HMAC : **A — clé distincte par tenant**

**Précision (écart 3.4)** :
- Clé HMAC générée via **Vault Transit `datakey`** (même mécanisme que la clé de données)
- Stockée `wrapped` dans `cles_tenant` avec `type_clé='HMAC'`
- Clé maîtresse : `ycc-master-key`
- **Séparation stricte** : `type_clé = 'DATA'` ou `'HMAC'`, jamais la même

### D-P4-5 — Rotation : **A — manuelle, double lecture**

**Mécanisme détaillé (écart 2.4)** :

1. **Création** : nouvelle version (`version=2`, `statut='ACTIVE'`), ancienne passe `statut='DEPRECATED'`
2. **Écriture** : nouvelle écriture → version 2
3. **Lecture** : détection du préfixe `vault:v1:` → déchiffrement avec version 1 (encore lisible) ; `vault:v2:` → version 2
4. **Rechiffrement progressif** : batch `UPDATE tiers SET ifu = encrypt(decrypt(ifu, v1), v2), ifu_hmac = hmac(decrypt(ifu, v1))` — par lots de 1000 lignes
5. **Clôture** : après 100 % rechiffré → ancienne version `statut='REVOKED'`

**Aucune fenêtre de double écriture** : chaque valeur est écrite une seule fois dans la nouvelle version.

### D-P4-6 — Vault : **A en prod, B en dev + garde-fou**

**Garde-fou (écart 2.6)** — ajout d'un `VaultStartupGuard` :

```java
@Component
public class VaultStartupGuard {
    @Value("${spring.profiles.active:}") private String profile;
    @Value("${ycc.vault.mode:dev}") private String mode;

    @PostConstruct
    void check() {
        if ("prod".equals(profile) && "dev".equals(mode)) {
            throw new IllegalStateException(
                "Vault en mode -dev interdit en production. " +
                "Configurer ycc.vault.mode=prod et un backend persistant.");
        }
    }
}
```

### D-P4-7 — Cache de clé (nouveau, écart 2.5)

| Option | Avantages | Inconvénients |
|---|---|---|
| **A — Caffeine in-process** | Ultra-rapide (< 1 µs), TTL configurable, isolation tenant par clé de cache | Cache à invalider sur rotation manuelle ; 1 cache par instance (pas partagé) |
| **B — Redis** | Partagé entre instances, invalidation centralisée | Appel réseau (~1 ms), dépendance Redis déjà là |

**Décision : A — Caffeine in-process.**

- **Clé de cache** : `(tenantId, keyType, version)` → `dataKey` déchiffrée
- **TTL** : 5 minutes
- **Invalidation** : sur rotation manuelle, `cache.invalidateAll(tenantId)`
- **Isolation** : `Cache<String tenantId, DataKey>` — pas de fuite cross-tenant
- **Sécurité** : les clés sont en mémoire → cohérent avec l'usage (elles finissent par être chargées en RAM de toute façon)

### D-P4-8 — Correction C40 (nouveau, écart 2.7)

**Décision : OUI, corriger C40 en P4 L0 (avant L1).**

**Raison** : sans correction, un admin PostgreSQL peut :
1. Lire `cles_tenant.cle_wrapped`
2. Lire `VAULT_TOKEN` dans les variables d'environnement du backend
3. Appeler Vault avec ce token → déchiffrer toutes les clés
4. Déchiffrer toute la base

**Fix** :
- Créer le rôle `ycc_tenant_app` (déjà présent) + rôle `ycc_control_plane_app` pour le control plane
- Modifier `MultiTenantConnectionProviderImpl` : `this.dbUser = cfg.getDbUser()` au lieu de `"postgres"`
- Le mot de passe de `ycc_tenant_app` est dans Vault KV (`secret/tenants/{id}/db`)
- Le token Vault n'a que les permissions `transit/encrypt|decrypt` — pas `sys/`, pas `secret/` global

**Voir aussi** : fiche P4-L0 détaillée.

### D-P4-9 — Fail-closed / fail-soft sur Vault indisponible (nouveau, écart 3.3)

**Décision** :
- **Champs sensibles** (`ifu`, `rccm`, `telephone`, `conditions_reglement`, `email` métier) : **fail-closed**. Si Vault est KO → exception `EncryptionUnavailableException` → API retourne 503.
- **Champs non sensibles** (`raison_sociale`, `nom_commercial`, etc.) : **fail-soft**. Le champ n'est pas chiffré, aucun impact.
- **`mfa_secret_package`** : **fail-closed**. Pas de MFA si Vault KO → sécurité d'abord.

**Justification** : une copie de base sans Vault doit retourner des erreurs, pas des ciphertexts bruts.

### D-P4-10 — mfa_secret_package : exception documentée (écart 3.2)

**Décision** : `mfa_secret_package` **reste chiffré via `ycc-mfa-key`**.

**Raison** :
- Séparation des préoccupations : MFA = clé dédiée, isolée du reste
- Migration risquée : changer la clé MFA casserait les TOTP actifs
- Documenté comme exception dans l'ADR-040

**Non couvert par le mécanisme par tenant** : c'est la seule exception du système.

### D-P4-11 — Journalisation des lectures (nouveau, écart 4.2)

**Décision : OUI, journaliser chaque lecture dans `audit_log`.**

**Mécanisme** :
- `DataEncryptionService.decrypt(...)` appelle `CentralAuditService.persist()` avec `OperationCritique.LECTURE_CHAMP_SENSIBLE`
- **Fail-closed strict** (aligné N-2) : si l'audit échoue, la lecture est refusée
- Inclut : `tenantId`, `userId` (issu de `SecurityContext`), `field`, `table`, `recordId`, `timestamp`
- **Ne journalise jamais** : `plaintext`, `dataKey`, `cle_wrapped`
- **Volume** : batch `async` possible en P8 (mais fail-closed en P4)

**Coût** : chaque lecture = 1 INSERT + 1 UPDATE chaînage. Acceptable pour `ifu`, `rccm`, `telephone`. **Attention** : `conditions_reglement` peut être lu souvent → limiter aux champs strictement nécessaires.

### D-P4-12 — Privilèges `cles_tenant` (nouveau, écart 4.3)

**Décision** :
- **SELECT** : réservé au rôle `ycc_encryption_app` (dédié) — pas `ycc_control_plane_app`
- **INSERT** : réservé au rôle `ycc_key_rotation_app` (service de rotation)
- **UPDATE** : réservé à `ycc_key_rotation_app` (changement de statut uniquement)
- **DELETE** : **aucun rôle** — jamais de suppression de clé (statut `REVOKED` à la place)
- **REVOKE** explicite de `ycc_control_plane_app` dans V9

**Complément** : pas de colonne `cle_en_clair` — uniquement `cle_wrapped`.

---

## 5. Solution retenue

### 5.1 — Normalisation avant HMAC

**Règle par champ** :

| Champ | Normalisation |
|---|---|
| `email` | `trim()` + `toLowerCase()` (RFC 5321 : email techniquement case-sensitive local part, mais la pratique générale est case-insensitive) |
| `ifu` | `trim()` + suppression espaces/tirets/points + `toUpperCase()` |
| `rccm` | `trim()` + suppression espaces/tirets/points + `toUpperCase()` |
| `telephone` | `trim()` + suppression espaces/tirets/points/parenthèses + suppression préfixe `+226`/`00226` |

**Implémentation** : `HmacService.normalize(field, value)` appliqué **avant** `HMAC-SHA256(normalisé, clé)`.

**Exemples** :
```
email : "  Alice@Example.COM " → "alice@example.com"
ifu   : " 123-456 "            → "123456"
ifu   : "123.456"              → "123456"
tel   : "+226 70-12-34-56"     → "70123456"
tel   : "(+226)70123456"       → "70123456"
```

**Colonne stockée** : toujours la valeur normalisée dans `*_hmac`. La valeur en clair (chiffrée) garde le format saisi.

### 5.2 — Architecture

```
┌──────────────────────────────────────────────────────┐
│  Application                                         │
│                                                      │
│  ┌─────────────────────┐   ┌─────────────────────┐  │
│  │DataEncryptionService│───│ VaultTransitService │  │
│  │ (orchestration)     │   │ (multi-clés)        │  │
│  │ + audit log         │   └──────────┬──────────┘  │
│  │ + cache Caffeine    │              │             │
│  └──────────┬──────────┘              │             │
│             │                          │             │
│             ▼                          ▼             │
│  ┌─────────────────────┐   ┌─────────────────────┐  │
│  │ClesTenantRepository │   │ Vault Transit       │  │
│  │                     │   │ (master key)        │  │
│  └──────────┬──────────┘   └─────────────────────┘  │
│             │                                        │
│  ┌──────────▼──────────┐                            │
│  │ HmacService         │                            │
│  │ (normalisation)     │                            │
│  └─────────────────────┘                            │
└─────────────┬────────────────────────────────────────┘
              │
              ▼
┌──────────────────────────────────────────────────────┐
│  Control Plane                                       │
│  cles_tenant                                         │
│  (tenant_id, version, cle_wrapped, type_clé, statut) │
└──────────────────────────────────────────────────────┘
```

### 5.3 — Migrations

**V9 (control plane)** :
- Table `cles_tenant`
- Rôles : `ycc_encryption_app`, `ycc_key_rotation_app`
- GRANT SELECT / INSERT / UPDATE selon D-P4-12
- Trigger `BEFORE DELETE` → `RAISE EXCEPTION` (pas de suppression)

**V18 (tenant)** :
- `tiers` : `ifu_hmac`, `rccm_hmac`, `telephone_hmac`, `email_hmac` VARCHAR(64) + 4 index B-tree
- `users` : `telephone_hmac`, `email_hmac` VARCHAR(64) + 2 index B-tree
- Contrainte `UNIQUE(email_hmac)` sur `users` et `tiers` (remplace `UNIQUE(email)` actuel — le chiffré reste non unique, l'unicité migre sur le HMAC)

---

## 6. Justifications

### Normalisation (écart 2.2)
Sans normalisation, deux utilisateurs saisissant `" 123-456 "` et `"123456"` produisent 2 HMAC différents. La recherche par HMAC **ne fonctionne pas** sans cette règle.

### Double lecture pendant rotation (écart 2.4)
- **In-place pur** : pic de charge, downtime partiel
- **Fenêtre de double écriture** : complexité applicative
- **Double lecture** : transparent, pas de pic, batch progressif

Choix **double lecture** : chaque valeur a une seule version à un instant donné, mais **le lecteur accepte les deux** pendant la transition.

### Cache Caffeine (écart 2.5)
Sans cache : chaque lecture d'`ifu` = 2 appels Vault (~2-5 ms) × N lignes affichées = latence × 10. Cache TTL 5 min → coût réseau amorti, 1 seul appel Vault par (tenant, version).

### Garde-fou Vault `-dev` (écart 2.6)
Un développeur qui démarre en `prod` par erreur avec `-dev` perd toutes les données au prochain restart. Le garde-fou **empêche** ce démarrage.

### Correction C40 (écart 2.7)
Le chiffrement est **inutile** si un superuser peut lire les clés. La correction C40 est **prérequis** à P4.

### Journalisation (écart 4.2)
ADR-032 exige la traçabilité. Sans journalisation, un admin peut lire `ifu` d'un tiers sans laisser de trace → non conforme.

### Privilèges `cles_tenant` (écart 4.3)
Énumérer les versions de clés permet de détecter une rotation récente (fenêtre d'attaque). Restreindre l'accès à un rôle dédié réduit la surface.

---

## 7. Modules impactés

### Base tenant (V18)
- `tiers` : +4 colonnes HMAC, +4 index, contrainte `UNIQUE(email_hmac)`
- `users` : +2 colonnes HMAC, +2 index, contrainte `UNIQUE(email_hmac)`

### Base control plane (V9)
- **Nouvelle table** : `cles_tenant`
- **Nouveaux rôles** : `ycc_encryption_app`, `ycc_key_rotation_app`

### Backend — modifiés
- `VaultTransitService` : +`encrypt(plaintext, tenantCode, field)`, +`decrypt(ciphertext, tenantCode)`
- `VaultProperties` : +`masterKey`
- `MultiTenantConnectionProviderImpl` : **correction C40** (db_user depuis `tenant_databases`)
- `UserRepository` : +`findByEmailHmac`, +`findByTelephoneHmac`
- `TiersRepository` : +`findByIfuHmac`, +`findByRccmHmac`, +`findByEmailHmac`

### Backend — nouveaux
- `DataEncryptionService` : orchestration + audit + cache
- `HmacService` : normalisation + HMAC
- `ClesTenantRepository`
- `EncryptionKeyRotationService`
- `VaultStartupGuard`
- `DataKeyCacheConfig` (Caffeine)

### API
- `POST /api/admin/encryption/rotate` (Superadmin, protégé par `@RequireDroitSpecial`)
- `GET /api/admin/encryption/status/{tenantId}` (Superadmin)

### Frontend
- Page "Paramètres → Chiffrement" (Superadmin)
- Bandeau d'avertissement si `Vault indisponible`

### Tests (5 nouveaux IT)
- `DataEncryptionServiceIT` — round-trip + fail-closed Vault KO
- `EncryptionKeyRotationIT` — double lecture
- `HmacServiceIT` — normalisation + collision
- `EncryptionMigrationIT` — reprise des données
- `ClesTenantRepositoryIT` — versioning + unicité
- `VaultStartupGuardIT` — refus démarrage

### Documentation
- ADR-040 : chiffrement en enveloppe multi-tenant
- ADR-041 : rotation manuelle à double lecture
- ADR-042 : HMAC + normalisation
- ADR-043 : cache de clé Caffeine

---

## 8. Preuves prévues

### Critère de sortie
> Une copie de la base ou d'une sauvegarde ne permet pas de lire les champs chiffrés.

### Preuves

| Preuve | Méthode |
|---|---|
| Copie base illisible | `pg_dump` → `ifu` = `vault:v1:...` |
| Chiffrement round-trip | `DataEncryptionServiceIT` |
| Clé par tenant | `encrypt("A", t1) != encrypt("A", t2)` |
| Rotation sans perte | `EncryptionKeyRotationIT` (double lecture) |
| Normalisation HMAC | `hmac(" 123-456 ") == hmac("123456")` |
| Fail-closed Vault KO | `DataEncryptionServiceIT` avec mock Vault KO → 503 |
| Journalisation | `audit_log` contient `LECTURE_CHAMP_SENSIBLE` |
| Garde-fou prod | `VaultStartupGuardIT` : démarrage refuse |
| C40 corrigé | `SELECT current_user` sur tenant = `ycc_tenant_app` |
| Privilèges `cles_tenant` | `information_schema.role_table_grants` |

---

## 9. Points à valider avant L1

| Réf. | Objet | Statut |
|---|---|---|
| **P-04** | Liste champs sensibles (email inclus) | ✅ Validée (3.1) |
| **D-P4-1** | Vault datakey | À valider |
| **D-P4-2** | Format `vault:v<N>:` | À valider |
| **D-P4-3** | Colonnes HMAC (4 champs × 2 tables) | À valider |
| **D-P4-4** | Clé HMAC distincte via datakey | À valider |
| **D-P4-5** | Rotation double lecture | À valider |
| **D-P4-6** | Garde-fou prod | À valider |
| **D-P4-7** | Cache Caffeine | À valider |
| **D-P4-8** | Correction C40 en P4 L0 | À valider |
| **D-P4-9** | Fail-closed / fail-soft | ✅ Validée (3.3) |
| **D-P4-10** | mfa_secret_package exception | ✅ Validée (3.2) |
| **D-P4-11** | Journalisation lectures | À valider |
| **D-P4-12** | Privilèges `cles_tenant` | À valider |

---

## 10. Validation

| Critère (annexe B) | État |
|---|---|
| 8 rubriques renseignées | ✅ |
| Au moins 2 options par décision | ✅ 12 décisions |
| Constats, décisions, ADR cités | ✅ |
| Liste des preuves explicite | ✅ |
| Validation auteur | En attente |
| Prise de connaissance encadreur | En attente |

---

**Fin de la fiche d'analyse Phase 4**

| Champ | Valeur |
|---|---|
| Version | 1.1 |
| Date | 19 octobre 2026 |
| Auteur | Yameogo Idrissa |
| Corrections intégrées | 7 points + 4 compléments + 3 écarts |