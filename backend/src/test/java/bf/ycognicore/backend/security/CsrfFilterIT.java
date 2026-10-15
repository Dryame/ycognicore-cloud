package bf.ycognicore.backend.security;

import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThat;

/** Tests CsrfFilter. Ref. : D-13, F8, T3.6. */
class CsrfFilterIT {

    private CsrfFilter filter;

    @BeforeEach
    void setUp() {
        filter = new CsrfFilter();
        ReflectionTestUtils.setField(filter, "enforce", false);
    }

    @Test
    void cookie_emis_si_absent() throws Exception {
        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/api/clients");
        MockHttpServletResponse res = new MockHttpServletResponse();
        filter.doFilter(req, res, new MockFilterChain());

        Cookie cookie = res.getCookie("XSRF-TOKEN");
        assertThat(cookie).isNotNull();
        assertThat(cookie.getValue()).isNotBlank();
        assertThat(cookie.isHttpOnly()).isFalse();
        assertThat(cookie.getSecure()).isTrue();
    }

    @Test
    void mode_observation_ne_bloque_pas() throws Exception {
        MockHttpServletRequest req = new MockHttpServletRequest("POST", "/api/clients");
        req.setCookies(new Cookie("XSRF-TOKEN", "cookie-val"));
        MockHttpServletResponse res = new MockHttpServletResponse();
        filter.doFilter(req, res, new MockFilterChain());

        assertThat(res.getStatus()).isNotEqualTo(403);
    }

    @Test
    void mode_strict_bloque_mismatch() throws Exception {
        ReflectionTestUtils.setField(filter, "enforce", true);
        MockHttpServletRequest req = new MockHttpServletRequest("POST", "/api/clients");
        req.setCookies(new Cookie("XSRF-TOKEN", "cookie-val"));
        MockHttpServletResponse res = new MockHttpServletResponse();
        filter.doFilter(req, res, new MockFilterChain());

        assertThat(res.getStatus()).isEqualTo(403);
    }

    @Test
    void mode_strict_passe_si_match() throws Exception {
        ReflectionTestUtils.setField(filter, "enforce", true);
        MockHttpServletRequest req = new MockHttpServletRequest("POST", "/api/clients");
        req.setCookies(new Cookie("XSRF-TOKEN", "same"));
        req.addHeader("X-XSRF-TOKEN", "same");
        MockHttpServletResponse res = new MockHttpServletResponse();
        filter.doFilter(req, res, new MockFilterChain());

        assertThat(res.getStatus()).isNotEqualTo(403);
    }

    @Test
    void shouldNotFilter_login_et_actuator() {
        MockHttpServletRequest login = new MockHttpServletRequest("POST", "/api/auth/login");
        MockHttpServletRequest act = new MockHttpServletRequest("GET", "/actuator/health");
        MockHttpServletRequest normal = new MockHttpServletRequest("POST", "/api/clients");

        assertThat(filter.shouldNotFilter(login)).isTrue();
        assertThat(filter.shouldNotFilter(act)).isTrue();
        assertThat(filter.shouldNotFilter(normal)).isFalse();
    }
}
