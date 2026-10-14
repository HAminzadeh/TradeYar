package com.tradeyar.app.v06;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

/** Read-only SSE; periodic snapshots, not broker tick streaming. */
@RestController
@RequestMapping("/api/v06")
public class StreamingV06 {
 private final AnalysisV06 analysis;
 private final ConcurrentHashMap<String,Client> clients=new ConcurrentHashMap<>();
 private record Client(SseEmitter e,String symbol,String timeframe,String style) {}
 public StreamingV06(AnalysisV06 analysis){this.analysis=analysis;}
 @GetMapping(path="/stream",produces="text/event-stream")
 public SseEmitter stream(@RequestParam(name="symbol",defaultValue="EURUSD")String symbol,
   @RequestParam(name="timeframe",defaultValue="H1")String timeframe,
   @RequestParam(name="style",defaultValue="INTRADAY")String style){
   Map<String,Object> initial=analysis.snapshot(symbol,timeframe,style);
   if(clients.size()>=32)throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,"SSE capacity reached");
   var id=UUID.randomUUID().toString();var e=new SseEmitter(120000L);
   clients.put(id,new Client(e,symbol,timeframe,style));
   e.onCompletion(()->clients.remove(id));e.onTimeout(()->clients.remove(id));e.onError(ex->clients.remove(id));
   try{e.send(SseEmitter.event().name("snapshot").data(initial));}
   catch(Exception ex){clients.remove(id);e.completeWithError(ex);}return e;
 }
 @Scheduled(fixedDelay=10000)
 public void publish(){Map<String,Map<String,Object>> cache=new HashMap<>();
   clients.forEach((id,c)->{try{
     String key=c.symbol()+"/"+c.timeframe()+"/"+c.style();
     Map<String,Object> data=cache.computeIfAbsent(key,k->analysis.snapshot(c.symbol(),c.timeframe(),c.style()));
     c.e().send(SseEmitter.event().name("snapshot").data(data));
   }catch(Exception ex){clients.remove(id);try{c.e().completeWithError(ex);}catch(Exception ignored){}}});
 }
}
