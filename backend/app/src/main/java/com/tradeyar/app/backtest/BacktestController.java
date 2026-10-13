package com.tradeyar.app.backtest;

import com.tradeyar.app.market.MarketService;
import com.tradeyar.app.technical.TechnicalService;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

/** Educational SMA demonstration with synthetic bars and next-bar-open fills. */
@RestController
@RequestMapping("/api/backtest")
public class BacktestController {
  private final MarketService market;
  private final TechnicalService technical;
  public BacktestController(MarketService market, TechnicalService technical) {
    this.market=market;this.technical=technical;
  }
  @GetMapping("/run") public Map<String,Object> run(
     @RequestParam(name="symbol", defaultValue="EURUSD") String symbol,
     @RequestParam(name="strategy", defaultValue="SMA_CROSS") String strategy,
     @RequestParam(name="spreadPips", defaultValue="1.5") double spreadPips) {
    if (!"SMA_CROSS".equals(strategy)) throw new IllegalArgumentException("Demo backtest supports SMA_CROSS only");
    if (!Double.isFinite(spreadPips) || spreadPips<0 || spreadPips>100)
      throw new IllegalArgumentException("spreadPips must be within 0..100");
    symbol=market.symbol(symbol);
    List<MarketService.Candle> bars=market.candles(symbol,200);
    List<Double> closes=technical.closes(bars);
    double pip = symbol.equals("USDJPY") ? .01 : symbol.equals("XAUUSD") ? .1 : .0001;
    boolean holding=false;
    double entry=0,netPips=0;
    int trades=0,winners=0;
    for (int i=26; i<bars.size()-1; i++) {
      double prevFast=technical.sma(closes,10,i-1);
      double prevSlow=technical.sma(closes,25,i-1);
      double fast=technical.sma(closes,10,i);
      double slow=technical.sma(closes,25,i);
      if(!holding && prevFast<=prevSlow && fast>slow) {
        entry=bars.get(i+1).open(); holding=true;
      } else if(holding && prevFast>=prevSlow && fast<slow) {
        double pips=(bars.get(i+1).open()-entry)/pip-spreadPips;
        netPips+=pips; trades++; if(pips>0) winners++;
        holding=false;
      }
    }
    return Map.of("symbol",symbol,"strategy",strategy,"source","SYNTHETIC_DEMO",
      "tradesClosed",trades,"winningTrades",winners,"netPips",Math.round(netPips*100.0)/100.0,
      "spreadPipsPerRoundTrip",spreadPips,"openPositionNotMarkedToMarket",holding,
      "disclaimer","Not historical data, not a reliable performance estimate");
  }
}