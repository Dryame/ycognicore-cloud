package bf.ycognicore.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * Configuration d'acces au coffre Vault (transit).
 * Ref. : ADR-002, ADR-005, BL-012
 */
@Configuration
@ConfigurationProperties(prefix = "ycc.vault")
public class VaultProperties {

    private String url = "http://localhost:8200";
    private String token = "";
    private String transitKey = "ycc-mfa-key";
    private String issuer = "yCogniCore Cloud";

    public String getUrl() { return url; }
    public void setUrl(String url) { this.url = url; }
    public String getToken() { return token; }
    public void setToken(String token) { this.token = token; }
    public String getTransitKey() { return transitKey; }
    public void setTransitKey(String transitKey) { this.transitKey = transitKey; }
    public String getIssuer() { return issuer; }
    public void setIssuer(String issuer) { this.issuer = issuer; }
}
