# F-14 à F-19 — Code source Sprint H2 (J1+J2)

## F-14 — RBAC réel (BL-013.1)

### service/RbacService.java

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

### security/RbacInterceptor.java

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

### controller/RbacRealTestController.java

```java
package bf.ycognicore.backend.controller;

import bf.ycognicore.backend.security.RequirePermission;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/rbac-test")
public class RbacRealTestController {

    @GetMapping("/ventes/lire")
    @RequirePermission(module = "VENTES", permission = "LIRE")
    public ResponseEntity<Map<String, Object>> ventesLire(Authentication auth) {
        return ResponseEntity.ok(Map.of(
                "endpoint", "rbac-test/ventes/lire",
                "requiresPermission", "VENTES.LIRE",
                "user", auth.getName(),
                "granted", true
        ));
    }

    @GetMapping("/comptabilite/valider")
    @RequirePermission(module = "COMPTABILITE", permission = "VALIDER")
    public ResponseEntity<Map<String, Object>> comptaValider(Authentication auth) {
        return ResponseEntity.ok(Map.of(
                "endpoint", "rbac-test/comptabilite/valider",
                "requiresPermission", "COMPTABILITE.VALIDER",
                "user", auth.getName(),
                "granted", true
        ));
    }
}
```

### config/WebMvcConfig.java

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

## F-15 — Refresh JWT (BL-011.1)

### dto/RefreshRequest.java

```java
package bf.ycognicore.backend.dto;

import jakarta.validation.constraints.NotBlank;

public record RefreshRequest(
        @NotBlank String refreshToken
) {}
```

### dto/RefreshResponse.java

```java
package bf.ycognicore.backend.dto;

public record RefreshResponse(
        String accessToken,
        String tokenType,
        long expiresInSeconds
) {}
```

### service/RefreshService.java

```java
package bf.ycognicore.backend.service;

import bf.ycognicore.backend.dto.RefreshResponse;
import bf.ycognicore.backend.entity.controlplane.SuperadminUser;
import bf.ycognicore.backend.entity.tenant.User;
import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.repository.controlplane.SuperadminUserRepository;
import bf.ycognicore.backend.repository.tenant.UserRepository;
import io.jsonwebtoken.Claims;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
public class RefreshService {

    private static final Logger logger = LoggerFactory.getLogger(RefreshService.class);

    private final JwtService jwtService;
    private final SuperadminUserRepository superadminRepo;
    private final UserRepository userRepo;

    public RefreshService(JwtService jwtService,
                          SuperadminUserRepository superadminRepo,
                          UserRepository userRepo) {
        this.jwtService = jwtService;
        this.superadminRepo = superadminRepo;
        this.userRepo = userRepo;
    }

    public RefreshResponse refresh(String refreshToken) {
        Claims claims;
        try {
            claims = jwtService.parseToken(refreshToken);
        } catch (Exception e) {
            throw new BadCredentialsException("Refresh token invalide ou expire");
        }

        String type = claims.get("type", String.class);
        if (!"refresh".equals(type)) {
            throw new BadCredentialsException("Token fourni n'est pas un refresh token");
        }

        String userId = claims.getSubject();
        if (userId == null || userId.isBlank()) {
            throw new BadCredentialsException("Refresh token sans subject");
        }

        UUID userUuid = UUID.fromString(userId);
        String tenantCode = TenantContext.getTenantId();

        if (tenantCode == null || tenantCode.isBlank()) {
            return refreshSuperadmin(userUuid);
        }
        return refreshTenantUser(userUuid, tenantCode);
    }

    private RefreshResponse refreshSuperadmin(UUID userId) {
        SuperadminUser sa = superadminRepo.findById(userId)
                .orElseThrow(() -> new BadCredentialsException("Superadmin introuvable"));

        if (!"ACTIF".equals(sa.getStatut())) {
            throw new BadCredentialsException("Compte non actif");
        }

        String access = jwtService.generateAccessToken(
                sa.getId().toString(), sa.getEmail(), "SUPERADMIN", null,
                List.of("ROLE_SUPERADMIN"));

        logger.info("Refresh SUPERADMIN OK pour {}", sa.getEmail());
        return new RefreshResponse(access, "Bearer", jwtService.getAccessTtlSeconds());
    }

    private RefreshResponse refreshTenantUser(UUID userId, String tenantCode) {
        User user = userRepo.findById(userId)
                .orElseThrow(() -> new BadCredentialsException("Utilisateur introuvable"));

        if (!"ACTIF".equals(user.getStatut())) {
            throw new BadCredentialsException("Compte non actif");
        }

        String userType = "EXTERNE".equals(user.getTypeUtilisateur()) ? "EXTERNE" : "INTERNE";

        String access = jwtService.generateAccessToken(
                user.getId().toString(), user.getEmail(), userType, tenantCode,
                List.of("ROLE_" + userType));

        logger.info("Refresh TENANT OK pour {} (tenant={})", user.getEmail(), tenantCode);
        return new RefreshResponse(access, "Bearer", jwtService.getAccessTtlSeconds());
    }
}
```

