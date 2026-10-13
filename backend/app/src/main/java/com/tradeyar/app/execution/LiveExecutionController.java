package com.tradeyar.app.execution;

import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/** This prototype has no path for order submission to MT5 or any broker. */
@RestController
@RequestMapping("/api/live")
public class LiveExecutionController {
  @GetMapping("/status") public Map<String,Object> status() {
    return Map.of("enabled",false,"state","LOCKED","brokerConnected",false,
      "note","Authentication, reconciliation, risk gates and safety review are required");
  }
  @PostMapping("/orders") public void reject(@RequestBody(required=false) String ignored) {
    throw new ResponseStatusException(HttpStatus.LOCKED,"Real-money order execution is disabled");
  }
}