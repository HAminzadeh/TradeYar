package com.tradeyar.app.technical;

import com.tradeyar.app.market.MarketService;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.*;

@Service
public class TechnicalService {
  public double sma(List<Double> values, int period, int endIndex) {
    if (period < 2 || endIndex < period-1 || endIndex >= values.size())
      throw new IllegalArgumentException("Insufficient SMA samples");
    double sum=0;
    for (int i=endIndex-period+1;i<=endIndex;i++) sum += values.get(i);
    return sum/period;
  }
  public double ema(List<Double> values, int period) {
    if (period < 2 || values.size() < period) throw new IllegalArgumentException("Insufficient EMA samples");
    double value=0;
    for (int i=0;i<period;i++) value+=values.get(i);
    value/=period;
    double alpha=2.0/(period+1);
    for (int i=period;i<values.size();i++) value=values.get(i)*alpha+value*(1-alpha);
    return value;
  }
  public double rsi(List<Double> values, int period) {
    if (period<2 || values.size()<=period) throw new IllegalArgumentException("Insufficient RSI samples");
    double gains=0, losses=0;
    for(int i=1;i<=period;i++) {
      double delta=values.get(i)-values.get(i-1);
      gains+=Math.max(delta,0); losses+=Math.max(-delta,0);
    }
    gains/=period; losses/=period;
    for(int i=period+1;i<values.size();i++) {
      double delta=values.get(i)-values.get(i-1);
      gains=(gains*(period-1)+Math.max(delta,0))/period;
      losses=(losses*(period-1)+Math.max(-delta,0))/period;
    }
    if (losses==0) return gains==0 ? 50.0 : 100.0;
    return 100.0-100.0/(1.0+gains/losses);
  }
  public List<Double> closes(List<MarketService.Candle> candles) {
    return candles.stream().map(MarketService.Candle::close).toList();
  }
}

@RestController
@RequestMapping("/api/technical")
class TechnicalController {
  private final TechnicalService technical;
  private final MarketService market;
  TechnicalController(TechnicalService technical, MarketService market) {
    this.technical=technical;this.market=market;
  }
  @GetMapping("/summary") public Map<String,Object> summary(@RequestParam(name="symbol", defaultValue="EURUSD") String symbol) {
    List<Double> values=technical.closes(market.candles(symbol,100));
    return Map.of("symbol",market.symbol(symbol),"source","SYNTHETIC_DEMO",
      "sma20",technical.sma(values,20,values.size()-1),"ema20",technical.ema(values,20),
      "rsi14",technical.rsi(values,14));
  }
}