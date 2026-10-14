# Modèle de fiche d'analyse préalable

**Référence** : planning prévisionnel v1.1, annexe B
**Usage** : une fiche par module ou changement structurel, à rédiger avant tout développement
**Longueur cible** : une page

---

## 1. Périmètre

- Module ou changement concerné
- Exigences de l'encadreur visées (axes 1 à 5)

## 2. État existant

- Ce qui existe déjà (code, tables, écrans)
- État vérifié (source, date, commit)

## 3. Problèmes identifiés

- Défauts constatés
- Manques
- Risques

## 4. Options

- Option A : description, avantages, inconvénients
- Option B : description, avantages, inconvénients
- (au moins deux options obligatoires)

## 5. Solution retenue

- Option choisie
- Alternatives écartées et raison

## 6. Justification technique

- Raisons du choix appuyées sur des faits vérifiés
- Références aux décisions (D-xx), aux constats (C-xx), aux ADR

## 7. Modules impactés

- Modules touchés
- Tables impactées
- API et écrans concernés
- Migrations nécessaires
- Tests à adapter ou à créer

## 8. Preuves prévues

- Tests automatiques
- Démonstrations
- Vérifications de sécurité
- Vérifications de non-régression

---

## Validation

Une fiche d'analyse est **complète** lorsque :
- Les 8 rubriques sont renseignées ;
- Au moins deux options ont été comparées ;
- Les références (constats, décisions, ADR) sont citées ;
- La liste des preuves est explicite.

Une fiche d'analyse est **validée** lorsque :
- L'auteur la valide ;
- L'encadreur en prend connaissance (pour les phases qui touchent au socle).
