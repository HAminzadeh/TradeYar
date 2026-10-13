package com.tradeyar.app.strategies;

import com.tradeyar.app.market.MarketService;
import com.tradeyar.app.technical.TechnicalService;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.*;

@Service
public class StrategyService {
  public static final List<String> CATALOG=List.of(
    "SMA_CROSS","EMA_CROSS","TRIPLE_EMA","SUPERTREND",
    "MACD","RSI_REVERSAL","STOCHASTIC","CCI",
    "DONCHIAN_BREAKOUT","ATR_BREAKOUT","BOLLINGER_SQUEEZE","LONDON_BREAKOUT",
    "BOLLINGER_MEAN_REVERSION","RSI_DIVERGENCE","KELTNER_MEAN_REVERSION",
    "PIN_BAR","ENGULFING","PIVOT_POINT","ICHIMOKU","MULTI_TF_EMA_ADX");
  private static final Set<String> ENABLED=Set.of("SMA_CROSS","EMA_CROSS","RSI_REVERSAL");
  private final MarketService market;
  private final TechnicalService technical;
  public StrategyService(MarketService market, TechnicalService technical) {
    this.market=market;this.technical=technical;
  }
  public Map<String,Object> evaluate(String symbol,String strategy) {
    if (!CATALOG.contains(strategy)) throw new IllegalArgumentException("Unknown strategy");
    symbol=market.symbol(symbol);
    if (!ENABLED.contains(strategy)) return Map.of("strategy",strategy,"symbol",symbol,
      "implemented",false,"signal","NO_SIGNAL","source","SYNTHETIC_DEMO");
    List<Double> close=technical.closes(market.candles(symbol,100));
    String signal="NO_SIGNAL";
    if ("RSI_REVERSAL".equals(strategy)) {
      double rsi=technical.rsi(close,14);
      signal=rsi<30 ? "BUY" : rsi>70 ? "SELL" : "NO_SIGNAL";
    } else if ("EMA_CROSS".equals(strategy)) {
      double fast=technical.ema(close,10), slow=technical.ema(close,25);
      signal=fast>slow ? "BUY" : fast<slow ? "SELL" : "NO_SIGNAL";
    } else {
      double fast=technical.sma(close,10,close.size()-1), slow=technical.sma(close,25,close.size()-1);
      signal=fast>slow ? "BUY" : fast<slow ? "SELL" : "NO_SIGNAL";
    }
    return Map.of("strategy",strategy,"symbol",symbol,"implemented",true,
      "signal",signal,"source","SYNTHETIC_DEMO","executable",false);
  }
  public List<Map<String,Object>> catalog() {
    return CATALOG.stream().map(s -> Map.<String,Object>of("id",s,
      "implemented",ENABLED.contains(s),"executionEnabled",false)).toList();
  }
}

@RestController
@RequestMapping("/api/strategies")
class StrategiesController {
  private final StrategyService service;
  StrategiesController(StrategyService service) { this.service=service; }
  @GetMapping public List<Map<String,Object>> list() { return service.catalog(); }
  @GetMapping("/evaluate") public Map<String,Object> evaluate(
    @RequestParam(name="symbol", defaultValue="EURUSD") String symbol,
    @RequestParam(name="strategy", defaultValue="SMA_CROSS") String strategy) {
    return service.evaluate(symbol,strategy);
  }
}