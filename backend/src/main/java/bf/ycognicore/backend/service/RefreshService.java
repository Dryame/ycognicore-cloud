package bf.ycognicore.backend.service;

import bf.ycognicore.backend.dto.RefreshResponse;
import bf.ycognicore.backend.entity.controlplane.SuperadminUser;
import bf.ycognicore.backend.entity.tenant.User;
import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.repository.controlplane.SuperadminUserRepository;
import bf.ycognicore.backend.repository.controlplane.TenantRepository;
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
    private final SessionService sessionService;
    private final TokenService tokenService;
    private final SuperadminUserRepository superadminRepo;
    private final UserRepository userRepo;
    private final UserService userService;
    private final TenantRepository tenantRepository;

    public RefreshService(JwtService jwtService,
                          SuperadminUserRepository superadminRepo,
                          UserRepository userRepo,
                          SessionService sessionService,
                          TokenService tokenService,
                          UserService userService,
                          TenantRepository tenantRepository) {
        this.jwtService = jwtService;
        this.sessionService = sessionService;
        this.tokenService = tokenService;
        this.superadminRepo = superadminRepo;
        this.userRepo = userRepo;
        this.userService = userService;
        this.tenantRepository = tenantRepository;
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

        String jti = claims.getId();
        if (jti == null || !jti.contains(":")) {
            throw new BadCredentialsException("Refresh token sans jti");
        }
        UUID sessionId;
        try {
            sessionId = UUID.fromString(jti.substring(0, jti.indexOf(':')));
        } catch (Exception e) {
            throw new BadCredentialsException("jti invalide");
        }

        String storedHash = sessionService.isActiveAndRefreshHash(tenantCode, sessionId);
        if (storedHash == null) {
            throw new BadCredentialsException("Session expiree ou revoquee");
        }
        String presentedHash = tokenService.hashToken(refreshToken);
        if (!storedHash.equals(presentedHash)) {
            throw new BadCredentialsException("Refresh token deja utilise (rejeu)");
        }

        String newRefresh = tokenService.generateRefreshToken(userUuid, sessionId);
        sessionService.rotateRefresh(tenantCode, sessionId, newRefresh);

        UUID tenantId = tenantRepository.findByCode(tenantCode.trim().toUpperCase()).orElseThrow().getId();
        
        User user = userRepo.findById(userUuid).orElse(null);
        if (user == null) {
            throw new BadCredentialsException("Utilisateur introuvable");
        }
        
        // Déchiffrement pour récupérer l'email en clair dans le token
        user = userService.decryptForDisplay(user, tenantId);

        String email = user.getEmail();
        String userType = user.getTypeUtilisateur();
        String newAccess = tokenService.generateAccessToken(userUuid, email, userType, tenantCode, List.of(userType), sessionId);

        return new RefreshResponse(newAccess, "Bearer", 1800L, newRefresh);
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
}
