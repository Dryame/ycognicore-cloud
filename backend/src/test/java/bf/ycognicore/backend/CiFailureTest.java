package bf.ycognicore.backend;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.fail;

class CiFailureTest {

    @Test
    void doit_echouer_pour_prouver_que_la_CI_bloque() {
        fail("Test volontairement cassé — T1.1 critère de sortie : la CI doit échouer");
    }
}
