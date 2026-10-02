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
