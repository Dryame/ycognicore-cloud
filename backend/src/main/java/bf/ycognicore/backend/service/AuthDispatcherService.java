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

import java.util.List;

/**
 * Auth Dispatcher : point d'entree unique qui identifie le type
 * d'utilisateur et le redirige vers l'interface appropriee.
 *
 * Ref. : NFR-SEC-06, BL-011
 */
@Service
public class AuthDispatcherService {

    private static final Logger logger = LoggerFactory.getLogger(AuthDispatcherService.class);

    private final SuperadminUserRepository superadminRepo;
    private final UserRepository userRepo;   // tenant
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public AuthDispatcherService(
            SuperadminUserRepository superadminRepo,
            UserRepository userRepo,
            PasswordEncoder passwordEncoder,
            JwtService jwtService
    ) {
        this.superadminRepo = superadminRepo;
        this.userRepo = userRepo;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    /**
     * Authentifie selon le tenantCode (null = Superadmin).
     */
    public LoginResponse authenticate(LoginRequest req) {
        if (req.tenantCode() == null || req.tenantCode().isBlank()) {
            return authenticateSuperadmin(req);
        }
        return authenticateTenantUser(req);
    }

    // -----------------------------------------------------------------
    // Superadmin (control plane)
    // -----------------------------------------------------------------
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

    // -----------------------------------------------------------------
    // Utilisateur tenant (interne ou externe)
    // -----------------------------------------------------------------
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

            // TODO BL-013 : distinguer ADMIN / EMPLOYE via role "Administrateur Client"
            String userType = "EXTERNE".equals(user.getTypeUtilisateur()) ? "EXTERNE" : "INTERNE";
            String redirectUrl = "EXTERNE".equals(userType)
                    ? "/portal/dashboard"
                    : "/admin/dashboard";

            String accessToken = jwtService.generateAccessToken(
                    user.getId().toString(), user.getEmail(), userType, tenantCode,
                    List.of("ROLE_" + userType));
            String refreshToken = jwtService.generateRefreshToken(user.getId().toString());

            UserInfo info = new UserInfo(
                    user.getId().toString(), user.getEmail(), userType, tenantCode,
                    redirectUrl);

            return new LoginResponse(accessToken, refreshToken, "Bearer",
                    jwtService.getAccessTtlSeconds(), info);
        } finally {
            TenantContext.clear();
        }
    }
}
