package bf.ycognicore.backend.service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.List;
import java.util.Map;

/**
 * Generation et validation des JWT (HS512).
 * Ref. : NFR-SEC-11, BL-011
 */
@Service
public class JwtService {

    private final SecretKey signingKey;
    private final long accessTtlMs;
    private final long refreshTtlMs;

    public JwtService(
            @Value("${ycc.jwt.secret}") String secret,
            @Value("${ycc.jwt.access-token-expiration-minutes:30}") long accessMinutes,
            @Value("${ycc.jwt.refresh-token-expiration-days:7}") long refreshDays
    ) {
        this.signingKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessTtlMs = accessMinutes * 60_000L;
        this.refreshTtlMs = refreshDays * 24 * 60 * 60_000L;
    }

    /**
     * Genere un access token signe.
     */
    public String generateAccessToken(String userId, String email, String userType,
                                       String tenantCode, List<String> roles) {
        long now = System.currentTimeMillis();
        return Jwts.builder()
                .subject(userId)
                .claim("email", email)
                .claim("userType", userType)
                .claim("tenantCode", tenantCode)
                .claim("roles", roles)
                .claim("type", "access")
                .issuedAt(new Date(now))
                .expiration(new Date(now + accessTtlMs))
                .signWith(signingKey, Jwts.SIG.HS512)
                .compact();
    }

    /**
     * Genere un refresh token.
     */
    public String generateRefreshToken(String userId) {
        long now = System.currentTimeMillis();
        return Jwts.builder()
                .subject(userId)
                .claim("type", "refresh")
                .issuedAt(new Date(now))
                .expiration(new Date(now + refreshTtlMs))
                .signWith(signingKey, Jwts.SIG.HS512)
                .compact();
    }

    /**
     * Valide et retourne les claims du token.
     * Lance une exception jjwt si invalide/expire.
     */
    public Claims parseToken(String token) {
        return Jwts.parser()
                .verifyWith(signingKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    public long getAccessTtlSeconds() {
        return accessTtlMs / 1000L;
    }
}
