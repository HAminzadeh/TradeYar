package com.tradeyar.app.v063;

import com.tradeyar.app.v05.MarketBars.Bar;
import com.tradeyar.app.v06.StrategyEngineV06;
import java.util.*;

/** Closed-bar research replay of the *existing* TradeYar v0.6 strategy rules.
 * No order API, no claims of live broker fills, no trained ML and no trade authorization.
 * Signal on bar i is executed at next bar OPEN; position exits on later bar OPEN.
 */
public final class ResearchReplayV063 {
  private ResearchReplayV063() {}
  public record Trade(String strategy, long signalTime, long entryTime, long exitTime,
                      String side, double entry, double exit, double netPips) {}
  public record Summary(String strategy, String segment, int signalsEvaluated, int trades,
                        double netPips, Double meanPips, Double winRate,
                        double maxClosedTradeDrawdownPips, List<Trade> sampleTrades) {}
  public record ReplayReport(int inputBars, int trainEndIndex, int validationEndIndex,
                             int testStartIndex, String dataSource,
                             String status, boolean independentlyValidated,
                             boolean tradeAuthorized, String disclaimer,
                             List<Summary> summaries) {}

  public static ReplayReport replay(StrategyEngineV06 engine, List<Bar> bars,
                                    String frame, String source,
                                    double pipSize, double spreadPips,
                                    double perSideSlippagePips, int holdBars) {
    if (engine == null || bars == null || bars.size()<600 || bars.size()>6000)
      throw new IllegalArgumentException("Require 600..6000 historical closed bars");
    if (!(pipSize>0) || !(spreadPips>=0) || !(perSideSlippagePips>=0) ||
        !Double.isFinite(pipSize) || !Double.isFinite(spreadPips) ||
        !Double.isFinite(perSideSlippagePips) || spreadPips>1000 ||
        perSideSlippagePips>1000 || holdBars<1 || holdBars>20)
      throw new IllegalArgumentException("Invalid cost/fill assumptions");
    long last=-1;
    for (Bar b:bars) {
      if(b.time()<=last || !Double.isFinite(b.open()) || b.open()<=0 ||
          !Double.isFinite(b.high()) || !Double.isFinite(b.low()) ||
          !Double.isFinite(b.close()) || b.low()>Math.min(b.open(),b.close()) ||
          b.high()<Math.max(b.open(),b.close()) || b.low()>b.high() || b.volume()<0)
        throw new IllegalArgumentException("Invalid, non-monotonic or incomplete OHLC series");
      last=b.time();
    }
    int trainEnd=(int)(bars.size()*.60), valEnd=(int)(bars.size()*.80);
    List<Summary> summaries=new ArrayList<>();
    for(String id:StrategyEngineV06.IDS) {
      summaries.add(score(engine,bars,frame,id,"TRAIN",120,trainEnd,holdBars,pipSize,spreadPips,perSideSlippagePips));
      summaries.add(score(engine,bars,frame,id,"VALIDATION",trainEnd,valEnd,holdBars,pipSize,spreadPips,perSideSlippagePips));
      summaries.add(score(engine,bars,frame,id,"HELD_OUT",valEnd,bars.size(),holdBars,pipSize,spreadPips,perSideSlippagePips));
    }
    return new ReplayReport(bars.size(),trainEnd,valEnd,valEnd,source,
        "RESEARCH_ONLY_UNVERIFIED",false,false,
        "Close-to-next-open modeled fills; constant estimated spread/slippage, fixed hold horizon; " +
        "no tick fills, variable costs, swap, position sizing, parameter optimization or independent validation. " +
        "Held-out metrics must not be used repeatedly for strategy selection.",List.copyOf(summaries));
  }

  static Summary score(StrategyEngineV06 engine,List<Bar> bars,String frame,String id,
                       String segment,int begin,int end,int hold,double pipSize,
                       double spreadPips,double slipPips) {
    int signals=0;List<Trade> results=new ArrayList<>();double net=0,peak=0,dd=0;
    // Keep enough earlier closed bars for indicators at the start of each segment.
    for(int i=Math.max(120,begin);i+1+hold<end;i++) {
      int prefixStart=Math.max(0,i-1000);
      if(i-prefixStart+1<120)continue;
      StrategyEngineV06.Result r=engine.evaluate(id,bars.subList(prefixStart,i+1),frame);
      signals++;
      if(!"BUY".equals(r.signal()) && !"SELL".equals(r.signal()))continue;
      int entryIndex=i+1,exitIndex=i+1+hold;
      Bar en=bars.get(entryIndex),ex=bars.get(exitIndex);
      // Full spread once per round trip, slippage independently charged on both fills.
      double gross=(ex.open()-en.open())/pipSize*("BUY".equals(r.signal())?1:-1);
      double pnl=gross-spreadPips-2*slipPips;
      Trade tr=new Trade(id,bars.get(i).time(),en.time(),ex.time(),r.signal(),en.open(),ex.open(),pnl);
      results.add(tr);net+=pnl;peak=Math.max(peak,net);dd=Math.max(dd,peak-net);
      i=exitIndex-1; // at most one open position per strategy; no overlapping fills
    }
    long wins=results.stream().filter(t->t.netPips()>0).count();
    return new Summary(id,segment,signals,results.size(),net,
        results.isEmpty()?null:net/results.size(),results.isEmpty()?null:(double)wins/results.size(),
        dd,List.copyOf(results.subList(0,Math.min(5,results.size()))));
  }
}