### controller/AuthController.java

```java
package bf.ycognicore.backend.controller;

import bf.ycognicore.backend.dto.LoginRequest;
import bf.ycognicore.backend.dto.LoginResponse;
import bf.ycognicore.backend.dto.RefreshRequest;
import bf.ycognicore.backend.dto.RefreshResponse;
import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.service.AuthDispatcherService;
import bf.ycognicore.backend.service.RefreshService;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private static final Logger logger = LoggerFactory.getLogger(AuthController.class);

    private final AuthDispatcherService authDispatcher;
    private final RefreshService refreshService;

    public AuthController(AuthDispatcherService authDispatcher,
                          RefreshService refreshService) {
        this.authDispatcher = authDispatcher;
        this.refreshService = refreshService;
    }

    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@Valid @RequestBody LoginRequest req) {
        return ResponseEntity.ok(authDispatcher.authenticate(req));
    }

    @PostMapping("/refresh")
    public ResponseEntity<RefreshResponse> refresh(@Valid @RequestBody RefreshRequest req) {
        String tenantCode = TenantContext.getTenantId();
        logger.info("Refresh demande (tenant={})", tenantCode != null ? tenantCode : "superadmin");
        return ResponseEntity.ok(refreshService.refresh(req.refreshToken()));
    }

    @GetMapping("/me")
    public ResponseEntity<Map<String, Object>> me(Authentication auth) {
        if (auth == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(Map.of(
                "userId", auth.getName(),
                "authenticated", auth.isAuthenticated(),
                "authorities", auth.getAuthorities()
        ));
    }
}
```

---

## F-16 — Distinction ADMIN/INTERNE/EXTERNE (BL-011.2)

### service/UserRoleLoader.java

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
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class UserRoleLoader {

    private static final Logger logger = LoggerFactory.getLogger(UserRoleLoader.class);

    private static final String SQL_ROLES = """
            SELECT r.nom
              FROM user_roles ur
              JOIN roles r ON r.id = ur.role_id
             WHERE ur.user_id = ?
               AND ur.statut = 'ACTIF'
            """;

    public static final String ROLE_ADMIN_CLIENT = "Administrateur Client";

    private final MultiTenantConnectionProviderImpl connectionProvider;

    public UserRoleLoader(MultiTenantConnectionProviderImpl connectionProvider) {
        this.connectionProvider = connectionProvider;
    }

    public List<String> loadRoles(UUID userId) {
        String tenant = TenantContext.getTenantId();
        if (tenant == null) {
            return List.of();
        }

        List<String> roles = new ArrayList<>();
        try (Connection conn = connectionProvider.getConnection(tenant);
             PreparedStatement ps = conn.prepareStatement(SQL_ROLES)) {

            ps.setObject(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    roles.add(rs.getString("nom"));
                }
            }
            logger.debug("Roles charges user={} tenant={} -> {}", userId, tenant, roles);
        } catch (Exception e) {
            logger.error("Erreur chargement roles user={} : {}", userId, e.getMessage());
        }
        return roles;
    }

    public boolean isAdminClient(List<String> roles) {
        return roles.stream().anyMatch(ROLE_ADMIN_CLIENT::equalsIgnoreCase);
    }
}
```

### service/AuthDispatcherService.java

```java
package bf.ycognicore.backend.service;

