package com.tradeyar.app.v05;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.*;
import org.springframework.web.bind.annotation.*;

/** Reproducible educational SMA-cross backtest with chronological out-of-sample split. Not ML training. */
@RestController
@RequestMapping("/api/v05/research")
public class ResearchV05 {
 private final MarketBars feed;private final ObjectMapper json;
 public ResearchV05(MarketBars feed,ObjectMapper json){this.feed=feed;this.json=json;}
 public record Request(String symbol,String timeframe,String strategy,double spreadPips){}
 @GetMapping("/status") public Map<String,Object> status(){
   return Map.of("phase","HISTORICAL_RESEARCH","machineLearningTrained",false,"validatedModels",0,
     "historicalDatasetConnected","CHECK_PER_SYMBOL","persistence","JSONL_LOCAL_AND_OPTIONAL_POSTGRES_IMPORT",
     "strategyBacktesting","SMA_CROSS_EDUCATIONAL_ONLY","trainingClaimsAllowed",false);
 }
 @PostMapping("/run") public Map<String,Object> run(@RequestBody Request req)throws Exception{
   if(req==null||!"SMA_CROSS".equals(req.strategy()))throw new IllegalArgumentException("Only SMA_CROSS reproducible demonstrator supported in this phase");
   if(!Double.isFinite(req.spreadPips())||req.spreadPips()<0||req.spreadPips()>100)throw new IllegalArgumentException("Invalid spread");
   MarketBars.Dataset data=feed.read(req.symbol(),req.timeframe());
   if(data.bars().size()<120)throw new IllegalArgumentException("Not enough bars");
   int cut=(int)(data.bars().size()*.7);
   Map<String,Object> train=evaluate(data.bars().subList(0,cut),data.symbol(),req.spreadPips());
   Map<String,Object> test=evaluate(data.bars().subList(cut,data.bars().size()),data.symbol(),req.spreadPips());
   Map<String,Object> outcome=new LinkedHashMap<>();
   outcome.put("runId",UUID.randomUUID().toString());outcome.put("atUtc",Instant.now().toString());
   outcome.put("symbol",data.symbol());outcome.put("timeframe",data.timeframe());outcome.put("source",data.source());
   outcome.put("historicallyVerified",false);outcome.put("trainedModel",false);outcome.put("dataFresh",data.fresh());
   outcome.put("strategy",req.strategy());outcome.put("spreadPips",req.spreadPips());
   outcome.put("dataHashSha256",hash(data.bars()));outcome.put("totalBars",data.bars().size());
   outcome.put("trainingPeriod",train);outcome.put("heldOutPeriod",test);
   outcome.put("warning","Illustrative next-bar-open fills, no commission/swaps/slippage, no walk-forward retraining. Held-out segment is not untouched after repeated manual tuning. Not investment evidence.");
   String path=System.getenv("TRADEYAR_RESEARCH_DIR");
   if(path==null||path.isBlank()){
     String local=System.getenv("LOCALAPPDATA");path=local!=null&&!local.isBlank()?Path.of(local,"TradeYar","research").toString():Path.of(System.getProperty("user.home"),".tradeyar","research").toString();
   }
   Path dir=Path.of(path).toAbsolutePath().normalize();Files.createDirectories(dir);
   Path log=dir.resolve("research-runs.jsonl");
   synchronized(ResearchV05.class){Files.writeString(log,json.writeValueAsString(outcome)+"\n",StandardCharsets.UTF_8,StandardOpenOption.CREATE,StandardOpenOption.APPEND);}
   outcome.put("savedToLocalResearchLog",true);return outcome;
 }
 private String hash(List<MarketBars.Bar>bars)throws Exception{MessageDigest md=MessageDigest.getInstance("SHA-256");for(var b:bars)md.update((b.time()+","+b.open()+","+b.high()+","+b.low()+","+b.close()+","+b.volume()+"\n").getBytes(StandardCharsets.UTF_8));return HexFormat.of().formatHex(md.digest());}
 private Map<String,Object> evaluate(List<MarketBars.Bar> bars,String symbol,double spread){
   if(bars.size()<45)return Map.of("tradesClosed",0,"netPips",0.0,"bars",bars.size(),"note","Insufficient period");
   double pip=symbol.equals("USDJPY")?.01:symbol.equals("XAUUSD")?.1:.0001;
   int n=bars.size(),trades=0,wins=0;double net=0,peak=0,maxDD=0,entry=0;boolean holding=false;
   for(int i=31;i<n-1;i++){
     double fast=avg(bars,i,10),slow=avg(bars,i,30),pf=avg(bars,i-1,10),ps=avg(bars,i-1,30);
     if(!holding&&pf<=ps&&fast>slow){entry=bars.get(i+1).open();holding=true;}
     else if(holding&&pf>=ps&&fast<slow){double pips=(bars.get(i+1).open()-entry)/pip-spread;net+=pips;trades++;if(pips>0)wins++;peak=Math.max(peak,net);maxDD=Math.max(maxDD,peak-net);holding=false;}
   }
   return Map.of("bars",n,"tradesClosed",trades,"winners",wins,"netPips",Math.round(net*100)/100.0,"maxDrawdownPips",Math.round(maxDD*100)/100.0,"openPositionNotMarkedToMarket",holding);
 }
 private double avg(List<MarketBars.Bar>b,int end,int len){double a=0;for(int i=end-len+1;i<=end;i++)a+=b.get(i).close();return a/len;}
}
