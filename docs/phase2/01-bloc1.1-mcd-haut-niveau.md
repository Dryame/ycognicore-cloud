# Bloc 1.1 — MCD Haut Niveau

**Phase 2 · yCogniCore Cloud · 06 octobre 2026**

## Les 4 livrables

### Livrable 1 — Diagramme global des 7 modules

- **CRM** — Prospection, qualification, conversion (~8 tables)
- **Ventes** — Chaîne documentaire commerciale (~12 tables)
- **Achats** — Approvisionnement, 3-Way Matching (~10 tables)
- **Stocks** — Gestion physique des marchandises (~15 tables)
- **Comptabilité** — SYSCOHADA + Fiscalité BF (~15 tables)
- **Trésorerie** — Flux financiers (~8 tables)
- **Projets** — Suivi temps et rentabilité (~7 tables)

**Flux métier** : CRM → Ventes → Achats → Stocks → Comptabilité → Trésorerie → Projets.

### Livrable 2 — Matrice de dépendances (14 relations)

1. CRM → Ventes (Conversion)
2. CRM → Comptabilité (Référence)
3. Ventes → Stocks (Sortie)
4. Ventes → Comptabilité (Écriture auto)
5. Ventes → Trésorerie (Paiement)
6. Ventes → Projets (Facturation)
7. Achats → Stocks (Entrée)
8. Achats → Comptabilité (Écriture auto)
9. Achats → Trésorerie (Décaissement)
10. Stocks → Comptabilité (Valorisation)
11. Comptabilité ↔ Trésorerie (Rapprochement)
12. Projets → Comptabilité (Analytique)
13. Projets → Stocks (Consommation)
14. Projets → Trésorerie (Budget)

### Livrable 3 — 10 conventions transversales

1. Clé primaire UUID
2. Audit temporel (date_creation, date_maj, date_suppression)
3. Traçabilité utilisateur (created_by, updated_by)
4. Multi-tenant transparent (aucun tenant_id)
5. Clés étrangères RESTRICT par défaut
6. Numérotation légale via prochain_numero()
7. Statuts via ENUM PostgreSQL
8. Nommage snake_case
9. Contraintes CHECK obligatoires
10. Index sur FK + colonnes de recherche

### Livrable 4 — 27 types ENUM

- CRM (4) : statut_piste, statut_opportunite, type_activite, etape_pipeline
- Ventes (6) : statut_devis, statut_commande, statut_livraison, statut_facture, mode_paiement, statut_paiement
- Achats (4) : statut_demande_achat, statut_commande_fournisseur, statut_reception, statut_facture_fournisseur
- Stocks (3) : type_mouvement, type_inventaire, statut_inventaire
- Comptabilité (4) : type_journal, sens_ecriture, statut_lettrage, type_declaration
- Trésorerie (3) : type_compte, type_mouvement_tresorerie, statut_cheque
- Projets (3) : statut_projet, statut_tache, priorite_tache

## Livrable SQL

Le fichier `db/migration/tenant/V8__init_phase2_socle.sql` implémente les livrables 3 et 4 (27 ENUMs + fonctions transversales).