import bf.ycognicore.backend.dto.LoginRequest;
import bf.ycognicore.backend.dto.LoginResponse;
import bf.ycognicore.backend.dto.UserInfo;
import bf.ycognicore.backend.entity.controlplane.SuperadminUser;
import bf.ycognicore.backend.entity.tenant.User;
import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.repository.controlplane.SuperadminUserRepository;
import bf.ycognicore.backend.repository.tenant.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service
public class AuthDispatcherService {

    private static final Logger logger = LoggerFactory.getLogger(AuthDispatcherService.class);

    private final SuperadminUserRepository superadminRepo;
    private final UserRepository userRepo;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final UserRoleLoader userRoleLoader;

    public AuthDispatcherService(
            SuperadminUserRepository superadminRepo,
            UserRepository userRepo,
            PasswordEncoder passwordEncoder,
            JwtService jwtService,
            UserRoleLoader userRoleLoader
    ) {
        this.superadminRepo = superadminRepo;
        this.userRepo = userRepo;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.userRoleLoader = userRoleLoader;
    }

    public LoginResponse authenticate(LoginRequest req) {
        if (req.tenantCode() == null || req.tenantCode().isBlank()) {
            return authenticateSuperadmin(req);
        }
        return authenticateTenantUser(req);
    }

    private LoginResponse authenticateSuperadmin(LoginRequest req) {
        logger.debug("Auth SUPERADMIN email={}", req.email());

        SuperadminUser sa = superadminRepo.findByEmail(req.email())
                .orElseThrow(() -> new BadCredentialsException("Identifiants invalides"));

        if (!passwordEncoder.matches(req.password(), sa.getMotDePasseHash())) {
            throw new BadCredentialsException("Identifiants invalides");
        }
        if (!"ACTIF".equals(sa.getStatut())) {
            throw new BadCredentialsException("Compte non actif");
        }

        String accessToken = jwtService.generateAccessToken(
                sa.getId().toString(), sa.getEmail(), "SUPERADMIN", null,
                List.of("ROLE_SUPERADMIN"));
        String refreshToken = jwtService.generateRefreshToken(sa.getId().toString());

        UserInfo info = new UserInfo(
                sa.getId().toString(), sa.getEmail(), "SUPERADMIN", null,
                "/superadmin/dashboard");

        return new LoginResponse(accessToken, refreshToken, "Bearer",
                jwtService.getAccessTtlSeconds(), info);
    }

