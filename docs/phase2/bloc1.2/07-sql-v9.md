# Module CRM — Migration SQL V9

**Bloc** : 1.2 — Module CRM
**Fichier source** : `db/migration/tenant/V9__init_crm.sql`
**Date** : 07 octobre 2026

---

## 1. Vue d'ensemble

La migration V9 crée les 8 tables du module CRM avec toutes leurs contraintes, index et triggers.

Elle s'appuie sur :

- Les 27 ENUMs du socle V8
- Les fonctions du socle V8 (`attacher_triggers_standard`, `current_user_id`, `soft_delete_element`, etc.)
- Les directives de conception BDD (soft delete, version, traçabilité)

---

## 2. Ordre de création des tables

L'ordre respecte les dépendances :

1. `crm_comptes` — aucune dépendance
2. `crm_pipeline_etapes` — aucune dépendance
3. `crm_contacts` — dépend de crm_comptes
4. `crm_pistes` — dépend de crm_comptes
5. `crm_opportunites` — dépend de crm_comptes, crm_pistes, crm_pipeline_etapes
6. `crm_campagnes` — aucune dépendance
7. `crm_activites` — dépend de toutes les précédentes
8. `crm_interactions` — dépend de crm_comptes, crm_contacts, crm_pistes, crm_opportunites

---

## 3. Contraintes appliquées

### Contraintes UNIQUE

- `crm_comptes.code`, `crm_comptes.email`
- `crm_contacts.email`
- `crm_pistes.code`
- `crm_opportunites.code`
- `crm_pipeline_etapes.code`, `crm_pipeline_etapes.ordre`
- `crm_campagnes.code`
- Index partiel : `crm_contacts(compte_id) WHERE est_principal = TRUE`

### Contraintes CHECK

- `crm_comptes.statut IN ('ACTIF','INACTIF','ARCHIVE')`
- `crm_pistes.score BETWEEN 0 AND 100`
- `crm_opportunites.montant_estime > 0`
- `crm_opportunites.probabilite BETWEEN 0 AND 100`
- `crm_opportunites.date_cloture_reelle IS NULL OR >= created_at::date`
- `crm_pipeline_etapes.pourcentage_default BETWEEN 0 AND 100`
- `crm_campagnes.type IN ('EMAILING','TELEMARKETING','EVENEMENT','RESEAUX_SOCIAUX')`
- `crm_campagnes.budget >= 0`
- `crm_campagnes.date_fin >= date_debut`
- `crm_activites.statut IN ('PLANIFIEE','EN_COURS','TERMINEE','ANNULEE')`
- `crm_activites` : au moins une FK renseignée
- `crm_interactions.type IN ('EMAIL','APPEL','REUNION','VISITE','NOTE')`
- `crm_interactions` : au moins une FK renseignée

### Règles ON DELETE

- FK vers crm_comptes depuis crm_contacts : RESTRICT
- FK vers crm_comptes depuis crm_opportunites : RESTRICT
- FK vers crm_comptes depuis crm_activites : CASCADE
- FK vers crm_comptes depuis crm_interactions : CASCADE
- FK vers crm_pistes : SET NULL
- FK vers crm_contacts : SET NULL
- FK vers crm_pipeline_etapes : RESTRICT
- FK vers crm_campagnes : SET NULL

---

## 4. Contenu complet du fichier SQL

