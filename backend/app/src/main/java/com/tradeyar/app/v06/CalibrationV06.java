package com.tradeyar.app.v06;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tradeyar.app.v05.MarketBars;
import com.tradeyar.app.v05.MarketBars.Bar;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.MessageDigest;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;
import jakarta.annotation.PreDestroy;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/**
 * Locally authorized, single-worker calibration demo. A time-separated investigation, NOT ML.
 * Uses read-only MT5 CSV samples when available; never treats synthetic data as training evidence.
 */
@Service
public final class CalibrationV06 {
 public record Request(String symbol,String timeframe,String style,double spreadPips,double slippagePips) {}
 private final MarketBars market;private final StrategyEngineV06 strategies;private final ObjectMapper mapper;
 private final ExecutorService worker=Executors.newSingleThreadExecutor(r->{Thread t=new Thread(r,"tradeyar-research-v06");t.setDaemon(true);return t;});
 private final AtomicReference<Map<String,Object>> status=new AtomicReference<>(Map.of("state","IDLE","completed",0,"total",20,"trainedMLModels",0));
 private final java.util.concurrent.atomic.AtomicBoolean busy=new java.util.concurrent.atomic.AtomicBoolean(false);
 public CalibrationV06(MarketBars market,StrategyEngineV06 strategies,ObjectMapper mapper){this.market=market;this.strategies=strategies;this.mapper=mapper;}
 @PreDestroy public void shutdown(){worker.shutdownNow();}
 public Map<String,Object> status(){return status.get();}
 public Map<String,Object> start(Request r,HttpServletRequest request){
   String env=System.getenv("TRADEYAR_ENABLE_LOCAL_RESEARCH");
   if(!"true".equalsIgnoreCase(env))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Local research disabled. Set TRADEYAR_ENABLE_LOCAL_RESEARCH=true on trusted workstation");
   if(request==null||!("127.0.0.1".equals(request.getRemoteAddr())||"0:0:0:0:0:0:0:1".equals(request.getRemoteAddr())||"::1".equals(request.getRemoteAddr())))
     throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Local research requires loopback client");
   if(r==null||r.symbol()==null||r.timeframe()==null||r.style()==null||!AnalysisV06.STYLES.contains(r.style().toUpperCase(Locale.ROOT))||
       !Double.isFinite(r.spreadPips())||r.spreadPips()<0||r.spreadPips()>50||
       !Double.isFinite(r.slippagePips())||r.slippagePips()<0||r.slippagePips()>50)throw new IllegalArgumentException("Invalid research input");
   MarketBars.Dataset data=market.read(r.symbol(),r.timeframe());
   if(!data.realFeed())throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,"Real historical CSV required; synthetic dataset cannot be calibrated");
   if(data.bars().size()<600)throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,"At least 600 closed bars required for preliminary split");
   if(!busy.compareAndSet(false,true))throw new ResponseStatusException(HttpStatus.CONFLICT,"A calibration run is already active");
   String id=UUID.randomUUID().toString();var bars=List.copyOf(data.bars().subList(Math.max(0,data.bars().size()-1200),data.bars().size()));
   var initial=state(id,"RUNNING",0,"Starting chronological 60/20/20 research",null);
   status.set(initial);
   worker.execute(()->{
      try{var result=calibrate(id,r,data,bars);status.set(state(id,"COMPLETED",20,"Research completed; no strategies approved",result));}
      catch(Exception ex){status.set(state(id,"FAILED",0,"Research failed: "+ex.getClass().getSimpleName(),null));}
      finally{busy.set(false);}
   });
   return initial;
 }
 private Map<String,Object> state(String id,String state,int completed,String message,Object report){
   Map<String,Object> m=new LinkedHashMap<>();m.put("runId",id);m.put("state",state);m.put("completed",completed);m.put("total",20);
   m.put("message",message);m.put("trainedMLModels",0);m.put("independentlyValidated",false);m.put("result",report);return m;
 }
 public Map<String,Object> calibrate(String id,Request r,MarketBars.Dataset dataset,List<Bar> bars)throws Exception{
   int n=bars.size(),a=(int)(n*.6),b=(int)(n*.8);List<Map<String,Object>> rows=new ArrayList<>();
   for(String key:StrategyEngineV06.IDS){
     StrategyEngineV06.Parameters best=StrategyEngineV06.DEFAULT;double score=-Double.MAX_VALUE;
     for(var p:StrategyEngineV06.PRESETS){Map<String,Object> s=evaluate(key,bars,Math.max(260,p.slow()+80),a,p,r.spreadPips(),r.slippagePips(),r.symbol(),r.timeframe());
       double value=(double)s.get("netPips")-.35*(double)s.get("maxDrawdownPips");
       if((int)s.get("tradesClosed")>=3&&value>score){score=value;best=p;}
     }
     Map<String,Object> train=evaluate(key,bars,Math.max(260,best.slow()+80),a,best,r.spreadPips(),r.slippagePips(),r.symbol(),r.timeframe());
     Map<String,Object> validation=evaluate(key,bars,a,b,best,r.spreadPips(),r.slippagePips(),r.symbol(),r.timeframe());
     Map<String,Object> heldout=evaluate(key,bars,b,n-1,best,r.spreadPips(),r.slippagePips(),r.symbol(),r.timeframe());
     rows.add(Map.of("strategy",key,"chosenTrainingOnlyPreset",best.name(),"training",train,"validation",validation,"heldOut",heldout));
     status.set(state(id,"RUNNING",rows.size(),"Completed "+key+"; hold-out remains read-only",null));
   }
   long first=bars.get(0).time(),last=bars.get(n-1).time();double years=(last-first)/(86400.0*365.2425);
   Map<String,Object> result=new LinkedHashMap<>();result.put("runId",id);result.put("createdAtUtc",Instant.now().toString());
   result.put("symbol",dataset.symbol());result.put("timeframe",dataset.timeframe());result.put("style",r.style());
   result.put("source",dataset.source());result.put("verifiedBrokerProvenance",false);
   result.put("coveredYearsInProcessedWindow",Math.round(years*1000)/1000.0);result.put("processedBars",n);
   result.put("tenYearTrainingComplete",false);result.put("trainedMLModels",0);result.put("independentlyValidated",false);
   result.put("datasetSha256",fingerprint(bars));result.put("rows",rows);
   result.put("limitations","Preliminary time-separated 60/20/20 evaluation on at most 1200 bars. Training-only parameter selection among 3 bounded presets; hold-out never used to select. No full-decade import, walk-forward, tick-execution model, verified broker fills or ML training. No trading authorization.");
   String folder=System.getenv("TRADEYAR_RESEARCH_DIR");
   Path dir=folder==null||folder.isBlank()?Path.of(System.getProperty("user.home"),".tradeyar","research"):Path.of(folder);
   Files.createDirectories(dir);Path file=dir.resolve("v06-"+id+".json");
   Files.writeString(file,mapper.writerWithDefaultPrettyPrinter().writeValueAsString(result),StandardCharsets.UTF_8,StandardOpenOption.CREATE_NEW);
   result.put("savedToLocalResearchLog",true);return result;
 }
 private Map<String,Object> evaluate(String id,List<Bar>bars,int start,int end,StrategyEngineV06.Parameters params,double spread,double slip,String symbol,String frame){
   double pip="USDJPY".equals(symbol)?.01:"XAUUSD".equals(symbol)?.1:.0001;double pnl=0,peak=0,dd=0;int trades=0,wins=0,position=0;double entry=0;
   start=Math.min(Math.max(start,265),end);int cutoff=Math.max(0,start-270);
   for(int i=start;i<end;i++){
     List<Bar>visible=bars.subList(cutoff,i+1);var vote=strategies.evaluate(id,visible,frame,params);
     int wanted="BUY".equals(vote.signal())?1:"SELL".equals(vote.signal())?-1:position;
     if(wanted==position)continue;
     double open=bars.get(i+1).open();double costs=spread+slip;
     if(position!=0){double delta=(open-entry)/pip*position-costs;pnl+=delta;trades++;if(delta>0)wins++;peak=Math.max(peak,pnl);dd=Math.max(dd,peak-pnl);}
     position=wanted;entry=open;
   }
   Map<String,Object> res=new LinkedHashMap<>();res.put("bars",Math.max(0,end-start));res.put("tradesClosed",trades);res.put("winningTrades",wins);
   res.put("netPips",Math.round(pnl*100)/100.0);res.put("maxDrawdownPips",Math.round(dd*100)/100.0);
   res.put("openPositionNotMarkedToMarket",position!=0);res.put("costPipsPerClosedTrade",spread+slip);
   res.put("futureLeakagePrevented",true);return res;
 }
 private String fingerprint(List<Bar>rows)throws Exception{MessageDigest h=MessageDigest.getInstance("SHA-256");for(var x:rows)h.update((x.time()+","+x.open()+","+x.high()+","+x.low()+","+x.close()+","+x.volume()+"\n").getBytes(StandardCharsets.UTF_8));return HexFormat.of().formatHex(h.digest());}
}

@RestController
@RequestMapping("/api/v06/calibration")
class CalibrationV06Controller {
 private final CalibrationV06 c;CalibrationV06Controller(CalibrationV06 c){this.c=c;}
 @GetMapping("/status")public Map<String,Object> status(){return c.status();}
 @PostMapping("/start")public Map<String,Object> start(@RequestBody CalibrationV06.Request r,HttpServletRequest request){return c.start(r,request);}
}
