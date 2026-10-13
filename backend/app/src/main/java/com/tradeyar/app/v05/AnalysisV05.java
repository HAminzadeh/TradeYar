package com.tradeyar.app.v05;

import java.time.Instant;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.*;

@Service
public class AnalysisV05 {
 private final MarketBars feed;private final StrategyEngineV05 engine;
 public AnalysisV05(MarketBars feed,StrategyEngineV05 engine){this.feed=feed;this.engine=engine;}
 public static final Set<String> STYLES=Set.of("SCALP","INTRADAY","SWING","POSITION","WEEKLY","CUSTOM");
 public Map<String,Object> snapshot(String symbol,String timeframe,String style){
   style=style==null?"INTRADAY":style.toUpperCase(Locale.ROOT);
   if(!STYLES.contains(style))throw new IllegalArgumentException("Invalid trading style");
   MarketBars.Dataset data=feed.read(symbol,timeframe);
   // Synthetic fallback is always H1, irrespective of the wizard choice.
   String effective=data.realFeed()?data.timeframe():"H1";
   List<StrategyEngineV05.Result> results=engine.evaluateAll(data.bars(),effective);
   Map<String,Integer> counts=new LinkedHashMap<>();for(String k:List.of("BUY","SELL","NO_SIGNAL","NOT_EVALUATED"))counts.put(k,0);
   for(var r:results)counts.compute(r.signal(),(k,v)->v==null?1:v+1);
   int aligned=Math.max(counts.get("BUY"),counts.get("SELL"));
   String status= !data.realFeed()?"DEMO_DATA_NOT_TRADEABLE":!data.fresh()?"STALE_MARKET_DATA":aligned<16?"NO_16_OF_20_CONSENSUS":"UNVERIFIED_DATA_AND_STRATEGIES";
   double bid=data.bars().get(data.bars().size()-1).close();
   double spread=data.symbol().equals("XAUUSD")?.25:data.symbol().equals("USDJPY")?.02:.0002;
   Map<String,Object> quote=Map.of("bid",bid,"ask",bid+spread,"source",data.source(),"executable",false);
   Map<String,Object> result=new LinkedHashMap<>();
   result.put("symbol",data.symbol());result.put("style",style);
   result.put("requestedTimeframe",data.timeframe());result.put("effectiveTimeframe",effective);
   result.put("requestedTimeframeApplied",data.realFeed());
   result.put("source",data.source());result.put("verifiedBrokerFeed",false);result.put("localReadOnlyCsvAvailable",data.realFeed());result.put("fresh",data.fresh());
   result.put("lastClosedBarUtc",data.lastClosedBarUtc());result.put("sampledAtUtc",Instant.now().toString());
   result.put("feedNote",data.reason());result.put("quote",quote);
   result.put("candles",data.bars().size()>250?data.bars().subList(data.bars().size()-250,data.bars().size()):data.bars());
   result.put("strategies",results);result.put("counts",counts);result.put("strategyCount",20);result.put("minimumAligned",16);
   result.put("aligned",aligned);result.put("decision",status);
   result.put("entryAllowed",false);result.put("realExecutionEnabled",false);result.put("paperReviewAllowed",false);
   result.put("validationNote","Twenty educational rule implementations; no independent out-of-sample or broker validation. The 16/20 vote threshold does NOT imply 80 percent win probability.");
   return result;
 }
}

@RestController
@RequestMapping("/api/v05")
class AnalysisV05Controller {
 private final AnalysisV05 service;
 AnalysisV05Controller(AnalysisV05 service){this.service=service;}
 @GetMapping("/snapshot")
 public Map<String,Object> snapshot(@RequestParam(name="symbol",defaultValue="EURUSD")String symbol,
      @RequestParam(name="timeframe",defaultValue="H1")String frame,
      @RequestParam(name="style",defaultValue="INTRADAY")String style){return service.snapshot(symbol,frame,style);}
 @GetMapping("/capabilities")
 public Map<String,Object> capabilities(){return Map.of("strategyDefinitions",20,"independentlyValidatedStrategies",0,
     "mt5RealTradingSupported",false,"realExecutionEnabled",false,
     "marketSource","OPTIONAL_LOCAL_READONLY_CSV_WITH_SYNTHETIC_FALLBACK",
     "streamTransport","SSE","trainingModelReady",false,
     "knowledgeMode","REPRODUCIBLE_EDUCATIONAL_BACKTEST_ONLY");}
}
