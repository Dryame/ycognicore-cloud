# RBAC — Contrôle d'accès basé sur les rôles

**Fonctionnalité** : F-12 (log-only, H1) + F-14 (réel, H2)
**Sprint** : H1 → H2
**Date** : 01/10/2026 → 02/10/2026

---

## Vue d'ensemble

Le **RBAC** (Role-Based Access Control) de yCogniCore Cloud repose sur un modèle à **6 permissions fixes × 16 modules**, conformément à NFR-SEC-12.

| Élément | Valeur |
|---|---|
| Permissions | 6 (LIRE, CREER, MODIFIER, SUPPRIMER, VALIDER, EXPORTER) |
| Modules | 16 (Tableau de bord, CRM, Ventes, ...) |
| Stockage | Table `role_permissions` (tenant) |
| Vérification | `RbacService.hasPermission(userId, module, permission)` |
| Interception | `RbacInterceptor` + `@RequirePermission` |
| Statut | Réel (bloque avec HTTP 403) |

---

## Architecture

```
Controller → RbacInterceptor
                    │
                    ▼
            Lit @RequirePermission
                    │
                    ▼
              RbacService
                    │
                    ▼
          MultiTenantConnectionProvider
                    │
                    ▼
        tenant DB : role_permissions
                    │
                    ▼
            COUNT(*) > 0 ?
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
    Oui → 200           Non → 403
```

---

## Base de données (tenant)

### Table `role_permissions`

```sql
CREATE TABLE role_permissions (
    role_id       UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id INTEGER NOT NULL REFERENCES permissions(id) ON DELETE RESTRICT,
    module_id     INTEGER NOT NULL REFERENCES modules(id) ON DELETE RESTRICT,
    accordee_par  UUID REFERENCES users(id),
    date_attribution TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (role_id, permission_id, module_id)
);
```

### Table `permissions` (6 fixes)

```sql
INSERT INTO permissions (code, libelle) VALUES
    ('LIRE', 'Lire'),
    ('CREER', 'Créer'),
    ('MODIFIER', 'Modifier'),
    ('SUPPRIMER', 'Supprimer'),
    ('VALIDER', 'Valider'),
    ('EXPORTER', 'Exporter');
```

### Table `modules` (16)

```sql
INSERT INTO modules (code, libelle, ordre_affichage) VALUES
    ('TABLEAU_DE_BORD', 'Tableau de bord', 1),
    ('CRM', 'CRM', 2),
    ('VENTES', 'Ventes', 3),
    ('ACHATS', 'Achats', 4),
    ('CLIENTS', 'Clients', 5),
    ('FOURNISSEURS', 'Fournisseurs', 6),
    ('ARTICLES', 'Articles', 7),
    ('STOCK', 'Stock', 8),
    ('TRESORERIE', 'Trésorerie', 9),
    ('COMPTABILITE', 'Comptabilité & Fiscalité', 10),
    ('PROJETS', 'Projets', 11),
    ('NOTIFICATIONS', 'Notifications intelligentes', 12),
    ('RAPPORTS_BI', 'Rapports & Business Intelligence', 13),
    ('RECHERCHE', 'Recherche globale', 14),
    ('SAUVEGARDE', 'Sauvegarde', 15),
    ('PARAMETRES', 'Paramètres', 16);
```

---

## Code source

### Annotation `@RequirePermission`

```java
package bf.ycognicore.backend.security;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
public @interface RequirePermission {

    String module();

    String permission();
}
```

### Service `RbacService`

