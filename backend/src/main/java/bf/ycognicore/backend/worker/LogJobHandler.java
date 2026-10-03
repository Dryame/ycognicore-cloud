package bf.ycognicore.backend.worker;

import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Handler de demonstration : log le payload.
 * Utile pour tester le worker sans dependance externe.
 *
 * Ref. : BL-019
 */
@Component
public class LogJobHandler implements JobHandler {

    private static final Logger logger = LoggerFactory.getLogger(LogJobHandler.class);

    @Override
    public String supportedType() {
        return "LOG";
    }

    @Override
    public void handle(JsonNode payload) throws Exception {
        logger.info("[JOB LOG] payload={}", payload);
    }
}