    private LoginResponse authenticateTenantUser(LoginRequest req) {
        String tenantCode = req.tenantCode().trim().toUpperCase();
        logger.debug("Auth TENANT={} email={}", tenantCode, req.email());

        TenantContext.setTenantId(tenantCode);
        try {
            User user = userRepo.findByEmail(req.email())
                    .orElseThrow(() -> new BadCredentialsException("Identifiants invalides"));

            if (!passwordEncoder.matches(req.password(), user.getMotDePasseHash())) {
                throw new BadCredentialsException("Identifiants invalides");
            }
            if (!"ACTIF".equals(user.getStatut())) {
                throw new BadCredentialsException("Compte non actif (" + user.getStatut() + ")");
            }

            List<String> roles = userRoleLoader.loadRoles(user.getId());
            String userType;
            String redirectUrl;

            if ("EXTERNE".equals(user.getTypeUtilisateur())) {
                userType = "EXTERNE";
                redirectUrl = "/portal/dashboard";
            } else if (userRoleLoader.isAdminClient(roles)) {
                userType = "ADMIN";
                redirectUrl = "/admin/dashboard";
            } else {
                userType = "INTERNE";
                redirectUrl = "/employee/dashboard";
            }

            List<String> jwtRoles = new ArrayList<>();
            jwtRoles.add("ROLE_" + userType);
            for (String role : roles) {
                jwtRoles.add("ROLE_" + role.toUpperCase().replace(" ", "_"));
            }

            String accessToken = jwtService.generateAccessToken(
                    user.getId().toString(), user.getEmail(), userType, tenantCode, jwtRoles);
            String refreshToken = jwtService.generateRefreshToken(user.getId().toString());

            UserInfo info = new UserInfo(
                    user.getId().toString(), user.getEmail(), userType, tenantCode,
                    redirectUrl);

            logger.info("Login OK user={} type={} tenant={} roles={}",
                    user.getEmail(), userType, tenantCode, jwtRoles);

            return new LoginResponse(accessToken, refreshToken, "Bearer",
                    jwtService.getAccessTtlSeconds(), info);
        } finally {
            TenantContext.clear();
        }
    }
}
```

---

## F-17 — Migration JSONB → JsonNode (BL-015.1)

### config/JacksonConfig.java

```java
package bf.ycognicore.backend.config;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class JacksonConfig {

    @Bean
    public ObjectMapper objectMapper() {
        ObjectMapper mapper = new ObjectMapper();
        mapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
        mapper.configure(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS, false);
        return mapper;
    }
}
```

### audit/AuditEvent.java

```java
package bf.ycognicore.backend.audit;

import com.fasterxml.jackson.databind.JsonNode;

import java.time.OffsetDateTime;
import java.util.UUID;

public record AuditEvent(
        UUID userId,
        String tenantCode,
        String action,
        String entite,
        String module,
        String niveau,
        boolean succes,
        String ip,
        String userAgent,
        JsonNode details,
        OffsetDateTime timestamp
) {}
```

### audit/AuditAspect.java

```java
package bf.ycognicore.backend.audit;

import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.service.AuditService;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import jakarta.servlet.http.HttpServletRequest;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.reflect.MethodSignature;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.time.OffsetDateTime;
import java.util.UUID;

@Aspect
@Component
public class AuditAspect {

    private static final Logger logger = LoggerFactory.getLogger(AuditAspect.class);

    private final AuditService auditService;
    private final ObjectMapper objectMapper;

    public AuditAspect(AuditService auditService, ObjectMapper objectMapper) {
        this.auditService = auditService;
        this.objectMapper = objectMapper;
    }

    @Around("@annotation(auditable)")
    public Object around(ProceedingJoinPoint pjp, Auditable auditable) throws Throwable {
        long start = System.currentTimeMillis();
        boolean succes = true;
        String erreur = null;

        try {
            return pjp.proceed();
        } catch (Throwable t) {
            succes = false;
            erreur = t.getClass().getSimpleName() + " : " + t.getMessage();
            throw t;
        } finally {
            try {
                AuditEvent event = buildEvent(pjp, auditable, succes, erreur,
                        System.currentTimeMillis() - start);
                auditService.persist(event);
            } catch (Exception e) {
                logger.warn("Audit non persiste : {}", e.getMessage());
            }
        }
    }

    private AuditEvent buildEvent(ProceedingJoinPoint pjp, Auditable a,
                                   boolean succes, String erreur, long dureeMs) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        UUID userId = null;
        if (auth != null && auth.getName() != null) {
            try { userId = UUID.fromString(auth.getName()); } catch (Exception ignored) {}
        }