```java
package bf.ycognicore.backend.service;

import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
import bf.ycognicore.backend.multitenant.TenantContext;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.UUID;

@Service
public class RbacService {

    private static final Logger logger = LoggerFactory.getLogger(RbacService.class);

    private static final String SQL_CHECK = """
            SELECT COUNT(*) FROM user_roles ur
              JOIN role_permissions rp ON rp.role_id = ur.role_id
              JOIN modules m ON m.id = rp.module_id
              JOIN permissions p ON p.id = rp.permission_id
             WHERE ur.user_id = ?
               AND ur.statut = 'ACTIF'
               AND m.code = ?
               AND p.code = ?
            """;

    private final MultiTenantConnectionProviderImpl connectionProvider;

    public RbacService(MultiTenantConnectionProviderImpl connectionProvider) {
        this.connectionProvider = connectionProvider;
    }

    public boolean hasPermission(UUID userId, String moduleCode, String permissionCode) {
        String tenant = TenantContext.getTenantId();
        if (tenant == null) {
            logger.warn("hasPermission sans TenantContext (userId={})", userId);
            return false;
        }

        try (Connection conn = connectionProvider.getConnection(tenant);
             PreparedStatement ps = conn.prepareStatement(SQL_CHECK)) {

            ps.setObject(1, userId);
            ps.setString(2, moduleCode);
            ps.setString(3, permissionCode);

            try (ResultSet rs = ps.executeQuery()) {
                boolean ok = rs.next() && rs.getInt(1) > 0;
                logger.debug("hasPermission user={} module={} perm={} tenant={} -> {}",
                        userId, moduleCode, permissionCode, tenant, ok);
                return ok;
            }
        } catch (Exception e) {
            logger.error("Erreur hasPermission : {}", e.getMessage());
            return false;
        }
    }
}
```

### Interceptor `RbacInterceptor`

```java
package bf.ycognicore.backend.security;

import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.service.RbacService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.UUID;

@Component
public class RbacInterceptor implements HandlerInterceptor {

    private static final Logger logger = LoggerFactory.getLogger(RbacInterceptor.class);

    private final RbacService rbacService;

    public RbacInterceptor(RbacService rbacService) {
        this.rbacService = rbacService;
    }

    @Override
    public boolean preHandle(HttpServletRequest request,
                              HttpServletResponse response,
                              Object handler) throws Exception {

        if (!(handler instanceof HandlerMethod method)) {
            return true;
        }

        RequirePermission req = method.getMethodAnnotation(RequirePermission.class);
        if (req == null) {
            req = method.getBeanType().getAnnotation(RequirePermission.class);
        }
        if (req == null) {
            return true;
        }

        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Authentification requise");
            return false;
        }

        UUID userId;
        try {
            userId = UUID.fromString(auth.getName());
        } catch (Exception e) {
            logger.warn("RBAC: userId non-UUID {}", auth.getName());
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Identifiant invalide");
            return false;
        }

        boolean granted = rbacService.hasPermission(userId, req.module(), req.permission());

        if (!granted) {
            logger.warn("RBAC REFUSE : user={} module={} perm={} tenant={}",
                    userId, req.module(), req.permission(), TenantContext.getTenantId());
            response.sendError(HttpServletResponse.SC_FORBIDDEN,
                    "Permission manquante : " + req.module() + "." + req.permission());
            return false;
        }

        logger.info("RBAC ACCORDE : user={} module={} perm={} tenant={}",
                userId, req.module(), req.permission(), TenantContext.getTenantId());
        return true;
    }
}
```

### Configuration `WebMvcConfig`

```java
package bf.ycognicore.backend.config;

import bf.ycognicore.backend.security.RbacInterceptor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    private final RbacInterceptor rbacInterceptor;

    public WebMvcConfig(RbacInterceptor rbacInterceptor) {
        this.rbacInterceptor = rbacInterceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(rbacInterceptor)
                .addPathPatterns("/api/rbac-test/**")
                .excludePathPatterns(
                        "/api/auth/**",
                        "/api/_poc/**",
                        "/api/admin/partitions/**",
                        "/error"
                );
    }
}
```

---

## Utilisation

### Annoter un endpoint

```java
@GetMapping("/ventes/lire")
@RequirePermission(module = "VENTES", permission = "LIRE")
public ResponseEntity<?> ventesLire(Authentication auth) {
    return ResponseEntity.ok(Map.of("granted", true));
}
```

### Tester

```bash
# Login commercial (a VENTES.LIRE mais PAS COMPTABILITE.VALIDER)
TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"commercial@demo001.bf","password":"Test@2026!","tenantCode":"DEMO001"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

# Doit passer (200)
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/rbac-test/ventes/lire

# Doit être refusé (403)
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/rbac-test/comptabilite/valider
```

---

## Sécurité

