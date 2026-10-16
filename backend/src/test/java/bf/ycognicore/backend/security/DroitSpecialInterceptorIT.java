package bf.ycognicore.backend.security;

import bf.ycognicore.backend.multitenant.MultiTenantConnectionProviderImpl;
import bf.ycognicore.backend.multitenant.TenantContext;
import bf.ycognicore.backend.service.DroitSpecialService;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.method.HandlerMethod;

import java.lang.reflect.Method;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Tests DroitSpecialInterceptor : sans annotation, avec droit, sans droit.
 * Ref. : D-11, P-06.
 */
class DroitSpecialInterceptorIT {

    // Handler de test
    static class TestHandler {
        @RequireDroitSpecial("CONSOLE_SECURITE")
        public void protectedMethod() {}

        public void publicMethod() {}
    }

    @Test
    void sans_annotation_passe() throws Exception {
        DroitSpecialService service = mock(DroitSpecialService.class);
        DroitSpecialInterceptor interceptor = new DroitSpecialInterceptor(service);

        Method m = TestHandler.class.getMethod("publicMethod");
        HandlerMethod handler = new HandlerMethod(new TestHandler(), m);

        MockHttpServletResponse res = new MockHttpServletResponse();
        boolean result = interceptor.preHandle(new MockHttpServletRequest(), res, handler);

        assertThat(result).isTrue();
        assertThat(res.getStatus()).isEqualTo(200);
    }

    @Test
    void avec_droit_passe() throws Exception {
        DroitSpecialService service = mock(DroitSpecialService.class);
        UUID userId = UUID.randomUUID();
        when(service.hasDroitSpecial(eq(userId), eq("CONSOLE_SECURITE"))).thenReturn(true);

        DroitSpecialInterceptor interceptor = new DroitSpecialInterceptor(service);

        SecurityContextHolder.getContext().setAuthentication(
            new UsernamePasswordAuthenticationToken(userId.toString(), null, List.of()));

        Method m = TestHandler.class.getMethod("protectedMethod");
        HandlerMethod handler = new HandlerMethod(new TestHandler(), m);

        MockHttpServletResponse res = new MockHttpServletResponse();
        boolean result = interceptor.preHandle(new MockHttpServletRequest(), res, handler);

        assertThat(result).isTrue();
        SecurityContextHolder.clearContext();
    }

    @Test
    void sans_droit_refuse_403() throws Exception {
        DroitSpecialService service = mock(DroitSpecialService.class);
        UUID userId = UUID.randomUUID();
        when(service.hasDroitSpecial(eq(userId), eq("CONSOLE_SECURITE"))).thenReturn(false);

        DroitSpecialInterceptor interceptor = new DroitSpecialInterceptor(service);

        SecurityContextHolder.getContext().setAuthentication(
            new UsernamePasswordAuthenticationToken(userId.toString(), null, List.of()));

        Method m = TestHandler.class.getMethod("protectedMethod");
        HandlerMethod handler = new HandlerMethod(new TestHandler(), m);

        MockHttpServletResponse res = new MockHttpServletResponse();
        boolean result = interceptor.preHandle(new MockHttpServletRequest(), res, handler);

        assertThat(result).isFalse();
        assertThat(res.getStatus()).isEqualTo(HttpServletResponse.SC_FORBIDDEN);
        SecurityContextHolder.clearContext();
    }

    @Test
    void non_authentifie_refuse_401() throws Exception {
        DroitSpecialService service = mock(DroitSpecialService.class);
        DroitSpecialInterceptor interceptor = new DroitSpecialInterceptor(service);
        SecurityContextHolder.clearContext();

        Method m = TestHandler.class.getMethod("protectedMethod");
        HandlerMethod handler = new HandlerMethod(new TestHandler(), m);

        MockHttpServletResponse res = new MockHttpServletResponse();
        boolean result = interceptor.preHandle(new MockHttpServletRequest(), res, handler);

        assertThat(result).isFalse();
        assertThat(res.getStatus()).isEqualTo(HttpServletResponse.SC_UNAUTHORIZED);
    }
}