        String ip = "0.0.0.0";
        String userAgent = "unknown";
        var attrs = RequestContextHolder.getRequestAttributes();
        if (attrs instanceof ServletRequestAttributes sra) {
            HttpServletRequest req = sra.getRequest();
            ip = req.getRemoteAddr();
            userAgent = req.getHeader("User-Agent");
            if (userAgent != null && userAgent.length() > 250) {
                userAgent = userAgent.substring(0, 250);
            }
        }

        ObjectNode details = objectMapper.createObjectNode();
        details.put("method", ((MethodSignature) pjp.getSignature()).getMethod().getName());
        details.put("dureeMs", dureeMs);
        if (erreur != null) {
            details.put("erreur", erreur);
        }

        return new AuditEvent(
                userId,
                TenantContext.getTenantId(),
                a.action(),
                a.entite(),
                a.module(),
                a.niveau(),
                succes,
                ip,
                userAgent,
                details,
                OffsetDateTime.now()
        );
    }
}
```

### service/AuditService.java

```java
package bf.ycognicore.backend.service;

import bf.ycognicore.backend.audit.AuditEvent;
import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
import bf.ycognicore.backend.multitenant.TenantContext;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.Timestamp;

@Service
public class AuditService {

    private static final Logger logger = LoggerFactory.getLogger(AuditService.class);

    private static final String SQL_INSERT = """
            INSERT INTO audit_log
                (user_id, action, entite, entite_id, timestamp, ip, user_agent,
                 niveau, succes, details)
            VALUES (?, ?, ?, NULL, ?, ?::inet, ?, ?, ?, ?::jsonb)
            """;

    private final MultiTenantConnectionProviderImpl connectionProvider;
    private final ObjectMapper objectMapper;

    public AuditService(MultiTenantConnectionProviderImpl connectionProvider,
                        ObjectMapper objectMapper) {
        this.connectionProvider = connectionProvider;
        this.objectMapper = objectMapper;
    }

    public void persist(AuditEvent event) {
        String tenant = TenantContext.getTenantId();
        if (tenant == null) {
            logger.debug("Audit ignore (pas de TenantContext) : {}", event.action());
            return;
        }

        String detailsJson = null;
        try {
            if (event.details() != null) {
                detailsJson = objectMapper.writeValueAsString(event.details());
            }
        } catch (Exception e) {
            logger.warn("Serialisation details audit echouee : {}", e.getMessage());
        }

        try (Connection conn = connectionProvider.getConnection(tenant);
             PreparedStatement ps = conn.prepareStatement(SQL_INSERT)) {

            ps.setObject(1, event.userId());
            ps.setString(2, event.action());
            ps.setString(3, event.entite());
            ps.setTimestamp(4, Timestamp.from(event.timestamp().toInstant()));
            ps.setString(5, event.ip());
            ps.setString(6, event.userAgent());
            ps.setString(7, event.niveau());
            ps.setBoolean(8, event.succes());
            ps.setString(9, detailsJson);

            int rows = ps.executeUpdate();
            logger.debug("Audit persiste : {} rows pour action={}", rows, event.action());

        } catch (Exception e) {
            logger.error("Erreur persistance audit (best-effort) : {}", e.getMessage());
        }
    }
}
```

### service/MfaService.java

```java
package bf.ycognicore.backend.service;

import bf.ycognicore.backend.config.VaultProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.warrenstrange.googleauth.GoogleAuthenticator;
import com.warrenstrange.googleauth.GoogleAuthenticatorKey;
import com.warrenstrange.googleauth.GoogleAuthenticatorQRGenerator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.Instant;

@Service
public class MfaService {

    private static final Logger logger = LoggerFactory.getLogger(MfaService.class);

    private final VaultTransitService vault;
    private final VaultProperties props;
    private final ObjectMapper objectMapper;
    private final GoogleAuthenticator gAuth = new GoogleAuthenticator();

