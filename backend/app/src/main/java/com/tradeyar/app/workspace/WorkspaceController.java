package com.tradeyar.app.workspace;

import com.tradeyar.app.market.MarketService;
import com.tradeyar.app.strategies.StrategyService;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Consolidated read-only demonstration scan, NOT a trading authorization service. */
@RestController
@RequestMapping("/api/v1/workspace")
public class WorkspaceController {
  private static final Set<String> STYLES = Set.of("SCALP", "INTRADAY", "SWING", "POSITION", "WEEKLY", "CUSTOM");
  private final MarketService market;
  private final StrategyService strategies;

  public WorkspaceController(MarketService market, StrategyService strategies) {
    this.market = market;
    this.strategies = strategies;
  }

  private String checkStyle(String input) {
    String value = input == null ? "INTRADAY" : input.trim().toUpperCase(Locale.ROOT);
    if (!STYLES.contains(value)) throw new IllegalArgumentException("Unknown trading style");
    return value;
  }

  @GetMapping("/snapshot")
  public Map<String, Object> snapshot(
      @RequestParam(name = "symbol", defaultValue = "EURUSD") String symbol,
      @RequestParam(name = "style", defaultValue = "INTRADAY") String style) {
    String validatedSymbol = market.symbol(symbol);
    String validatedStyle = checkStyle(style);
    List<Map<String,Object>> rows = new ArrayList<>();
    int buy = 0, sell = 0, neutral = 0, pending = 0;
    for (Map<String,Object> item : strategies.catalog()) {
      String id = String.valueOf(item.get("id"));
      boolean implemented = Boolean.TRUE.equals(item.get("implemented"));
      String signal = "NOT_IMPLEMENTED";
      if (implemented) {
        signal = String.valueOf(strategies.evaluate(validatedSymbol,id).get("signal"));
        if ("BUY".equals(signal)) buy++;
        else if ("SELL".equals(signal)) sell++;
        else neutral++;
      } else pending++;
      rows.add(Map.of("id",id,"implemented",implemented,"signal",signal,
          "validated",false,"eligibleForRealTrading",false,"source","SYNTHETIC_DEMO"));
    }
    Map<String,Object> result = new LinkedHashMap<>();
    result.put("symbol",validatedSymbol);
    result.put("style",validatedStyle);
    result.put("timeframe", "H1");
    result.put("requestedTimeframeApplied",false);
    result.put("source","SYNTHETIC_DEMO");
    result.put("actualLiveMarketFeed",false);
    result.put("sampledAtUtc",Instant.now().toString());
    result.put("quote",market.quote(validatedSymbol));
    result.put("candles",market.candles(validatedSymbol,100));
    result.put("strategies",rows);
    result.put("counts",Map.of("BUY",buy,"SELL",sell,"NO_SIGNAL",neutral,"NOT_IMPLEMENTED",pending));
    result.put("implementedCount",buy+sell+neutral);
    result.put("requiredCount",20);
    result.put("minimumAligned",16);
    result.put("decision","INSUFFICIENT_EVIDENCE");
    result.put("entryAllowed",false);
    result.put("realExecutionEnabled",false);
    result.put("reason","Synthetic H1 bars only, three demo algorithms and no validated strategy ensemble");
    return result;
  }

  @GetMapping("/training/status")
  public Map<String,Object> trainingStatus() {
    return Map.of("status","WAITING_FOR_DATA","trainedModels",0,"validatedModels",0,
       "verifiedHistoryYears",0,"learningJobsRunning",0,
       "readyToStart",false,"source","NO_VERIFIED_HISTORICAL_DATA",
       "strategyCount",StrategyService.CATALOG.size(),
       "requirements",List.of("Verified history & data provenance", "PostgreSQL research tables",
          "Leakage-safe chronological split", "Walk-forward validation", "Model registry and audit"));
  }

  /** Preflight request only. Deliberately does not start fake training. */
  @PostMapping("/training/preflight")
  public Map<String,Object> trainingPreflight() {
    return Map.of("accepted",false,"started",false,"state","BLOCKED_MISSING_PREREQUISITES",
      "checkedAtUtc",Instant.now().toString(),"trainingJobsRunning",0,
      "reason","Verified historical data and validated training pipeline are not installed");
  }
}
