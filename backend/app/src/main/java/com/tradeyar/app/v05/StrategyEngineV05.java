package com.tradeyar.app.v05;

import java.util.*;
import org.springframework.stereotype.Service;
import static java.lang.Math.*;

/** 20 deterministic, parameter-fixed educational implementations. NOT independently validated or approved to trade. */
@Service
public class StrategyEngineV05 {
  public static final List<String> IDS=List.of("SMA_CROSS","EMA_CROSS","TRIPLE_EMA","SUPERTREND","MACD","RSI_REVERSAL","STOCHASTIC","CCI","DONCHIAN_BREAKOUT","ATR_BREAKOUT","BOLLINGER_SQUEEZE","LONDON_BREAKOUT","BOLLINGER_MEAN_REVERSION","RSI_DIVERGENCE","KELTNER_MEAN_REVERSION","PIN_BAR","ENGULFING","PIVOT_POINT","ICHIMOKU","MULTI_TF_EMA_ADX");
  public record Result(String id,String signal,boolean implemented,boolean independentlyValidated,String reason,int barsUsed){}
  private static final String NONE="NO_SIGNAL",BUY="BUY",SELL="SELL",NA="NOT_EVALUATED";
  private static double sma(List<Double> x,int end,int n){double a=0;for(int i=end-n+1;i<=end;i++)a+=x.get(i);return a/n;}
  private static double ema(List<Double> x,int end,int n){double e=sma(x,n-1,n),alpha=2.0/(n+1);for(int i=n;i<=end;i++)e=alpha*x.get(i)+(1-alpha)*e;return e;}
  private static double maxHigh(List<MarketBars.Bar>b,int end,int n){double x=-Double.MAX_VALUE;for(int i=end-n+1;i<=end;i++)x=max(x,b.get(i).high());return x;}
  private static double minLow(List<MarketBars.Bar>b,int end,int n){double x=Double.MAX_VALUE;for(int i=end-n+1;i<=end;i++)x=min(x,b.get(i).low());return x;}
  private static double atr(List<MarketBars.Bar>b,int end,int n){double a=0;for(int i=end-n+1;i<=end;i++){MarketBars.Bar q=b.get(i);double pc=b.get(i-1).close();a+=max(q.high()-q.low(),max(abs(q.high()-pc),abs(q.low()-pc)));}return a/n;}
  private static double rsi(List<Double>x,int end,int n){double up=0,down=0;for(int i=end-n+1;i<=end;i++){double d=x.get(i)-x.get(i-1);up+=max(0,d);down+=max(0,-d);}return down==0?(up==0?50:100):100-100/(1+up/down);}
  private static String dir(double p,double n){return p>n?BUY:p<n?SELL:NONE;}
  private static double std(List<Double>x,int end,int n){double m=sma(x,end,n),v=0;for(int i=end-n+1;i<=end;i++)v+=pow(x.get(i)-m,2);return sqrt(v/n);}
  private static double cci(List<MarketBars.Bar>b,int end,int n){double[] tp=new double[n];double avg=0;for(int k=0;k<n;k++){var p=b.get(end-n+1+k);tp[k]=(p.high()+p.low()+p.close())/3.0;avg+=tp[k];}avg/=n;double meanAbs=0;for(double t:tp)meanAbs+=abs(t-avg);meanAbs/=n;return meanAbs<1e-10?0:(tp[n-1]-avg)/(.015*meanAbs);}
  private static double adxEstimate(List<MarketBars.Bar>b,int end,int n){double up=0,down=0,vol=0;for(int i=end-n+1;i<=end;i++){var q=b.get(i);var p=b.get(i-1);up+=max(0,q.high()-p.high());down+=max(0,p.low()-q.low());vol+=max(q.high()-q.low(),1e-9);}return 100*abs(up-down)/max(vol,1e-9);}
  /** Aggregate only complete higher-timeframe groups, using timestamp-aligned UTC bar buckets. */
  private static List<MarketBars.Bar> higherBars(List<MarketBars.Bar> bars,String frame){
    long seconds=switch(frame){case "M1"->300L;case "M5"->900L;case "M15"->3600L;case "M30"->3600L;case "H1"->14400L;case "H4"->86400L;default->0L;};
    if(seconds==0)return List.of();
    int ratio=switch(frame){case "M1"->5;case "M5"->3;case "M15"->4;case "M30"->2;case "H1"->4;case "H4"->6;default->0;};
    List<MarketBars.Bar> out=new ArrayList<>();long previous=-1;int seen=0;MarketBars.Bar start=null,end=null;double hi=0,lo=0;long vol=0;
    for(MarketBars.Bar bar:bars){long bucket=bar.time()/seconds;
      if(bucket!=previous){if(previous!=-1&&seen==ratio)out.add(new MarketBars.Bar(start.time(),start.open(),hi,lo,end.close(),vol));
        previous=bucket;seen=0;start=bar;hi=bar.high();lo=bar.low();vol=0;}
      seen++;end=bar;hi=Math.max(hi,bar.high());lo=Math.min(lo,bar.low());vol+=bar.volume();
    }
    if(seen==ratio&&start!=null&&end!=null)out.add(new MarketBars.Bar(start.time(),start.open(),hi,lo,end.close(),vol));
    return out;
  }
  public List<Result> evaluateAll(List<MarketBars.Bar> bars,String actualFrame){List<Result>out=new ArrayList<>();for(String id:IDS)out.add(evaluate(id,bars,actualFrame));return out;}
  public Result evaluate(String id,List<MarketBars.Bar>b,String frame){
    if(!IDS.contains(id))throw new IllegalArgumentException("Unknown strategy");
    if(b==null||b.size()<120)return new Result(id,NA,true,false,"At least 120 closed bars required",b==null?0:b.size());
    int z=b.size()-1;List<Double>c=b.stream().map(MarketBars.Bar::close).toList();
    try{
      double close=c.get(z),prev=c.get(z-1),a=atr(b,z,14);String s=NONE;String note="Technical rule evaluated on closed bars; no validation";
      switch(id){
        case "SMA_CROSS" -> {double fast=sma(c,z,10),slow=sma(c,z,30),pf=sma(c,z-1,10),ps=sma(c,z-1,30);s=pf<=ps&&fast>slow?BUY:pf>=ps&&fast<slow?SELL:NONE;}
        case "EMA_CROSS" -> {double fast=ema(c,z,9),slow=ema(c,z,21),pf=ema(c,z-1,9),ps=ema(c,z-1,21);s=pf<=ps&&fast>slow?BUY:pf>=ps&&fast<slow?SELL:NONE;}
        case "TRIPLE_EMA" -> {double f=ema(c,z,9),m=ema(c,z,21),l=ema(c,z,55);s=f>m&&m>l?BUY:f<m&&m<l?SELL:NONE;}
        case "SUPERTREND" -> {double mid=(b.get(z).high()+b.get(z).low())/2;s=close>mid+2*a?BUY:close<mid-2*a?SELL:NONE;note="Simplified ATR price-band filter, not canonical recursive Supertrend";}
        case "MACD" -> {double macd=ema(c,z,12)-ema(c,z,26),pm=ema(c,z-1,12)-ema(c,z-1,26);s=pm<=0&&macd>0?BUY:pm>=0&&macd<0?SELL:NONE;note="MACD zero-cross variation (12,26); no signal-line confirmation";}
        case "RSI_REVERSAL" -> {double r=rsi(c,z,14);s=r<30?BUY:r>70?SELL:NONE;}
        case "STOCHASTIC" -> {double k=(close-minLow(b,z,14))/max(maxHigh(b,z,14)-minLow(b,z,14),1e-10)*100;s=k<20?BUY:k>80?SELL:NONE;}
        case "CCI" -> {double q=cci(b,z,20);s=q< -100?BUY:q>100?SELL:NONE;}
        case "DONCHIAN_BREAKOUT" -> {s=close>maxHigh(b,z-1,20)?BUY:close<minLow(b,z-1,20)?SELL:NONE;}
        case "ATR_BREAKOUT" -> {s=close>prev+1.5*a?BUY:close<prev-1.5*a?SELL:NONE;}
        case "BOLLINGER_SQUEEZE" -> {double bw=std(c,z-1,20)/max(sma(c,z-1,20),1e-10);s=bw<.003?(close>maxHigh(b,z-1,20)?BUY:close<minLow(b,z-1,20)?SELL:NONE):NONE;}
        case "LONDON_BREAKOUT" -> {var utc=java.time.Instant.ofEpochSecond(b.get(z).time()).atZone(java.time.ZoneOffset.UTC);int hour=utc.getHour();double hi=-Double.MAX_VALUE,lo=Double.MAX_VALUE;int n=0;for(int i=max(0,z-30);i<z;i++){var q=b.get(i);var tm=java.time.Instant.ofEpochSecond(q.time()).atZone(java.time.ZoneOffset.UTC);if(tm.toLocalDate().equals(utc.toLocalDate())&&tm.getHour()>=7&&tm.getHour()<9){hi=max(hi,q.high());lo=min(lo,q.low());n++;}}s=n>=2&&hour>=9&&hour<=12?(close>hi?BUY:close<lo?SELL:NONE):NONE;note="Only meaningful for H1 bars with an applicable UTC session; daylight-saving must be reviewed";if(!"H1".equals(frame))return new Result(id,NA,true,false,"London session rule requires H1 bars",b.size());}
        case "BOLLINGER_MEAN_REVERSION" -> {double m=sma(c,z,20),sd=std(c,z,20);s=close<m-2*sd?BUY:close>m+2*sd?SELL:NONE;}
        case "RSI_DIVERGENCE" -> {double r=rsi(c,z,14),pr=rsi(c,z-8,14);s=close<minLow(b,z-2,5)&&r>pr+5?BUY:close>maxHigh(b,z-2,5)&&r<pr-5?SELL:NONE;note="Simplified oscillator-divergence screening; pivot confirmation is not production verified";}
        case "KELTNER_MEAN_REVERSION" -> {double m=ema(c,z,20);s=close<m-1.5*a?BUY:close>m+1.5*a?SELL:NONE;}
        case "PIN_BAR" -> {var q=b.get(z);double range=q.high()-q.low(),body=abs(q.close()-q.open()),up=q.high()-max(q.open(),q.close()),low=min(q.open(),q.close())-q.low();s=range>0&&body/range<.35?(low>range*.6?BUY:up>range*.6?SELL:NONE):NONE;}
        case "ENGULFING" -> {var q=b.get(z);var p=b.get(z-1);s=q.close()>q.open()&&p.close()<p.open()&&q.open()<=p.close()&&q.close()>=p.open()?BUY:q.close()<q.open()&&p.close()>p.open()&&q.open()>=p.close()&&q.close()<=p.open()?SELL:NONE;}
        case "PIVOT_POINT" -> {int n="D1".equals(frame)?1:"H1".equals(frame)?24:0;if(n==0)return new Result(id,NA,true,false,"Pivot demo supports H1 or D1 input only",b.size());double hi=maxHigh(b,z-1,n),lo=minLow(b,z-1,n),pivot=(hi+lo+c.get(z-1))/3;s=close>pivot&&prev<=pivot?BUY:close<pivot&&prev>=pivot?SELL:NONE;note="Simplified prior-period pivot; session/calendar alignment requires broker verification";}
        case "ICHIMOKU" -> {double tenkan=(maxHigh(b,z,9)+minLow(b,z,9))/2,kijun=(maxHigh(b,z,26)+minLow(b,z,26))/2,span=(maxHigh(b,z,52)+minLow(b,z,52))/2;s=close>max(tenkan,max(kijun,span))?BUY:close<min(tenkan,min(kijun,span))?SELL:NONE;note="Simplified Ichimoku filter; cloud displacement not used";}
        case "MULTI_TF_EMA_ADX" -> {
          List<MarketBars.Bar> higher=higherBars(b,frame);
          if(higher.size()<55)return new Result(id,NA,true,false,"Insufficient completed higher-timeframe bars for multi-TF alignment",b.size());
          List<Double> hc=higher.stream().map(MarketBars.Bar::close).toList();
          int h=hc.size()-1;double fast=ema(c,z,9),slow=ema(c,z,21),hf=ema(hc,h,9),hs=ema(hc,h,21);
          double trend=adxEstimate(higher,h,14);
          s=trend>=20&&fast>slow&&hf>hs?BUY:trend>=20&&fast<slow&&hf<hs?SELL:NONE;
          note="Completed higher-timeframe UTC aggregates and DX proxy; broker-session validation pending";
        }
      }
      return new Result(id,s,true,false,note,b.size());
    }catch(RuntimeException ex){return new Result(id,NA,true,false,"Indicator unable to evaluate: "+ex.getClass().getSimpleName(),b.size());}
  }
}
