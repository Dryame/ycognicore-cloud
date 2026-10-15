# Soumissions à l'encadreur — Phase 3

**Date** : 15 octobre 2026
**Auteur** : Yameogo Idrissa
**Phase** : P3 — Sécurité des accès, sessions, appareils et audit chaîné
**Objet** : 5 décisions nécessitant une validation formelle avant les lots concernés.

---

## P-01 — Seuils sessions / tokens / verrouillage

**Lot bloqué** : L3
**Décideur** : Encadreur

| Paramètre | Défaut | Minimum | Maximum |
|---|---|---|---|
| Sessions max par compte | 5 | 1 | 20 |
| Durée d'inactivité | 30 min | 5 min | 8 h |
| Durée absolue | 12 h | 1 h | 7 jours |
| Access token | 30 min | 5 min | 60 min |
| Refresh token | 7 jours | 1 h | 30 jours |
| Verrouillage | 15 min après 5 échecs | 5 min après 3 échecs | 60 min après 10 échecs |

**Règles** :
- Valeurs par défaut paramétrables par entreprise.
- Minimum et maximum imposés par la plateforme (superadmin uniquement).
- Modification tracée par audit.

**Demande** : valider les valeurs et les règles de modification.

---

## P-02 — Référence légale de la collecte d'IP

**Lot bloqué** : L4
**Décideur** : Encadreur

**Référence proposée** : loi n° 001-2021/AN du 30 mars 2021 (Burkina Faso).

**4 garde-fous** :
1. Base GeoIP locale (aucun envoi d'IP à un tiers).
2. Information de l'utilisateur (page « Confidentialité »).
3. Conservation limitée : 30 jours par défaut, paramétrable 7 à 90 jours.
4. Accès réservé aux administrateurs autorisés.

**Demande** : confirmer la référence légale et valider les 4 garde-fous.

---

## P-06 — Permission d'accès à la console

**Lot bloqué** : L5
**Décideur** : Encadreur

**Mécanisme proposé (D-11)** :
- Tables `droits_speciaux` et `role_droits_speciaux`.
- Attribution par l'administrateur du tenant.
- Les 6 permissions fixes RBAC restent intactes.

**Alternative écartée** : 7ᵉ permission (violerait la règle des 6 permissions fixes).

**Demande** : valider le mécanisme.

---

## N-4 — Point de contrôle d'audit

**Lot bloqué** : L2 (non bloquant — valeur déjà documentée, applicable immédiatement)
**Décideur** : Encadreur (confirmation administrative)

**Fréquence proposée** :
- Mensuelle à la clôture de chaque partition.
- Hebdomadaire intermédiaire.

**Rôle d'écriture dédié** : `ycc_audit_writer` (INSERT + SELECT uniquement sur `audit_checkpoints`).

**Limite documentée** : protège contre un administrateur de tenant, pas contre un administrateur de plateforme.

**Demande** : confirmer la fréquence et la limite documentée.

---

## D-13 — Stockage du jeton de renouvellement

**Lot bloqué** : L3
**Décideur** : Auteur et encadreur

**Choix proposé** :
- Jeton de renouvellement en cookie HttpOnly, Secure, SameSite=Strict, limité à `/api/auth`.
- Jeton d'accès en mémoire (perdu au rechargement → route de renouvellement = point de reprise de session).
- Jeton anti-CSRF obligatoire sur les requêtes sensibles.

**3 contraintes documentées** :
1. `SameSite=Strict` exige le même domaine enregistrable (dev : `Lax` + proxy local).
2. Anti-CSRF critique sur la route de renouvellement.
3. Tenant lu depuis la session serveur, jamais depuis `X-Tenant-Code`.

**Demande** : valider le choix et les contraintes.

---

## Récapitulatif

| Réf. | Objet | Lot bloqué | Décideur |
|---|---|---|---|
| P-01 | Seuils sessions/tokens/verrouillage | L3 | Encadreur |
| P-02 | Référence légale IP + garde-fous | L4 | Encadreur |
| P-06 | Permission console | L5 | Encadreur |
| N-4 | Point de contrôle (fréquence + rôle) | L2 (non bloquant) | Encadreur |
| D-13 | Cookie HttpOnly + 3 contraintes | L3 | Auteur + Encadreur |

**Fin du document**
