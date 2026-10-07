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
    private final YccMetricsService metrics;

    public AuthDispatcherService(
            SuperadminUserRepository superadminRepo,
            UserRepository userRepo,
            PasswordEncoder passwordEncoder,
            JwtService jwtService,
            UserRoleLoader userRoleLoader,
            YccMetricsService metrics
    ) {
        this.superadminRepo = superadminRepo;
        this.userRepo = userRepo;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.userRoleLoader = userRoleLoader;
        this.metrics = metrics;
    }

    public LoginResponse authenticate(LoginRequest req) {
        try {
            LoginResponse response;
            if (req.tenantCode() == null || req.tenantCode().isBlank()) {
                response = authenticateSuperadmin(req);
            } else {
                response = authenticateTenantUser(req);
            }
            metrics.incrementAuthLoginSuccess();
            return response;
        } catch (Exception e) {
            metrics.incrementAuthLoginFailure();
            throw e;
        }
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
                "/superadmin");

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
                redirectUrl = "/portal";
            } else if (userRoleLoader.isAdminClient(roles)) {
                userType = "ADMIN";
                redirectUrl = "/admin";
            } else {
                userType = "INTERNE";
                redirectUrl = "/employee";
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
