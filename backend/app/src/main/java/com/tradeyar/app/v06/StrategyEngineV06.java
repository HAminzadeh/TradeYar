package com.tradeyar.app.v06;

import com.tradeyar.app.v05.MarketBars.Bar;
import java.time.*;
import java.util.*;
import org.springframework.stereotype.Service;

/**
 * Deterministic, closed-bar, research-only rule engine. This is NOT a validated trading system.
 * No broker connection, order API, or position-opening code is present here.
 */
@Service
public final class StrategyEngineV06 {
  public static final List<String> IDS=List.of(
    "SMA_CROSS","EMA_CROSS","TRIPLE_EMA","SUPERTREND","MACD","RSI_REVERSAL",
    "STOCHASTIC","CCI","DONCHIAN_BREAKOUT","ATR_BREAKOUT","BOLLINGER_SQUEEZE",
    "LONDON_BREAKOUT","BOLLINGER_MEAN_REVERSION","RSI_DIVERGENCE",
    "KELTNER_MEAN_REVERSION","PIN_BAR","ENGULFING","PIVOT_POINT",
    "ICHIMOKU","MULTI_TF_EMA_ADX");
  public record Parameters(String name,int fast,int slow,int lookback,double multiplier) {
    public Parameters {
      if(name==null||name.isBlank()||fast<3||slow<=fast||slow>150||lookback<5||lookback>100||!Double.isFinite(multiplier)||multiplier<=0||multiplier>5)
        throw new IllegalArgumentException("Invalid research parameter set");
    }
  }
  public static final Parameters DEFAULT=new Parameters("BASE",10,30,14,2.0);
  public static final Parameters FAST=new Parameters("FAST",7,21,10,1.7);
  public static final Parameters SLOW=new Parameters("SLOW",15,50,21,2.3);
  public static final List<Parameters> PRESETS=List.of(DEFAULT,FAST,SLOW);
  public record Result(String id,String signal,boolean implemented,boolean independentlyValidated,
                       String reason,int barsUsed,String parameterSet,String timeframe) {}
  private static final String NONE="NO_SIGNAL", BUY="BUY", SELL="SELL", NA="NOT_EVALUATED";
  private static final double EPS=1.e-10;
  private static String cross(double before,double now){return before<=0&&now>0?BUY:before>=0&&now<0?SELL:NONE;}
  private static double[] closes(List<Bar>b){return b.stream().mapToDouble(Bar::close).toArray();}
  private static double[] ema(double[] x,int n){double[] out=new double[x.length];Arrays.fill(out,Double.NaN);if(x.length<n)return out;double s=0;for(int i=0;i<n;i++)s+=x[i];out[n-1]=s/n;double a=2.0/(n+1);for(int i=n;i<x.length;i++)out[i]=a*x[i]+(1-a)*out[i-1];return out;}
  private static double sma(double[] x,int end,int n){if(end-n+1<0)return Double.NaN;double s=0;for(int i=end-n+1;i<=end;i++)s+=x[i];return s/n;}
  private static double maxH(List<Bar>b,int end,int n){if(end-n+1<0)return Double.NaN;double x=-Double.MAX_VALUE;for(int i=end-n+1;i<=end;i++)x=Math.max(x,b.get(i).high());return x;}
  private static double minL(List<Bar>b,int end,int n){if(end-n+1<0)return Double.NaN;double x=Double.MAX_VALUE;for(int i=end-n+1;i<=end;i++)x=Math.min(x,b.get(i).low());return x;}
  private static double[] atr(List<Bar>b,int n){double[] tr=new double[b.size()],out=new double[b.size()];Arrays.fill(out,Double.NaN);for(int i=1;i<b.size();i++){var v=b.get(i);double prev=b.get(i-1).close();tr[i]=Math.max(v.high()-v.low(),Math.max(Math.abs(v.high()-prev),Math.abs(v.low()-prev)));}if(b.size()<=n)return out;double a=0;for(int i=1;i<=n;i++)a+=tr[i];out[n]=a/n;for(int i=n+1;i<b.size();i++)out[i]=(out[i-1]*(n-1)+tr[i])/n;return out;}
  private static double[] rsi(double[] x,int n){double[] out=new double[x.length];Arrays.fill(out,Double.NaN);if(x.length<=n)return out;double up=0,dn=0;for(int i=1;i<=n;i++){double d=x[i]-x[i-1];up+=Math.max(d,0);dn+=Math.max(-d,0);}up/=n;dn/=n;out[n]=rsiValue(up,dn);for(int i=n+1;i<x.length;i++){double d=x[i]-x[i-1];up=(up*(n-1)+Math.max(d,0))/n;dn=(dn*(n-1)+Math.max(-d,0))/n;out[i]=rsiValue(up,dn);}return out;}
  private static double rsiValue(double up,double down){return down<EPS?(up<EPS?50:100):100-100/(1+up/down);}
  private static double stdev(double[]x,int end,int n){double mean=sma(x,end,n),v=0;for(int i=end-n+1;i<=end;i++)v+=(x[i]-mean)*(x[i]-mean);return Math.sqrt(v/n);}
  private static double cci(List<Bar>b,int end,int n){double[] tp=new double[n];double mean=0;for(int i=0;i<n;i++){var q=b.get(end-n+1+i);tp[i]=(q.high()+q.low()+q.close())/3;mean+=tp[i];}mean/=n;double dev=0;for(double v:tp)dev+=Math.abs(v-mean);dev/=n;return dev<EPS?0:(tp[n-1]-mean)/(.015*dev);}
  private static List<Bar> completedHigher(List<Bar>b,String frame){
    long sec=switch(frame){case "M1"->300L;case "M5"->900L;case "M15","M30"->3600L;case "H1"->14400L;case "H4"->86400L;case "D1"->604800L;default->0L;};
    long input=switch(frame){case "M1"->60L;case "M5"->300L;case "M15"->900L;case "M30"->1800L;case "H1"->3600L;case "H4"->14400L;case "D1"->86400L;default->0L;};
    if(sec==0||input==0)return List.of();List<Bar>out=new ArrayList<>();long bucket=-1,prevTime=-1;int count=0;Bar first=null,last=null;double hi=0,lo=0;long vol=0;
    for(Bar q:b){long id=Math.floorDiv(q.time(),sec);if(id!=bucket){if(bucket!=-1&&count==sec/input&&first.time()==bucket*sec)out.add(new Bar(first.time(),first.open(),hi,lo,last.close(),vol));bucket=id;first=q;hi=q.high();lo=q.low();vol=0;count=0;}
      if(prevTime!=-1&&q.time()-prevTime!=input){count=-1000;}count++;last=q;hi=Math.max(hi,q.high());lo=Math.min(lo,q.low());vol+=q.volume();prevTime=q.time();}
    if(first!=null&&count==sec/input&&first.time()==bucket*sec)out.add(new Bar(first.time(),first.open(),hi,lo,last.close(),vol));return out;
  }
  private static double adxLast(List<Bar>b,int n){if(b.size()<n*3+2)return Double.NaN;double smoothTR=0,sp=0,sm=0,adx=0;int dxn=0;
    for(int i=1;i<b.size();i++){Bar cur=b.get(i),prev=b.get(i-1);double up=cur.high()-prev.high(),down=prev.low()-cur.low();double plus=up>down&&up>0?up:0,minus=down>up&&down>0?down:0;double tr=Math.max(cur.high()-cur.low(),Math.max(Math.abs(cur.high()-prev.close()),Math.abs(cur.low()-prev.close())));
      if(i<=n){smoothTR+=tr;sp+=plus;sm+=minus;if(i<n)continue;}
      else {smoothTR=smoothTR-smoothTR/n+tr;sp=sp-sp/n+plus;sm=sm-sm/n+minus;}
      double dip=100*sp/Math.max(smoothTR,EPS),dim=100*sm/Math.max(smoothTR,EPS),dx=100*Math.abs(dip-dim)/Math.max(dip+dim,EPS);
      if(dxn<n){adx+=dx/n;dxn++;}else adx=(adx*(n-1)+dx)/n;
    }return dxn>=n?adx:Double.NaN;
  }
  private static int[] pivots(double[]x,int end,int lookback,boolean lows){List<Integer> found=new ArrayList<>();int start=Math.max(2,end-lookback);for(int i=start;i<=end-2;i++){boolean pivot=true;for(int j=i-2;j<=i+2;j++){if(j==i)continue;if(lows?x[i]>=x[j]:x[i]<=x[j]){pivot=false;break;}}if(pivot)found.add(i);}if(found.size()<2)return null;return new int[]{found.get(found.size()-2),found.get(found.size()-1)};}
  private static double[] highs(List<Bar>b){return b.stream().mapToDouble(Bar::high).toArray();}
  private static double[] lows(List<Bar>b){return b.stream().mapToDouble(Bar::low).toArray();}
  private static String result(boolean buy,boolean sell){return buy?BUY:sell?SELL:NONE;}
  public List<Result> evaluateAll(List<Bar>b,String frame){return evaluateAll(b,frame,DEFAULT);}
  public List<Result> evaluateAll(List<Bar>b,String frame,Parameters p){List<Result>r=new ArrayList<>();for(String id:IDS)r.add(evaluate(id,b,frame,p));return List.copyOf(r);}
  public Result evaluate(String id,List<Bar>b,String frame){return evaluate(id,b,frame,DEFAULT);}
  public Result evaluate(String id,List<Bar>b,String frame,Parameters p){
    if(!IDS.contains(id))throw new IllegalArgumentException("Unknown strategy");if(p==null)throw new IllegalArgumentException("Parameters required");
    int count=b==null?0:b.size();if(count<Math.max(120,p.slow()+60))return new Result(id,NA,true,false,"INSUFFICIENT_CLOSED_BARS",count,p.name(),frame);
    if(!Set.of("M1","M5","M15","M30","H1","H4","D1","W1","MN1").contains(frame))throw new IllegalArgumentException("Unsupported timeframe");
    try{
      int z=count-1;double[]c=closes(b);double[]av=atr(b,p.lookback());double[]rs=rsi(c,p.lookback());double close=c[z],prev=c[z-1],vol=av[z];String signal=NONE,note="Closed-bar research signal, not investment authorization";
      switch(id){
        case "SMA_CROSS"->{signal=cross(sma(c,z-1,p.fast())-sma(c,z-1,p.slow()),sma(c,z,p.fast())-sma(c,z,p.slow()));}
        case "EMA_CROSS"->{double[]f=ema(c,p.fast()),s=ema(c,p.slow());signal=cross(f[z-1]-s[z-1],f[z]-s[z]);}
        case "TRIPLE_EMA"->{double[]f=ema(c,p.fast()),m=ema(c,p.slow()),s=ema(c,Math.min(150,p.slow()*2));signal=result(f[z]>m[z]&&m[z]>s[z],f[z]<m[z]&&m[z]<s[z]);}
        case "SUPERTREND"->{
          double upper=Double.NaN,lower=Double.NaN;int direction=1,prior=1;for(int i=p.lookback()+1;i<=z;i++){
            double mid=(b.get(i).high()+b.get(i).low())/2,rawU=mid+p.multiplier()*av[i],rawL=mid-p.multiplier()*av[i];
            if(Double.isNaN(upper)){upper=rawU;lower=rawL;continue;}
            double u=(rawU<upper||c[i-1]>upper)?rawU:upper,l=(rawL>lower||c[i-1]<lower)?rawL:lower;
            prior=direction;direction=c[i]>upper?1:c[i]<lower?-1:direction;upper=u;lower=l;
          }signal=result(prior<0&&direction>0,prior>0&&direction<0);
          note="Recursive ATR Supertrend trend-flip approximation; validate reference implementation and execution timing";
        }
        case "MACD"->{double[]fast=ema(c,Math.max(5,p.fast()+2)),slow=ema(c,Math.max(15,p.slow()-4));double[]line=new double[count];Arrays.fill(line,Double.NaN);int first=-1;for(int i=0;i<count;i++){if(Double.isFinite(fast[i])&&Double.isFinite(slow[i])){line[i]=fast[i]-slow[i];if(first<0)first=i;}}double[]compact=Arrays.copyOfRange(line,first,count);double[]sig=ema(compact,9);int k=sig.length-1;signal=cross(compact[k-1]-sig[k-1],compact[k]-sig[k]);}
        case "RSI_REVERSAL"->{signal=result(rs[z-1]<=30&&rs[z]>30,rs[z-1]>=70&&rs[z]<70);}
        case "STOCHASTIC"->{double k=100*(close-minL(b,z,p.lookback()))/Math.max(maxH(b,z,p.lookback())-minL(b,z,p.lookback()),EPS);double prevK=100*(prev-minL(b,z-1,p.lookback()))/Math.max(maxH(b,z-1,p.lookback())-minL(b,z-1,p.lookback()),EPS);signal=result(prevK<=20&&k>20,prevK>=80&&k<80);note="Fast stochastic threshold re-entry; %D confirmation intentionally not modeled";}
        case "CCI"->{double q=cci(b,z,p.slow()),q0=cci(b,z-1,p.slow());signal=result(q0<=-100&&q>-100,q0>=100&&q<100);}
        case "DONCHIAN_BREAKOUT"->{signal=result(close>maxH(b,z-1,p.slow()),close<minL(b,z-1,p.slow()));}
        case "ATR_BREAKOUT"->{signal=result(close>prev+p.multiplier()*vol,close<prev-p.multiplier()*vol);}
        case "BOLLINGER_SQUEEZE"->{double width=4*stdev(c,z-1,p.slow())/Math.max(sma(c,z-1,p.slow()),EPS);int n=0;for(int i=z-80;i<z;i++)if(i>=p.slow()&&4*stdev(c,i,p.slow())/Math.max(sma(c,i,p.slow()),EPS)>=width)n++;signal=width>0&&n>=64?result(close>maxH(b,z-1,p.slow()),close<minL(b,z-1,p.slow())):NONE;note="Rolling relative squeeze filter and Donchian breakout";}
        case "LONDON_BREAKOUT"->{if(!Set.of("M5","M15","M30","H1").contains(frame))return na(id,count,p,frame,"LONDON_SESSION_INCOMPATIBLE_TIMEFRAME");
          ZonedDateTime london=Instant.ofEpochSecond(b.get(z).time()).atZone(ZoneId.of("Europe/London"));var day=london.toLocalDate();double hi=-Double.MAX_VALUE,lo=Double.MAX_VALUE;int rows=0;
          for(int i=z-1;i>=0;i--){var t=Instant.ofEpochSecond(b.get(i).time()).atZone(ZoneId.of("Europe/London"));if(t.toLocalDate().isBefore(day))break;if(t.getHour()>=7&&t.getHour()<9){hi=Math.max(hi,b.get(i).high());lo=Math.min(lo,b.get(i).low());rows++;}}
          signal=rows>=2&&london.getHour()>=9&&london.getHour()<=12?result(close>hi,close<lo):NONE;note="Europe/London DST-aware session, 07:00–09:00 local reference range";
        }
        case "BOLLINGER_MEAN_REVERSION"->{double mid=sma(c,z,p.slow()),std=stdev(c,z,p.slow()),pMid=sma(c,z-1,p.slow()),pStd=stdev(c,z-1,p.slow());signal=result(prev<pMid-p.multiplier()*pStd&&close>=mid-p.multiplier()*std,prev>pMid+p.multiplier()*pStd&&close<=mid+p.multiplier()*std);}
        case "RSI_DIVERGENCE"->{int[]low=pivots(lows(b),z,70,true),high=pivots(highs(b),z,70,false);boolean bullish=low!=null&&b.get(low[1]).low()<b.get(low[0]).low()&&rs[low[1]]>rs[low[0]]+3;boolean bearish=high!=null&&b.get(high[1]).high()>b.get(high[0]).high()&&rs[high[1]]<rs[high[0]]-3;signal=result(bullish,bearish);note="Two confirmed 5-bar pivots; output uses only right-confirmed pivots";}
        case "KELTNER_MEAN_REVERSION"->{double[]m=ema(c,p.slow());signal=result(prev<m[z-1]-p.multiplier()*av[z-1]&&close>=m[z]-p.multiplier()*vol,prev>m[z-1]+p.multiplier()*av[z-1]&&close<=m[z]+p.multiplier()*vol);}
        case "PIN_BAR"->{Bar q=b.get(z);double range=q.high()-q.low(),body=Math.abs(q.close()-q.open()),upper=q.high()-Math.max(q.open(),q.close()),lower=Math.min(q.open(),q.close())-q.low();signal=range>EPS&&body/range<=.33?result(lower/range>=.6,upper/range>=.6):NONE;}
        case "ENGULFING"->{Bar q=b.get(z),old=b.get(z-1);signal=result(q.close()>q.open()&&old.close()<old.open()&&q.open()<=old.close()&&q.close()>=old.open(),q.close()<q.open()&&old.close()>old.open()&&q.open()>=old.close()&&q.close()<=old.open());}
        case "PIVOT_POINT"->{if(!Set.of("M15","M30","H1","H4","D1").contains(frame))return na(id,count,p,frame,"PIVOT_INCOMPATIBLE_TIMEFRAME");
          ZoneId utc=ZoneOffset.UTC;LocalDate current=Instant.ofEpochSecond(b.get(z).time()).atZone(utc).toLocalDate();LocalDate lastDay=null;double hi=-Double.MAX_VALUE,lo=Double.MAX_VALUE,prevClose=0;int rows=0;
          for(int i=z-1;i>=0;i--){LocalDate d=Instant.ofEpochSecond(b.get(i).time()).atZone(utc).toLocalDate();if(d.equals(current))continue;if(lastDay==null)lastDay=d;if(!d.equals(lastDay))break;hi=Math.max(hi,b.get(i).high());lo=Math.min(lo,b.get(i).low());if(rows==0)prevClose=b.get(i).close();rows++;}
          if(rows==0)return na(id,count,p,frame,"MISSING_PREVIOUS_SESSION");double pivot=(hi+lo+prevClose)/3;signal=cross(c[z-1]-pivot,c[z]-pivot);note="Previous completed UTC trading day pivot; broker session boundaries can differ";
        }
        case "ICHIMOKU"->{double ten=(maxH(b,z,9)+minL(b,z,9))/2,kij=(maxH(b,z,26)+minL(b,z,26))/2;
          // Cloud plotted at current bar was computed 26 bars ago. Never reference future data.
          int lag=z-26;double tenLag=(maxH(b,lag,9)+minL(b,lag,9))/2,kijLag=(maxH(b,lag,26)+minL(b,lag,26))/2;
          double spanA=(tenLag+kijLag)/2,spanB=(maxH(b,lag,52)+minL(b,lag,52))/2;
          signal=result(close>Math.max(spanA,spanB)&&ten>kij,close<Math.min(spanA,spanB)&&ten<kij);note="Displaced Ichimoku cloud, no future leakage; Chikou filter excluded";
        }
        case "MULTI_TF_EMA_ADX"->{List<Bar>h=completedHigher(b,frame);if(h.size()<Math.max(70,p.slow()+25))return na(id,count,p,frame,"INSUFFICIENT_COMPLETE_HIGHER_BARS");
          double[]hc=closes(h),f=ema(c,p.fast()),s=ema(c,p.slow()),hf=ema(hc,p.fast()),hs=ema(hc,p.slow());int k=h.size()-1;double adx=adxLast(h,p.lookback());signal=Double.isFinite(adx)&&adx>=20?result(f[z]>s[z]&&hf[k]>hs[k],f[z]<s[z]&&hf[k]<hs[k]):NONE;note="Completed higher-timeframe bars with Wilder ADX strength gate";
        }
      }
      return new Result(id,signal,true,false,note,count,p.name(),frame);
    }catch(RuntimeException e){return na(id,count,p,frame,"INDICATOR_ERROR_"+e.getClass().getSimpleName());}
  }
  private static Result na(String id,int count,Parameters p,String frame,String why){return new Result(id,NA,true,false,why,count,p.name(),frame);}
}
