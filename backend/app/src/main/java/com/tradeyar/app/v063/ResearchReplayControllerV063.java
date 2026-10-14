package com.tradeyar.app.v063;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.tradeyar.app.v05.MarketBars.Bar;
import com.tradeyar.app.v06.StrategyEngineV06;
import jakarta.servlet.http.HttpServletRequest;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/** Research-only, explicitly enabled local endpoint; never forwards any broker order. */
@RestController
@RequestMapping("/api/v063/research")
public final class ResearchReplayControllerV063 {
 private static final Set<String> SYMBOLS=Set.of("EURUSD","GBPUSD","USDJPY","XAUUSD");
 private static final Set<String> FRAMES=Set.of("M1","M5","M15","M30","H1","H4");
 private final StrategyEngineV06 engine;
 private final ObjectMapper json;
 public ResearchReplayControllerV063(StrategyEngineV06 engine,ObjectMapper json){this.engine=engine;this.json=json;}
 public record Request(String symbol,String timeframe,Integer maxBars,Double pipSize,
                       Double spreadPips,Double slippagePips,Integer holdingBars) {}

 @PostMapping("/replay")
 public ResearchReplayV063.ReplayReport replay(@RequestBody Request req,HttpServletRequest http) {
  String addr=http.getRemoteAddr();
  String secret=System.getenv("TRADEYAR_V063_RESEARCH_TOKEN");
  String supplied=http.getHeader("X-TradeYar-Research-Token");
  if(!Set.of("127.0.0.1","::1","0:0:0:0:0:0:0:1").contains(addr) ||
     !"true".equalsIgnoreCase(System.getenv("TRADEYAR_ENABLE_LOCAL_RESEARCH")) ||
     secret==null||secret.length()<24||supplied==null||
     !MessageDigest.isEqual(secret.getBytes(StandardCharsets.UTF_8),supplied.getBytes(StandardCharsets.UTF_8)))
    throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Local opt-in and research token required");
  if(req==null || !SYMBOLS.contains(req.symbol())||!FRAMES.contains(req.timeframe()))
    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid symbol or intraday frame");
  int cap=req.maxBars()==null?1200:req.maxBars();
  if(cap<600||cap>3000)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"maxBars must be 600..3000");
  String marketDir=System.getenv("TRADEYAR_HISTORY_DIR");
  if(marketDir==null||marketDir.isBlank()){
    String local=System.getenv("LOCALAPPDATA");
    if(local==null||local.isBlank())throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"Set TRADEYAR_HISTORY_DIR");
    marketDir=Path.of(local,"TradeYar","history").toString();
  }
  try {
   List<Bar> bars=readVerified(Path.of(marketDir,req.symbol(),req.timeframe()),req.symbol(),req.timeframe(),cap);
   if(bars.size()<600)throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,"At least 600 verified closed bars required");
   return ResearchReplayV063.replay(engine,bars,req.timeframe(),"V062_LOCAL_ARCHIVE_READ_ONLY",
       req.pipSize()==null? ("USDJPY".equals(req.symbol())?.01:.0001):req.pipSize(),
       req.spreadPips()==null?1.5:req.spreadPips(),
       req.slippagePips()==null?.2:req.slippagePips(),
       req.holdingBars()==null?3:req.holdingBars());
  }catch(ResponseStatusException e){throw e;}
   catch(Exception e){throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY,"Archive verification/replay failed: "+e.getClass().getSimpleName());}
 }
 private List<Bar> readVerified(Path dir,String symbol,String frame,int cap) throws Exception {
  Path canonical=dir.toRealPath();
  JsonNode manifest=json.readTree(Files.readString(canonical.resolve("_manifest.json"),StandardCharsets.UTF_8));
  if(!symbol.equals(manifest.path("symbol").asText()) || !frame.equals(manifest.path("timeframe").asText()))
    throw new IOException("Archive identity mismatch");
  String source=manifest.path("source").asText();
  if(!"MT5_TERMINAL_READ_ONLY".equals(source))throw new IOException("Only v0.6.2 read-only MT5 archive accepted");
  JsonNode periods=manifest.path("periods");if(!periods.isArray())throw new IOException("Invalid manifest periods");
  TreeMap<Long,Bar> all=new TreeMap<>();
  long maxMonthBytes=32_000_000;
  for(JsonNode entry:periods){
   int declared=entry.path("bars").asInt(0);if(declared==0)continue;
   String month=entry.path("month").asText();
   String name=entry.path("relativePath").asText();
   if(!month.matches("\\d{4}-(0[1-9]|1[0-2])") || !name.equals(month+".csv"))throw new IOException("Unsafe shard name");
   Path file=canonical.resolve(name).toRealPath();
   if(!canonical.equals(file.getParent())||Files.size(file)>maxMonthBytes)throw new IOException("Invalid archive shard");
   byte[] bytes=Files.readAllBytes(file);
   byte[] digest=MessageDigest.getInstance("SHA-256").digest(bytes);
   StringBuilder hex=new StringBuilder();for(byte b:digest)hex.append(String.format("%02x",b & 255));
   if(!hex.toString().equalsIgnoreCase(entry.path("sha256").asText()))throw new IOException("Manifest checksum mismatch");
   int count=0;long previous=Long.MIN_VALUE;
   try(BufferedReader br=new BufferedReader(new InputStreamReader(new ByteArrayInputStream(bytes),StandardCharsets.UTF_8))){
    if(!"time,open,high,low,close,volume".equals(br.readLine()))throw new IOException("Unexpected CSV header");
    String line;
    while((line=br.readLine())!=null){
      String[] x=line.split(",",-1);if(x.length!=6)throw new IOException("Invalid CSV columns");
      long t=Long.parseLong(x[0]);double o=Double.parseDouble(x[1]),h=Double.parseDouble(x[2]),l=Double.parseDouble(x[3]),c=Double.parseDouble(x[4]);long volume=Long.parseLong(x[5]);
      if(t<=previous || t>Instant.now().getEpochSecond() || volume<0 ||
         !Double.isFinite(o)||!Double.isFinite(h)||!Double.isFinite(l)||!Double.isFinite(c)||
         o<=0||h<=0||l<=0||c<=0||l>Math.min(o,c)||h<Math.max(o,c)||l>h)
        throw new IOException("Invalid OHLC / timestamp");
      previous=t;count++;
      Bar prior=all.putIfAbsent(t,new Bar(t,o,h,l,c,volume));
      if(prior!=null)throw new IOException("Duplicated monthly bar timestamp");
      while(all.size()>cap)all.pollFirstEntry();
    }
   }
   if(count!=declared)throw new IOException("Shard row-count mismatch");
  }
  return List.copyOf(all.values());
 }
}