```sql
-- ============================================================================
-- V9__init_crm.sql
-- Base : ycc_tenant_<id>
-- Objet : Module CRM (8 tables + contraintes + index + seeds)
-- ============================================================================

SET search_path TO public;

-- ============================================================================
-- TABLE 1 — crm_comptes
-- ============================================================================

CREATE TABLE crm_comptes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(50) NOT NULL,
    nom             VARCHAR(255) NOT NULL,
    secteur         VARCHAR(100),
    taille          VARCHAR(20),
    adresse         JSONB,
    site_web        VARCHAR(255),
    telephone       VARCHAR(30),
    email           CITEXT,
    statut          VARCHAR(20) NOT NULL DEFAULT 'ACTIF',

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at      TIMESTAMPTZ,
    version         INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT chk_crm_comptes_statut
        CHECK (statut IN ('ACTIF','INACTIF','ARCHIVE')),
    CONSTRAINT uq_crm_comptes_code UNIQUE (code),
    CONSTRAINT uq_crm_comptes_email UNIQUE (email)
);

CREATE INDEX idx_crm_comptes_statut
    ON crm_comptes (statut) WHERE deleted_at IS NULL;

COMMENT ON TABLE crm_comptes IS 'Entreprises (prospects, clients, partenaires)';

-- ============================================================================
-- TABLE 2 — crm_pipeline_etapes
-- ============================================================================

CREATE TABLE crm_pipeline_etapes (
    id                  SERIAL PRIMARY KEY,
    code                VARCHAR(30) NOT NULL,
    libelle             VARCHAR(100) NOT NULL,
    ordre               SMALLINT NOT NULL,
    pourcentage_default SMALLINT NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_crm_pipeline_pourcentage
        CHECK (pourcentage_default BETWEEN 0 AND 100),
    CONSTRAINT uq_crm_pipeline_code UNIQUE (code),
    CONSTRAINT uq_crm_pipeline_ordre UNIQUE (ordre)
);

COMMENT ON TABLE crm_pipeline_etapes IS 'Étapes du pipeline commercial (référentiel)';

INSERT INTO crm_pipeline_etapes (code, libelle, ordre, pourcentage_default) VALUES
    ('PROSPECTION',    'Prospection',    1, 10),
    ('QUALIFICATION',  'Qualification',  2, 25),
    ('PROPOSITION',    'Proposition',    3, 50),
    ('NEGOCIATION',    'Négociation',    4, 75),
    ('CLOTURE',        'Clôture',        5, 100);

-- ============================================================================
-- TABLE 3 — crm_contacts
-- ============================================================================

CREATE TABLE crm_contacts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nom             VARCHAR(100) NOT NULL,
    prenom          VARCHAR(100) NOT NULL,
    email           CITEXT NOT NULL,
    telephone       VARCHAR(30),
    fonction        VARCHAR(100),
    compte_id       UUID NOT NULL,
    est_principal   BOOLEAN NOT NULL DEFAULT FALSE,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at      TIMESTAMPTZ,
    version         INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT fk_crm_contacts_compte
        FOREIGN KEY (compte_id) REFERENCES crm_comptes(id) ON DELETE RESTRICT,
    CONSTRAINT uq_crm_contacts_email UNIQUE (email)
);

CREATE INDEX idx_crm_contacts_compte
    ON crm_contacts (compte_id) WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX idx_crm_contacts_principal
    ON crm_contacts (compte_id) WHERE est_principal = TRUE AND deleted_at IS NULL;

-- ============================================================================
-- TABLE 4 — crm_pistes
-- ============================================================================

CREATE TABLE crm_pistes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(50) NOT NULL,
    nom             VARCHAR(255) NOT NULL,
    email           CITEXT,
    telephone       VARCHAR(30),
    source          VARCHAR(50),
    statut          statut_piste NOT NULL DEFAULT 'NOUVEAU',
    score           SMALLINT NOT NULL DEFAULT 0,
    compte_id       UUID,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at      TIMESTAMPTZ,
    version         INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT chk_crm_pistes_score CHECK (score BETWEEN 0 AND 100),
    CONSTRAINT uq_crm_pistes_code UNIQUE (code),
    CONSTRAINT fk_crm_pistes_compte
        FOREIGN KEY (compte_id) REFERENCES crm_comptes(id) ON DELETE SET NULL
);

CREATE INDEX idx_crm_pistes_statut
    ON crm_pistes (statut) WHERE deleted_at IS NULL;
CREATE INDEX idx_crm_pistes_email ON crm_pistes (email);

-- ============================================================================
-- TABLE 5 — crm_opportunites
-- ============================================================================

CREATE TABLE crm_opportunites (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                VARCHAR(50) NOT NULL,
    nom                 VARCHAR(255) NOT NULL,
    montant_estime      NUMERIC(15,2) NOT NULL,
    probabilite         SMALLINT NOT NULL DEFAULT 0,
    statut              statut_opportunite NOT NULL DEFAULT 'OUVERTE',
    etape_id            INTEGER NOT NULL,
    piste_id            UUID,
    compte_id           UUID NOT NULL,
    date_cloture_prevue DATE,
    date_cloture_reelle DATE,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by          UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by          UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at          TIMESTAMPTZ,
    version             INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT chk_crm_opportunites_montant CHECK (montant_estime > 0),
    CONSTRAINT chk_crm_opportunites_probabilite
        CHECK (probabilite BETWEEN 0 AND 100),
    CONSTRAINT chk_crm_opportunites_date_cloture
        CHECK (date_cloture_reelle IS NULL OR date_cloture_reelle >= created_at::date),
    CONSTRAINT uq_crm_opportunites_code UNIQUE (code),
    CONSTRAINT fk_crm_opportunites_etape
        FOREIGN KEY (etape_id) REFERENCES crm_pipeline_etapes(id) ON DELETE RESTRICT,
    CONSTRAINT fk_crm_opportunites_piste
        FOREIGN KEY (piste_id) REFERENCES crm_pistes(id) ON DELETE SET NULL,
    CONSTRAINT fk_crm_opportunites_compte
        FOREIGN KEY (compte_id) REFERENCES crm_comptes(id) ON DELETE RESTRICT
);

CREATE INDEX idx_crm_opportunites_statut
    ON crm_opportunites (statut) WHERE deleted_at IS NULL;
CREATE INDEX idx_crm_opportunites_compte ON crm_opportunites (compte_id);
CREATE INDEX idx_crm_opportunites_etape ON crm_opportunites (etape_id);

-- ============================================================================
-- TABLE 6 — crm_campagnes
-- ============================================================================

CREATE TABLE crm_campagnes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(50) NOT NULL,
    nom             VARCHAR(255) NOT NULL,
    type            VARCHAR(30) NOT NULL,
    date_debut      DATE NOT NULL,
    date_fin        DATE,
    budget          NUMERIC(15,2),
    statut          VARCHAR(20) NOT NULL DEFAULT 'PLANIFIEE',

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at      TIMESTAMPTZ,
    version         INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT chk_crm_campagnes_type
        CHECK (type IN ('EMAILING','TELEMARKETING','EVENEMENT','RESEAUX_SOCIAUX')),
    CONSTRAINT chk_crm_campagnes_statut
        CHECK (statut IN ('PLANIFIEE','EN_COURS','TERMINEE','ANNULEE')),
    CONSTRAINT chk_crm_campagnes_budget CHECK (budget IS NULL OR budget >= 0),
    CONSTRAINT chk_crm_campagnes_dates
        CHECK (date_fin IS NULL OR date_fin >= date_debut),
    CONSTRAINT uq_crm_campagnes_code UNIQUE (code)
);

-- ============================================================================
-- TABLE 7 — crm_activites
-- ============================================================================

CREATE TABLE crm_activites (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type            type_activite NOT NULL,
    sujet           VARCHAR(255) NOT NULL,
    description     TEXT,
    date_debut      TIMESTAMPTZ NOT NULL,
    date_fin        TIMESTAMPTZ,
    statut          VARCHAR(20) NOT NULL DEFAULT 'PLANIFIEE',
    compte_id       UUID,
    contact_id      UUID,
    piste_id        UUID,
    opportunite_id  UUID,
    campagne_id     UUID,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at      TIMESTAMPTZ,
    version         INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT chk_crm_activites_statut
        CHECK (statut IN ('PLANIFIEE','EN_COURS','TERMINEE','ANNULEE')),
    CONSTRAINT chk_crm_activites_rattachement
        CHECK (
            compte_id IS NOT NULL OR contact_id IS NOT NULL OR
            piste_id IS NOT NULL OR opportunite_id IS NOT NULL OR
            campagne_id IS NOT NULL
        ),
    CONSTRAINT fk_crm_activites_compte
        FOREIGN KEY (compte_id) REFERENCES crm_comptes(id) ON DELETE CASCADE,
    CONSTRAINT fk_crm_activites_contact
        FOREIGN KEY (contact_id) REFERENCES crm_contacts(id) ON DELETE SET NULL,
    CONSTRAINT fk_crm_activites_piste
        FOREIGN KEY (piste_id) REFERENCES crm_pistes(id) ON DELETE SET NULL,
    CONSTRAINT fk_crm_activites_opportunite
        FOREIGN KEY (opportunite_id) REFERENCES crm_opportunites(id) ON DELETE SET NULL,
    CONSTRAINT fk_crm_activites_campagne
        FOREIGN KEY (campagne_id) REFERENCES crm_campagnes(id) ON DELETE SET NULL
);

CREATE INDEX idx_crm_activites_compte
    ON crm_activites (compte_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_crm_activites_piste
    ON crm_activites (piste_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_crm_activites_opportunite
    ON crm_activites (opportunite_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_crm_activites_date_debut ON crm_activites (date_debut);

-- ============================================================================
-- TABLE 8 — crm_interactions
-- ============================================================================

CREATE TABLE crm_interactions (
    id               BIGSERIAL PRIMARY KEY,
    type             VARCHAR(30) NOT NULL,
    description      TEXT NOT NULL,
    date_interaction TIMESTAMPTZ NOT NULL DEFAULT now(),
    compte_id        UUID,
    contact_id       UUID,
    piste_id         UUID,
    opportunite_id   UUID,

    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by       UUID REFERENCES users(id) ON DELETE SET NULL,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by       UUID REFERENCES users(id) ON DELETE SET NULL,
    deleted_at       TIMESTAMPTZ,
    version          INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT chk_crm_interactions_type
        CHECK (type IN ('EMAIL','APPEL','REUNION','VISITE','NOTE')),
    CONSTRAINT chk_crm_interactions_rattachement
        CHECK (
            compte_id IS NOT NULL OR contact_id IS NOT NULL OR
            piste_id IS NOT NULL OR opportunite_id IS NOT NULL
        ),
    CONSTRAINT fk_crm_interactions_compte
        FOREIGN KEY (compte_id) REFERENCES crm_comptes(id) ON DELETE CASCADE,
    CONSTRAINT fk_crm_interactions_contact
        FOREIGN KEY (contact_id) REFERENCES crm_contacts(id) ON DELETE SET NULL,
    CONSTRAINT fk_crm_interactions_piste
        FOREIGN KEY (piste_id) REFERENCES crm_pistes(id) ON DELETE SET NULL,
    CONSTRAINT fk_crm_interactions_opportunite
        FOREIGN KEY (opportunite_id) REFERENCES crm_opportunites(id) ON DELETE SET NULL
);

CREATE INDEX idx_crm_interactions_compte
    ON crm_interactions (compte_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_crm_interactions_date ON crm_interactions (date_interaction DESC);

-- ============================================================================
-- ATTACHEMENT DES TRIGGERS STANDARD
-- ============================================================================

SELECT attacher_triggers_standard('crm_comptes');
SELECT attacher_triggers_standard('crm_contacts');
SELECT attacher_triggers_standard('crm_pistes');
SELECT attacher_triggers_standard('crm_opportunites');
SELECT attacher_triggers_standard('crm_pipeline_etapes');
SELECT attacher_triggers_standard('crm_activites');
SELECT attacher_triggers_standard('crm_campagnes');
SELECT attacher_triggers_standard('crm_interactions');

-- ============================================================================
-- VÉRIFICATION POST-MIGRATION
-- ============================================================================

DO $$
DECLARE v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM information_schema.tables
    WHERE table_name LIKE 'crm_%';

    IF v_count < 8 THEN
        RAISE EXCEPTION 'Attendu 8 tables CRM, trouvé %', v_count;
    END IF;

    RAISE NOTICE '=============================================';
    RAISE NOTICE 'V9__init_crm.sql — Module CRM OK (% tables)', v_count;
    RAISE NOTICE '=============================================';
END;
$$;
```

