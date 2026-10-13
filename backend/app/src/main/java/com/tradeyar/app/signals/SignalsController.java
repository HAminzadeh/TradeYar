package com.tradeyar.app.signals;

import com.tradeyar.app.strategies.StrategyService;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/signals")
public class SignalsController {
  private final StrategyService strategies;
  SignalsController(StrategyService strategies) { this.strategies=strategies; }
  @GetMapping("/preview") public Map<String,Object> preview(@RequestParam(name="symbol", defaultValue="EURUSD") String symbol) {
    return Map.of("signal",strategies.evaluate(symbol,"SMA_CROSS"),
      "confidenceValidated",false,"tradePermitted",false,"riskApproved",false);
  }
}