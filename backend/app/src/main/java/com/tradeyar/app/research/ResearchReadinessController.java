package com.tradeyar.app.research;

import com.tradeyar.app.strategies.StrategyService;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Read-only readiness contracts for TradeYar v0.4. No history ingestion, training,
 * broker commands, real-money execution, or research-success claims.
 */
@RestController
@RequestMapping("/api/v1/research")
public class ResearchReadinessController {
  private static final Set<String> STYLES = Set.of("SCALP", "INTRADAY", "SWING", "POSITION", "WEEKLY", "CUSTOM");
  private final StrategyService strategies;

  public ResearchReadinessController(StrategyService strategies) { this.strategies = strategies; }

  private static String style(String raw) {
    String value = raw == null ? "INTRADAY" : raw.trim().toUpperCase(Locale.ROOT);
    if (!STYLES.contains(value)) throw new IllegalArgumentException("Unknown trading style");
    return value;
  }

  @GetMapping("/profiles")
  public Map<String,Object> profiles() {
    List<Map<String,Object>> items = List.of(
      profile("SCALP", "M1", "M15", 0.10),
      profile("INTRADAY", "M15", "H1", 0.25),
      profile("SWING", "H4", "D1", 0.25),
      profile("POSITION", "D1", "W1", 0.25),
      profile("WEEKLY", "W1", "MN1", 0.20),
      profile("CUSTOM", "H1", "H4", 0.25)
    );
    return Map.of("profiles",items,"mode","RESEARCH_ONLY","validated",false,"executionEnabled",false);
  }

  private static Map<String,Object> profile(String id,String signal,String confirmation,double maxPaperRisk) {
    return Map.of("id",id,"signalTimeframe",signal,"confirmationTimeframe",confirmation,
      "indicativeMaxPaperRiskPercent",maxPaperRisk,"validated",false);
  }

  @GetMapping("/consensus")
  public Map<String,Object> consensus(
      @RequestParam(name="symbol", defaultValue="EURUSD") String symbol,
      @RequestParam(name="style", defaultValue="INTRADAY") String style) {
    String selectedStyle = style(style);
    List<Map<String,Object>> catalog = strategies.catalog();
    long enabled = catalog.stream().filter(item->Boolean.TRUE.equals(item.get("implemented"))).count();
    long buys = 0, sells = 0, neutral = 0;
    for (Map<String,Object> item : catalog) {
      if (!Boolean.TRUE.equals(item.get("implemented"))) continue;
      String id = String.valueOf(item.get("id"));
      String vote = String.valueOf(strategies.evaluate(symbol,id).get("signal"));
      if ("BUY".equals(vote)) buys++;
      else if ("SELL".equals(vote)) sells++;
      else neutral++;
    }
    Map<String,Object> votes = Map.of("BUY",buys,"SELL",sells,"NO_SIGNAL",neutral);
    Map<String,Object> result = new LinkedHashMap<>();
    result.put("symbol",symbol.toUpperCase(Locale.ROOT));
    result.put("style",selectedStyle);
    result.put("strategyCount",StrategyService.CATALOG.size());
    result.put("evaluatedCount",enabled);
    result.put("minimumAligned",16);
    result.put("requiredConsensusPercent",80);
    result.put("votes",votes);
    result.put("outcome","INSUFFICIENT_EVIDENCE");
    result.put("reason","Only three basic synthetic evaluations exist; 20 validated, independent evaluations and real data are required");
    result.put("eligibleForRealTrading",false);
    result.put("source","SYNTHETIC_DEMO");
    result.put("researchValidated",false);
    return result;
  }

  @GetMapping("/knowledge/overview")
  public Map<String,Object> knowledge(
      @RequestParam(name="symbol", defaultValue="EURUSD") String symbol,
      @RequestParam(name="style", defaultValue="INTRADAY") String style) {
    String selectedStyle = style(style);
    // Validate supported symbols using existing strategy service; no accidental fake import.
    strategies.evaluate(symbol,"SMA_CROSS");
    Map<String,Object> result = new LinkedHashMap<>();
    result.put("module","M23");
    result.put("symbol",symbol.toUpperCase(Locale.ROOT));
    result.put("style",selectedStyle);
    result.put("status","WAITING_FOR_DATA");
    result.put("requestedHistoryYears",10);
    result.put("verifiedCoverageYears",0);
    result.put("verifiedDatasets",0);
    result.put("validatedModel",false);
    result.put("trainedModels",0);
    result.put("completedResearchExperiments",0);
    result.put("dailyIncrementalJobConfigured",false);
    result.put("historyImported",false);
    result.put("decisionAuthorization",false);
    result.put("note","Verified historical ingestion, PostgreSQL metadata, walk-forward validation and model registry are planned future stages");
    return result;
  }

  @GetMapping("/roadmap")
  public Map<String,Object> roadmap() {
    return Map.of("targetModules",23,"plannedPhases",12,"implementedPhases",List.of(0,1),
      "unimplementedPhases",List.of(2,3,4,5,6,7,8,9,10,11),"liveExecutionEnabled",false,
      "baselineModules",20);
  }
}