    public MfaService(VaultTransitService vault, VaultProperties props, ObjectMapper objectMapper) {
        this.vault = vault;
        this.props = props;
        this.objectMapper = objectMapper;
    }

    public MfaSetupResult setup(String userEmail) {
        GoogleAuthenticatorKey key = gAuth.createCredentials();
        String secret = key.getKey();
        String qrUrl = GoogleAuthenticatorQRGenerator.getOtpAuthTotpURL(
                props.getIssuer(), userEmail, key);
        logger.info("MFA setup pour {} (secret genere, {}-char)", userEmail, secret.length());
        return new MfaSetupResult(secret, qrUrl);
    }

    public JsonNode encryptSecret(String secret) {
        String ciphertext = vault.encrypt(secret);
        ObjectNode node = objectMapper.createObjectNode();
        node.put("algo", "aes256-gcm96");
        node.put("vault_ct", ciphertext);
        node.put("version", 1);
        node.put("created_at", Instant.now().toString());
        return node;
    }

    public String decryptSecret(JsonNode jsonPackage) {
        if (jsonPackage == null || !jsonPackage.has("vault_ct")) {
            throw new IllegalArgumentException("Format package MFA invalide : vault_ct absent");
        }
        String ciphertext = jsonPackage.get("vault_ct").asText();
        return vault.decrypt(ciphertext);
    }

    public boolean verifyCode(String secret, int code) {
        boolean ok = gAuth.authorize(secret, code);
        logger.debug("Verification MFA : resultat={}", ok);
        return ok;
    }

    public record MfaSetupResult(String secret, String qrUrl) {}

    public record MfaVerifyResult(boolean success, String message) {}
}
```

**Note** : les 13 entités migrées suivent toutes le même pattern :

```java
@JdbcTypeCode(SqlTypes.JSON)
@Column(name = "xxx", columnDefinition = "jsonb")
private JsonNode xxx;
```

---

## F-18 — Frontend Angular Core (BL-015)

### core/models/login.model.ts

```typescript
export interface LoginRequest {
  email: string;
  password: string;
  tenantCode?: string | null;
}

export interface UserInfo {
  userId: string;
  email: string;
  userType: 'SUPERADMIN' | 'ADMIN' | 'INTERNE' | 'EXTERNE';
  tenantCode: string | null;
  redirectUrl: string;
}

export interface LoginResponse {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  expiresInSeconds: number;
  user: UserInfo;
}

export interface RefreshResponse {
  accessToken: string;
  tokenType: string;
  expiresInSeconds: number;
}
```

### core/auth/auth.service.ts

```typescript
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { BehaviorSubject, Observable, tap } from 'rxjs';
import { environment } from '../../../environments/environment';
import { LoginRequest, LoginResponse, RefreshResponse, UserInfo } from '../models/login.model';

@Injectable({ providedIn: 'root' })
export class AuthService {

  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);

  private readonly currentUser$ = new BehaviorSubject<UserInfo | null>(this.loadUser());

  get user$(): Observable<UserInfo | null> {
    return this.currentUser$.asObservable();
  }

  get currentUser(): UserInfo | null {
    return this.currentUser$.value;
  }

  get accessToken(): string | null {
    return localStorage.getItem(environment.tokenKey);
  }

  get refreshToken(): string | null {
    return localStorage.getItem(environment.refreshKey);
  }

  isAuthenticated(): boolean {
    return !!this.accessToken && !!this.currentUser;
  }

  login(payload: LoginRequest): Observable<LoginResponse> {
    return this.http.post<LoginResponse>(`${environment.apiUrl}/api/auth/login`, payload)
      .pipe(tap(res => this.storeSession(res)));
  }

  refresh(): Observable<RefreshResponse> {
    const refreshToken = this.refreshToken;
    const tenantCode = this.currentUser?.tenantCode;
    return this.http.post<RefreshResponse>(
      `${environment.apiUrl}/api/auth/refresh`,
      { refreshToken },
      tenantCode ? { headers: { 'X-Tenant-Code': tenantCode } } : {}
    ).pipe(tap(res => {
      localStorage.setItem(environment.tokenKey, res.accessToken);
    }));
  }

  logout(): void {
    localStorage.removeItem(environment.tokenKey);
    localStorage.removeItem(environment.refreshKey);
    localStorage.removeItem(environment.userKey);
    this.currentUser$.next(null);
    this.router.navigate(['/login']);
  }

  private storeSession(res: LoginResponse): void {
    localStorage.setItem(environment.tokenKey, res.accessToken);
    localStorage.setItem(environment.refreshKey, res.refreshToken);
    localStorage.setItem(environment.userKey, JSON.stringify(res.user));
    this.currentUser$.next(res.user);
  }

  private loadUser(): UserInfo | null {
    const raw = localStorage.getItem(environment.userKey);
    if (!raw) return null;
    try { return JSON.parse(raw) as UserInfo; } catch { return null; }
  }
}
```

### core/http/jwt.interceptor.ts

```typescript
import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { AuthService } from '../auth/auth.service';

