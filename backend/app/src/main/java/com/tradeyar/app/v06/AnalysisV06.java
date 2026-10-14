package com.tradeyar.app.v06;

import com.tradeyar.app.v05.MarketBars;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ConcurrentHashMap;
import java.time.Instant;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.*;

@Service
public class AnalysisV06 {
 private final MarketBars feed;private final StrategyEngineV06 engine;
 private final ObjectMapper mapper=new ObjectMapper();
 private final Set<String> seen=ConcurrentHashMap.newKeySet();
 private static final Object IO_LOCK=new Object();
 public AnalysisV06(MarketBars feed,StrategyEngineV06 engine){this.feed=feed;this.engine=engine;}
 public static final Set<String> STYLES=Set.of("SCALP","INTRADAY","SWING","POSITION","WEEKLY","CUSTOM");
 /** Append one auditable signal snapshot per finished bar, not every SSE heartbeat. */
 private String archive(Map<String,Object> result){
   String key=result.get("symbol")+"|"+result.get("effectiveTimeframe")+"|"+result.get("style")+"|"+result.get("lastClosedBarUtc")+"|V06";
   if(!seen.add(key))return "ALREADY_ARCHIVED_IN_PROCESS";
   try{
     String configured=System.getenv("TRADEYAR_RESEARCH_DIR");
     Path dir=configured==null||configured.isBlank()?Path.of(System.getProperty("user.home"),".tradeyar","research"):Path.of(configured);
     Map<String,Object> event=new LinkedHashMap<>();
     for(String k:List.of("symbol","style","effectiveTimeframe","source","lastClosedBarUtc","decision","counts","strategies"))event.put(k,result.get(k));
     event.put("engineVersion","V06_RESEARCH_RULES");event.put("independentlyValidated",false);
     synchronized(IO_LOCK){Files.createDirectories(dir);
       Files.writeString(dir.resolve("analysis-events-v06.jsonl"),mapper.writeValueAsString(event)+"\n",StandardCharsets.UTF_8,StandardOpenOption.CREATE,StandardOpenOption.APPEND);}
     return "LOCAL_RESEARCH_ARCHIVED_DB_SYNC_PENDING";
   }catch(Exception e){seen.remove(key);return "ARCHIVE_FAILED_"+e.getClass().getSimpleName();}
 }

 public Map<String,Object> snapshot(String symbol,String timeframe,String style){
   style=style==null?"INTRADAY":style.toUpperCase(Locale.ROOT);
   if(!STYLES.contains(style))throw new IllegalArgumentException("Invalid trading style");
   MarketBars.Dataset data=feed.read(symbol,timeframe);
   String effective=data.realFeed()?data.timeframe():"H1";
   var results=engine.evaluateAll(data.bars(),effective);
   Map<String,Integer> counts=new LinkedHashMap<>();for(String key:List.of("BUY","SELL","NO_SIGNAL","NOT_EVALUATED"))counts.put(key,0);
   for(var r:results)counts.merge(r.signal(),1,Integer::sum);
   int aligned=Math.max(counts.get("BUY"),counts.get("SELL"));
   String decision=!data.realFeed()?"DEMO_DATA_NOT_TRADEABLE":!data.fresh()?"STALE_MARKET_DATA":aligned<16?"NO_16_OF_20_CONSENSUS":"UNVERIFIED_DATA_AND_STRATEGIES";
   double bid=data.bars().get(data.bars().size()-1).close();
   Map<String,Object> result=new LinkedHashMap<>();
   result.put("symbol",data.symbol());result.put("style",style);
   result.put("requestedTimeframe",data.timeframe());result.put("effectiveTimeframe",effective);
   result.put("requestedTimeframeApplied",data.realFeed());result.put("source",data.source());
   result.put("verifiedBrokerFeed",false);result.put("localReadOnlyCsvAvailable",data.realFeed());result.put("fresh",data.fresh());
   result.put("lastClosedBarUtc",data.lastClosedBarUtc());result.put("sampledAtUtc",Instant.now().toString());result.put("feedNote",data.reason());
   result.put("quote",Map.of("bid",bid,"ask",bid,"source",data.source(),"tradable",false,"indicativeMidOnly",true));
   var bars=data.bars();result.put("candles",bars.size()>250?bars.subList(bars.size()-250,bars.size()):bars);
   result.put("strategies",results);result.put("counts",counts);result.put("strategyCount",results.size());
   result.put("aligned",aligned);result.put("minimumAligned",16);result.put("decision",decision);
   result.put("entryAllowed",false);result.put("paperReviewAllowed",false);result.put("realExecutionEnabled",false);
   result.put("validationNote","All 20 rules are educational and UNVALIDATED. Local CSV does not prove broker provenance. 16/20 votes do not imply an 80% win probability.");
   result.put("analysisArchiveStatus",data.realFeed()?archive(result):"DEMO_NOT_ARCHIVED_AS_MARKET_EVIDENCE");
   return result;
 }
}

@RestController
@RequestMapping("/api/v06")
class AnalysisV06Controller {
 private final AnalysisV06 service;
 AnalysisV06Controller(AnalysisV06 service){this.service=service;}
 @GetMapping("/snapshot") public Map<String,Object> snapshot(
     @RequestParam(name="symbol",defaultValue="EURUSD")String symbol,
     @RequestParam(name="timeframe",defaultValue="H1")String timeframe,
     @RequestParam(name="style",defaultValue="INTRADAY")String style){return service.snapshot(symbol,timeframe,style);}
 @GetMapping("/capabilities") public Map<String,Object> capabilities(){return Map.of(
   "strategyDefinitions",20,"strategyEngineVersion","V06_RESEARCH_RULES", "independentlyValidatedStrategies",0,
   "historicalTenYearTrainingComplete",false,"trainedMLModels",0,
   "marketSource","OPTIONAL_LOCAL_MT5_READONLY_CSV", "realExecutionEnabled",false,
   "brokerQuoteValidated",false,"dataProvenanceVerified",false,"helpCenterAvailable",true);
 }
}