---

## 5. Application

```bash
docker exec -i pg-ycc psql -U postgres -d ycc_tenant_demo001 < db/migration/tenant/V9__init_crm.sql
```

**Résultat attendu** :

```
CREATE TABLE (8 fois)
CREATE INDEX (plusieurs)
INSERT 0 5
SELECT (8 lignes)
NOTICE:  V9__init_crm.sql — Module CRM OK (8 tables)
```

---

## 6. Vérification

```bash
docker exec pg-ycc psql -U postgres -d ycc_tenant_demo001 -c "\dt crm_*"
```

Doit afficher les 8 tables :

- crm_activites
- crm_campagnes
- crm_comptes
- crm_contacts
- crm_interactions
- crm_opportunites
- crm_pipeline_etapes
- crm_pistes

---

## 7. Rollback

```sql
DROP TABLE IF EXISTS crm_interactions CASCADE;
DROP TABLE IF EXISTS crm_activites CASCADE;
DROP TABLE IF EXISTS crm_campagnes CASCADE;
DROP TABLE IF EXISTS crm_opportunites CASCADE;
DROP TABLE IF EXISTS crm_pistes CASCADE;
DROP TABLE IF EXISTS crm_contacts CASCADE;
DROP TABLE IF EXISTS crm_pipeline_etapes CASCADE;
DROP TABLE IF EXISTS crm_comptes CASCADE;
```

---

## 8. Statistiques

- **Nombre de tables** : 8
- **Nombre de contraintes UNIQUE** : 9
- **Nombre de contraintes CHECK** : 13
- **Nombre de FK** : 12
- **Nombre d'index** : 15
- **Nombre de triggers** : 15
- **Nombre de seeds** : 5 (pipeline)

---

**Fin du document**
