package bf.ycognicore.backend.service;

import com.maxmind.db.CHMCache;
import com.maxmind.geoip2.DatabaseReader;
import com.maxmind.geoip2.exception.AddressNotFoundException;
import com.maxmind.geoip2.model.CityResponse;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.InetAddress;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Resolution IP -> (code pays ISO, nom ville).
 * Base DB-IP Lite City (CC BY 4.0).
 * Fail-soft : si la base est absente, retourne (null, null).
 * Ref. : T3.8, F9, P-02 (garde-fou 1 : base locale).
 */
@Service
public class GeoIpService {

    private static final Logger log = LoggerFactory.getLogger(GeoIpService.class);

    @Value("${ycc.geoip.database-path:./data/geoip/dbip-city-lite.mmdb}")
    private String databasePath;

    private DatabaseReader reader;

    @PostConstruct
    void init() {
        Path p = Paths.get(databasePath);
        if (!Files.exists(p)) {
            log.warn("Base GeoIP absente ({}). Resolution desactivee — fail-soft.", p.toAbsolutePath());
            return;
        }
        try {
            this.reader = new DatabaseReader.Builder(p.toFile())
                .withCache(new CHMCache())
                .build();
            log.info("Base GeoIP chargee : {}", p.toAbsolutePath());
        } catch (Exception e) {
            log.error("Chargement base GeoIP echoue : {}", e.getMessage());
        }
    }

    @PreDestroy
    void close() {
        if (reader != null) {
            try { reader.close(); } catch (Exception ignored) {}
        }
    }

    public boolean isReady() {
        return reader != null;
    }

    /**
     * Resout une IP. Retourne (null, null) si non resolvable.
     * IP privee/loopback : retourne ("LOCAL", null).
     */
    public GeoLocation resolve(String ip) {
        if (ip == null || ip.isBlank()) return GeoLocation.UNKNOWN;
        if (reader == null) return GeoLocation.UNKNOWN;

        try {
            InetAddress addr = InetAddress.getByName(ip.trim());
            if (addr.isLoopbackAddress() || addr.isSiteLocalAddress()
                || addr.isLinkLocalAddress() || addr.isAnyLocalAddress()) {
                return new GeoLocation("LOCAL", null);
            }
            CityResponse response = reader.city(addr);
            String country = response.getCountry() != null
                ? response.getCountry().getIsoCode() : null;
            String city = response.getCity() != null
                ? response.getCity().getName() : null;
            if (country != null && country.length() > 2) {
                country = country.substring(0, 2);
            }
            return new GeoLocation(country, city);
        } catch (AddressNotFoundException e) {
            return GeoLocation.UNKNOWN;
        } catch (Exception e) {
            log.debug("Resolution GeoIP echouee pour {} : {}", ip, e.getMessage());
            return GeoLocation.UNKNOWN;
        }
    }

    public record GeoLocation(String pays, String ville) {
        public static final GeoLocation UNKNOWN = new GeoLocation(null, null);
    }
}
