package bf.ycognicore.backend.service;

import io.jsonwebtoken.Claims;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;

/**
 * Encapsule JwtService : jti, nonce rotation, hash stockage.
 * Ref. : D-13, F2, F3, P-01.
 */
@Service
public class TokenService {

    private static final SecureRandom RNG = new SecureRandom();

    private final JwtService jwtService;

    public TokenService(JwtService jwtService) {
        this.jwtService = jwtService;
    }

    public String generateAccessToken(UUID userId, String email, String userType,
                                      String tenantCode, List<String> roles, UUID sessionId) {
        String jti = sessionId != null ? sessionId.toString() : null;
        return jwtService.generateAccessToken(
            userId.toString(), email, userType, tenantCode, roles, jti);
    }

    public String generateRefreshToken(UUID userId, UUID sessionId) {
        String jti = sessionId + ":" + randomNonce();
        return jwtService.generateRefreshToken(userId.toString(), jti);
    }

    public String extractJti(String token) {
        try {
            Claims c = jwtService.parseToken(token);
            return c.getId();
        } catch (Exception e) {
            return null;
        }
    }

    public UUID extractSessionId(String jti) {
        if (jti == null || !jti.contains(":")) return null;
        try {
            return UUID.fromString(jti.substring(0, jti.indexOf(':')));
        } catch (Exception e) {
            return null;
        }
    }

    public String hashToken(String token) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] h = md.digest(token.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(h);
        } catch (Exception e) {
            throw new IllegalStateException("SHA-256 indisponible", e);
        }
    }

    private static String randomNonce() {
        byte[] b = new byte[16];
        RNG.nextBytes(b);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(b);
    }

    /** jti peut être un UUID seul (access) ou "UUID:nonce" (refresh). */
    public java.util.UUID extractSessionIdFromJtiOrId(String jti) {
        if (jti == null) return null;
        try {
            if (jti.contains(":")) {
                return java.util.UUID.fromString(jti.substring(0, jti.indexOf(':')));
            }
            return java.util.UUID.fromString(jti);
        } catch (Exception e) {
            return null;
        }
    }

    /** Délègue à JwtService.parseToken (D-13, filtre session). */
    public io.jsonwebtoken.Claims parseToken(String token) {
        return jwtService.parseToken(token);
    }
}
