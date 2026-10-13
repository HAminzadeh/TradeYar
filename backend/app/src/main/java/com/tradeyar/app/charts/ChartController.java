package com.tradeyar.app.charts;

import com.tradeyar.app.market.MarketService;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/charts")
public class ChartController {
  private final MarketService market;
  public ChartController(MarketService market) { this.market = market; }
  @GetMapping("/series")
  public Map<String,Object> series(@RequestParam(name="symbol", defaultValue="EURUSD") String symbol) {
    return Map.of("symbol",market.symbol(symbol),"resolution","H1","source","SYNTHETIC_DEMO",
      "candles",market.candles(symbol,100),"supportedIndicators",new String[]{"SMA","EMA","RSI"});
  }
}