| Aspect | Implémentation |
|---|---|
| **Isolation tenant** | Vérification via `MultiTenantConnectionProvider` |
| **Statut des rôles** | Filtre `ur.statut = 'ACTIF'` |
| **Retour 401** | Si non authentifié |
| **Retour 403** | Si permission manquante |
| **Log** | `RBAC ACCORDE` / `RBAC REFUSE` tracés |
| **Immuabilité** | Trigger `trg_permissions_immuables` (UPDATE/DELETE interdits) |

---

## Points reportés (H2+)

- **BL-013.1** : ✅ Implémenté en H2 J1
- **BL-013.2** : Application RBAC à tous les endpoints métier (Sprint H3)
- **BL-026** : Séparation des tâches (SoD) — Sprint H3

---

**Documentation RBAC v1.0 — 02/10/2026**

---

## Renforcement P1 — Migrations V15 et V16

**Date** : 13 octobre 2026
**Références** : ADR-032, ADR-033, constats C3 et C31
**Migrations** : V15, V16
**Commit** : 451528f

---

### V15 — Anti-TRUNCATE

Caractéristiques :

- Fonction : `forbid_truncate()` — RAISE EXCEPTION (ERRCODE 42501)
- Triggers créés : 10 (BEFORE TRUNCATE, niveau STATEMENT)
- Tables protégées : audit_log + 4 partitions + 5 tables append-only
- Révocation : REVOKE TRUNCATE ON audit_log FROM ycc_tenant_app
- Idempotence : oui
- Défensive : oui (tolère l'absence de tables)

Liste des tables append-only protégées :

- password_history — historique des mots de passe
- interactions — journal CRM
- opportunites_historique_etapes — historique pipeline
- documents_vente_historique_statuts — historique statuts Ventes
- audit_log — registre d'audit (parent + 4 partitions)

---

### V16 — RBAC strict

Liste des tables dont le privilège DELETE est révoqué :

- users — GRANT issu de V1 (ligne 235)
- roles — GRANT issu de V1 (ligne 235)
- role_permissions — GRANT issu de V1 (ligne 235)
- user_roles — GRANT issu de V1 (ligne 235)
- sessions_history — GRANT issu de V1 (ligne 235)
- numero_sequences — GRANT issu de V4 (ligne 98)
- user_invitations — GRANT issu de V4 (ligne 98)

Caractéristiques :

- Commande : REVOKE DELETE ON <table> FROM ycc_tenant_app
- Idempotence : oui (REVOKE est idempotent)
- Défensive : oui (tolère l'absence du rôle)
- Vérification : RAISE EXCEPTION si un GRANT DELETE subsiste

---

### Impact sur la matrice RBAC

Avant P1 :

- Permissions fixes : 6
- Modules RBAC : 16
- Tables avec DELETE accordé : 7
- Triggers anti-TRUNCATE : 0
- Tables protégées contre DELETE : 0

Après P1 :

- Permissions fixes : 6 (inchangé)
- Modules RBAC : 16 (inchangé)
- Tables avec DELETE accordé : 0
- Triggers anti-TRUNCATE : 10
- Tables protégées contre DELETE : 7

---

### Vérifications

Aucun GRANT DELETE résiduel — requête :

    SELECT COUNT(*) FROM information_schema.role_table_grants
    WHERE grantee = 'ycc_tenant_app' AND privilege_type = 'DELETE'
      AND table_name IN ('users','roles','role_permissions','user_roles',
                         'sessions_history','numero_sequences','user_invitations');

Résultat attendu : 0

TRUNCATE bloqué — commande :

    TRUNCATE audit_log;

Résultat attendu : ERROR: TRUNCATE interdit sur audit_log (protection append-only)

Résultats obtenus en production :

- ycc_tenant_demo001 : TRUNCATE bloqué, 0 GRANT DELETE résiduel
- ycc_tenant_demo002 : TRUNCATE bloqué, 0 GRANT DELETE résiduel

---

### Suivi

Extensions prévues :

- Sessions actives — Phase 3
- Appareils — Phase 3
- Droits spéciaux de console (D-11) — Phase 3
- Conservation des 6 permissions fixes — toutes phases
