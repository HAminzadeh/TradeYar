package com.tradeyar.app;

import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "http://localhost:5173")
public class SystemController {

    @GetMapping("/health")
    public Map<String, Object> health() {
        return Map.of(
            "application", "TradeYar",
            "status", "READY",
            "mode", "DEMO",
            "tradingEnabled", false
        );
    }
}