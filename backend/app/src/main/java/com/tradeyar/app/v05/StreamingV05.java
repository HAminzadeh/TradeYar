package com.tradeyar.app.v05;

import java.io.IOException;
import java.util.*;
import java.util.concurrent.*;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@Configuration
@EnableScheduling
class TradeYarV05Scheduling {}

/** SSE dispatches periodic analysis snapshots, NOT a broker push subscription. */
@RestController
@RequestMapping("/api/v05")
public class StreamingV05 {
 private final AnalysisV05 analysis;
 private final ConcurrentHashMap<String,Client> clients=new ConcurrentHashMap<>();
 private record Client(SseEmitter emitter,String symbol,String timeframe,String style){}
 public StreamingV05(AnalysisV05 analysis){this.analysis=analysis;}
 @GetMapping(path="/stream",produces="text/event-stream")
 public SseEmitter stream(@RequestParam(name="symbol",defaultValue="EURUSD")String symbol,
                          @RequestParam(name="timeframe",defaultValue="H1")String timeframe,
                          @RequestParam(name="style",defaultValue="INTRADAY")String style){
   // Input validation before reserving an emitter, preventing malformed subscriptions.
   analysis.snapshot(symbol,timeframe,style);
   if(clients.size()>=48)throw new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.TOO_MANY_REQUESTS,"SSE client capacity reached");
   String id=UUID.randomUUID().toString();SseEmitter e=new SseEmitter(0L);
   clients.put(id,new Client(e,symbol,timeframe,style));
   e.onCompletion(()->clients.remove(id));e.onTimeout(()->clients.remove(id));e.onError(ex->clients.remove(id));
   try{e.send(SseEmitter.event().name("state").data(Map.of("transport","SSE","mode","READ_ONLY","source","SERVER_SIDE_POLLING")));
       e.send(SseEmitter.event().name("snapshot").data(analysis.snapshot(symbol,timeframe,style)));}
   catch(Exception ex){clients.remove(id);e.completeWithError(ex);}
   return e;
 }
 @Scheduled(fixedDelay=10000)
 public void publish(){
   Map<String,Map<String,Object>>cache=new HashMap<>();
   clients.forEach((id,c)->{
     try{
       String key=c.symbol()+"|"+c.timeframe()+"|"+c.style();
       Map<String,Object>out=cache.computeIfAbsent(key,k->analysis.snapshot(c.symbol(),c.timeframe(),c.style()));
       c.emitter().send(SseEmitter.event().name("snapshot").data(out));
     }catch(Exception ex){clients.remove(id);try{c.emitter().completeWithError(ex);}catch(Exception ignored){}}
   });
 }
}