export const jwtInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const token = auth.accessToken;
  const user = auth.currentUser;

  let headers = req.headers;
  if (token) {
    headers = headers.set('Authorization', `Bearer ${token}`);
  }
  if (user?.tenantCode && !headers.has('X-Tenant-Code')) {
    headers = headers.set('X-Tenant-Code', user.tenantCode);
  }

  return next(req.clone({ headers }));
};
```

### core/auth/auth.guard.ts

```typescript
import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';

export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (auth.isAuthenticated()) {
    return true;
  }
  router.navigate(['/login']);
  return false;
};
```

### core/auth/role.guard.ts

```typescript
import { inject } from '@angular/core';
import { ActivatedRouteSnapshot, CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';

export const roleGuard: CanActivateFn = (route: ActivatedRouteSnapshot) => {
  const auth = inject(AuthService);
  const router = inject(Router);
  const user = auth.currentUser;
  const allowed = (route.data?.['roles'] as string[] | undefined) ?? [];

  if (!user) {
    router.navigate(['/login']);
    return false;
  }
  if (allowed.length === 0 || allowed.includes(user.userType)) {
    return true;
  }
  router.navigate([user.redirectUrl || '/login']);
  return false;
};
```

### app.config.ts

```typescript
import { ApplicationConfig, provideZonelessChangeDetection } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';

import { routes } from './app.routes';
import { jwtInterceptor } from './core/http/jwt.interceptor';

export const appConfig: ApplicationConfig = {
  providers: [
    provideZonelessChangeDetection(),
    provideRouter(routes),
    provideHttpClient(withInterceptors([jwtInterceptor])),
  ],
};
```

### app.routes.ts

```typescript
import { Routes } from '@angular/router';
import { authGuard } from './core/auth/auth.guard';
import { roleGuard } from './core/auth/role.guard';

export const routes: Routes = [
  {
    path: 'login',
    loadComponent: () => import('./layout/auth-layout/auth-layout.component').then(m => m.AuthLayoutComponent),
    children: [
      { path: '', loadComponent: () => import('./features/auth/login/login.component').then(m => m.LoginComponent) },
    ],
  },
  {
    path: 'superadmin',
    canActivate: [authGuard, roleGuard],
    data: { roles: ['SUPERADMIN'] },
    loadComponent: () => import('./layout/main-layout/main-layout.component').then(m => m.MainLayoutComponent),
    children: [
      { path: '', loadComponent: () => import('./features/dashboard/dashboard.component').then(m => m.DashboardComponent) },
    ],
  },
  {
    path: 'admin',
    canActivate: [authGuard, roleGuard],
    data: { roles: ['ADMIN'] },
    loadComponent: () => import('./layout/main-layout/main-layout.component').then(m => m.MainLayoutComponent),
    children: [
      { path: '', loadComponent: () => import('./features/dashboard/dashboard.component').then(m => m.DashboardComponent) },
    ],
  },
  {
    path: 'employee',
    canActivate: [authGuard, roleGuard],
    data: { roles: ['INTERNE'] },
    loadComponent: () => import('./layout/main-layout/main-layout.component').then(m => m.MainLayoutComponent),
    children: [
      { path: '', loadComponent: () => import('./features/dashboard/dashboard.component').then(m => m.DashboardComponent) },
    ],
  },
  {
    path: 'portal',
    canActivate: [authGuard, roleGuard],
    data: { roles: ['EXTERNE'] },
    loadComponent: () => import('./layout/main-layout/main-layout.component').then(m => m.MainLayoutComponent),
    children: [
      { path: '', loadComponent: () => import('./features/dashboard/dashboard.component').then(m => m.DashboardComponent) },
    ],
  },
  { path: '', redirectTo: '/login', pathMatch: 'full' },
  { path: '**', redirectTo: '/login' },
];
```

---

## F-19 — Page login (BL-016)

### features/auth/login/login.component.ts

```typescript
import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule],
  template: `
    <form (ngSubmit)="onSubmit()" #f="ngForm" class="login-form">
      <div class="field">
        <label for="email">Email</label>
        <input id="email" type="email" name="email" [(ngModel)]="email"
               required autocomplete="email" placeholder="votre@email.bf" />
      </div>

      <div class="field">
        <label for="password">Mot de passe</label>
        <input id="password" type="password" name="password" [(ngModel)]="password"
               required autocomplete="current-password" placeholder="********" />
      </div>

      <div class="field">
        <label for="tenantCode">Code tenant (laisser vide pour Superadmin)</label>
        <input id="tenantCode" type="text" name="tenantCode" [(ngModel)]="tenantCode"
               placeholder="DEMO001" />
      </div>

      @if (errorMessage()) {
        <div class="error">{{ errorMessage() }}</div>
      }

      <button type="submit" [disabled]="!f.valid || loading()">
        {{ loading() ? 'Connexion...' : 'Se connecter' }}
      </button>
    </form>
  `,
  styles: [`
    .login-form { display: flex; flex-direction: column; gap: 1rem; }
    .field { display: flex; flex-direction: column; gap: 0.35rem; }
    .field label { font-size: 0.85rem; color: #334155; font-weight: 500; }
    .field input { padding: 0.65rem 0.85rem; border: 1px solid #cbd5e1; border-radius: 6px; font-size: 0.95rem; }
    .field input:focus { outline: none; border-color: #3b82f6; box-shadow: 0 0 0 3px rgba(59,130,246,0.15); }
    .error { color: #dc2626; font-size: 0.85rem; padding: 0.5rem; background: #fee2e2; border-radius: 4px; }
    button { padding: 0.75rem; background: #1e3a8a; color: white; border: none; border-radius: 6px; font-size: 1rem; font-weight: 500; cursor: pointer; }
    button:hover:not(:disabled) { background: #1e40af; }
    button:disabled { opacity: 0.6; cursor: not-allowed; }
  `],
})
export class LoginComponent {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  email = '';
  password = '';
  tenantCode = '';

  readonly loading = signal(false);
  readonly errorMessage = signal<string | null>(null);

  onSubmit(): void {
    this.loading.set(true);
    this.errorMessage.set(null);

    const payload = {
      email: this.email,
      password: this.password,
      tenantCode: this.tenantCode?.trim() || null,
    };

    this.auth.login(payload).subscribe({
      next: (res) => {
        this.loading.set(false);
        this.router.navigate([res.user.redirectUrl || '/']);
      },
      error: (err) => {
        this.loading.set(false);
        const msg = err?.error?.error || err?.error?.message || err?.message || 'Erreur de connexion';
        this.errorMessage.set(msg);
      },
    });
  }
}
```
