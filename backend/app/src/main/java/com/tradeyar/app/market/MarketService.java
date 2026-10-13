package com.tradeyar.app.market;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.*;

@Service
public class MarketService {
  public record Candle(long time, double open, double high, double low, double close, long volume) { }
  private static final Set<String> SYMBOLS = Set.of("EURUSD","GBPUSD","USDJPY","XAUUSD");
  public String symbol(String input) {
    String symbol = input == null ? "EURUSD" : input.toUpperCase(java.util.Locale.ROOT).trim();
    if (!SYMBOLS.contains(symbol)) throw new IllegalArgumentException("Unsupported symbol");
    return symbol;
  }
  public List<Candle> candles(String symbol, int limit) {
    symbol = symbol(symbol);
    if (limit < 10 || limit > 500) throw new IllegalArgumentException("limit must be 10..500");
    int seed = switch (symbol) { case "GBPUSD" -> 2; case "USDJPY" -> 3; case "XAUUSD" -> 4; default -> 1; };
    double price = switch (symbol) { case "GBPUSD" -> 1.31; case "USDJPY" -> 150.0; case "XAUUSD" -> 3000.0; default -> 1.10; };
    double scale = symbol.equals("XAUUSD") ? 6.0 : symbol.equals("USDJPY") ? .30 : .003;
    long base = Instant.parse("2026-01-01T00:00:00Z").getEpochSecond();
    List<Candle> rows = new ArrayList<>();
    for (int i = 0; i < limit; i++) {
      double open = price;
      price += scale * (.32 * Math.sin((i + seed) * .37) + .18 * Math.cos((i + seed) * .13));
      double high = Math.max(open,price) + scale * .14;
      double low = Math.min(open,price) - scale * .14;
      rows.add(new Candle(base + i * 3600L, round(open),round(high),round(low),round(price),100+i*7L));
    }
    return rows;
  }
  private double round(double n) { return Math.round(n * 100000.0) / 100000.0; }
  public Map<String,Object> quote(String symbol) {
    symbol = symbol(symbol);
    double price = candles(symbol,100).get(99).close();
    double spread = symbol.equals("XAUUSD") ? .25 : symbol.equals("USDJPY") ? .02 : .0002;
    return Map.of("symbol",symbol,"bid",price,"ask",round(price+spread),
      "source","SYNTHETIC_DEMO","tradable",false,"timestamp",Instant.now().toString());
  }
}

@RestController
@RequestMapping("/api/market")
class MarketController {
  private final MarketService service;
  MarketController(MarketService service) { this.service=service; }
  @GetMapping("/candles") public Map<String,Object> candles(
      @RequestParam(name="symbol", defaultValue="EURUSD") String symbol,
      @RequestParam(name="limit", defaultValue="100") int limit) {
    return Map.of("symbol",service.symbol(symbol),"source","SYNTHETIC_DEMO",
      "timeframe","H1","candles",service.candles(symbol,limit));
  }
  @GetMapping("/quote") public Map<String,Object> quote(@RequestParam(name="symbol", defaultValue="EURUSD") String symbol) {
    return service.quote(symbol);
  }
}