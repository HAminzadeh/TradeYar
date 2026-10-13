package com.tradeyar.app.mt5;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;

import org.springframework.web.bind.annotation.*;

/**
 * Read-only local CSV status. No terminal commands or order execution.
 */
@RestController
@RequestMapping("/api/mt5")
public class Mt5Controller {
    @GetMapping("/status")
    public Map<String, Object> status() {
        String sourcePath = System.getenv("TRADEYAR_MT5_TICKS_FILE");
        if (sourcePath == null || sourcePath.isBlank()) return disconnected("CSV path not configured");
        try {
            Path file = Path.of(sourcePath);
            if (!Files.isRegularFile(file) || Files.size(file) > 32768L)
                return disconnected("Snapshot unavailable or too large");
            List<String> lines = Files.readAllLines(file);
            if (lines.isEmpty()) return disconnected("Empty snapshot");
            String[] fields = lines.get(lines.size() - 1).split(";", -1);
            if (fields.length < 4) return disconnected("Malformed snapshot");
            double bid = Double.parseDouble(fields[2]);
            double ask = Double.parseDouble(fields[3]);
            if (!Double.isFinite(bid) || !Double.isFinite(ask) || bid <= 0 || ask < bid)
                return disconnected("Invalid prices");
            return Map.of("status", "SNAPSHOT_AVAILABLE", "mode", "READ_ONLY", "liveTradingEnabled", false,
                    "timestamp", fields[0], "symbol", fields[1], "bid", bid, "ask", ask,
                    "note", "Snapshot is not a validated live market feed");
        } catch (Exception e) {
            return disconnected("Unable to read CSV snapshot");
        }
    }

    private Map<String, Object> disconnected(String note) {
        return Map.of("status", "DISCONNECTED", "mode", "READ_ONLY", "liveTradingEnabled", false, "note", note);
    }
}