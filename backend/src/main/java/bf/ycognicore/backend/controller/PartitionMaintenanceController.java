package bf.ycognicore.backend.controller;

import bf.ycognicore.backend.entity.controlplane.PartitionMaintenanceLog;
import bf.ycognicore.backend.repository.controlplane.PartitionMaintenanceLogRepository;
import bf.ycognicore.backend.service.PartitionMaintenanceService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Endpoint REST pour le déclenchement manuel et la consultation.
 *
 * Réf. : BL-005
 */
@RestController
@RequestMapping("/api/admin/partitions")
public class PartitionMaintenanceController {

    private static final Logger logger = LoggerFactory.getLogger(PartitionMaintenanceController.class);

    private final PartitionMaintenanceService service;
    private final PartitionMaintenanceLogRepository logRepository;

    public PartitionMaintenanceController(PartitionMaintenanceService service,
                                           PartitionMaintenanceLogRepository logRepository) {
        this.service = service;
        this.logRepository = logRepository;
    }

    @PostMapping("/run")
    public ResponseEntity<?> runManuel() {
        logger.info("Déclenchement manuel");
        var result = service.runMaintenance("MANUEL");
        return ResponseEntity.ok(result);
    }

    @GetMapping("/history")
    public ResponseEntity<List<PartitionMaintenanceLog>> history() {
        return ResponseEntity.ok(logRepository.findTop50ByOrderByExecuteLeDesc());
    }
}
