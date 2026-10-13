package com.tradeyar.app.v05;

import com.tradeyar.app.market.MarketService;
import java.io.BufferedReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.time.Instant;
import java.util.*;
import org.springframework.stereotype.Service;

/** Deterministic demonstration fallback or explicitly configured local read-only MT5 bar export. */
@Service
public class MarketBars {
  public record Bar(long time,double open,double high,double low,double close,long volume) {}
  public record Dataset(String symbol,String timeframe,String source,boolean realFeed,boolean fresh,
                        String reason,String fetchedAtUtc,String lastClosedBarUtc,List<Bar> bars) {}
  private final MarketService demo;
  public MarketBars(MarketService demo){this.demo=demo;}
  public static final Set<String> FRAMES=Set.of("M1","M5","M15","M30","H1","H4","D1","W1","MN1");
  public static String frame(String v){String s=v==null?"H1":v.trim().toUpperCase(Locale.ROOT);if(!FRAMES.contains(s))throw new IllegalArgumentException("Unsupported timeframe");return s;}
  public Dataset read(String symbol,String timeframe){
    symbol=demo.symbol(symbol);timeframe=frame(timeframe);
    String dir=System.getenv("TRADEYAR_MARKET_DIR");
    if(dir!=null&&!dir.isBlank()){
      Path path=Path.of(dir).toAbsolutePath().normalize().resolve(symbol+"_"+timeframe+".csv");
      if(Files.isRegularFile(path)){
        try{
          if(Files.size(path)>12_000_000)throw new IllegalArgumentException("CSV exceeds 12 MB cap");
          List<Bar> rows=new ArrayList<>();long last=0;
          try(BufferedReader reader=Files.newBufferedReader(path,StandardCharsets.UTF_8)){
            String row;int line=0;
            while((row=reader.readLine())!=null){line++;
              if(line==1&&row.trim().equalsIgnoreCase("time,open,high,low,close,volume"))continue;
              if(row.isBlank())continue;
              String[] p=row.trim().split(",",-1);
              if(p.length!=6||line>25000)throw new IllegalArgumentException("Malformed CSV row or excess rows");
              long time=Long.parseLong(p[0]);double o=Double.parseDouble(p[1]),h=Double.parseDouble(p[2]),l=Double.parseDouble(p[3]),c=Double.parseDouble(p[4]);long volume=Long.parseLong(p[5]);
              if(time<=last||time>Instant.now().getEpochSecond()+300||!valid(o)||!valid(h)||!valid(l)||!valid(c)||l>Math.min(o,c)||h<Math.max(o,c)||l>h||volume<0)
                throw new IllegalArgumentException("Invalid candle order or OHLC data");
              rows.add(new Bar(time,o,h,l,c,volume));last=time;
            }
          }
          if(rows.size()<120)throw new IllegalArgumentException("Need at least 120 closed candles");
          // The CSV bridge exports only already closed bars. Reject future timestamps.
          long maxAge= switch(timeframe){case "M1"->300L;case "M5"->1200L;case "M15"->3600L;case "M30"->7200L;case "H1"->14400L;case "H4"->57600L;case "D1"->259200L;case "W1"->1814400L;default->5356800L;};
          // Markets can close on weekends; freshness always separately reported, never assumed.
          boolean fresh=Instant.now().getEpochSecond()-last<=maxAge;
          return new Dataset(symbol,timeframe,"MT5_LOCAL_CSV_READ_ONLY",true,fresh,fresh?"Read-only MT5 exported bars":"Last closed candle is stale; check market hours and bridge",Instant.now().toString(),Instant.ofEpochSecond(last).toString(),List.copyOf(rows));
        }catch(Exception ex){return demo(symbol,timeframe,"CSV_REJECTED: "+ex.getMessage());}
      }
    }
    return demo(symbol,timeframe,"No validated read-only MT5 CSV was found for the requested timeframe");
  }
  private static boolean valid(double x){return Double.isFinite(x)&&x>0;}
  private Dataset demo(String symbol,String frame,String why){
    List<Bar> bars=demo.candles(symbol,500).stream().map(b->new Bar(b.time(),b.open(),b.high(),b.low(),b.close(),b.volume())).toList();
    return new Dataset(symbol,frame,"SYNTHETIC_H1_DEMO",false,false,why+". Demo bars are H1 regardless of requested timeframe",Instant.now().toString(),Instant.ofEpochSecond(bars.get(bars.size()-1).time()).toString(),bars);
  }
}
