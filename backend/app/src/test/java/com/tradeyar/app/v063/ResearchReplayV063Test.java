package com.tradeyar.app.v063;
import com.tradeyar.app.v05.MarketBars.Bar;
import com.tradeyar.app.v06.StrategyEngineV06;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class ResearchReplayV063Test {
 @Test void replayAllExistingRulesIsResearchOnly() {
  List<Bar> bars=new ArrayList<>();
  for(int i=0;i<720;i++){
   double c=1.1+.00003*i+.0003*Math.sin(i*.31);
   bars.add(new Bar(1700000000L+i*3600,c-.00004,c+.00025,c-.00025,c,i+50));
  }
  var r=ResearchReplayV063.replay(new StrategyEngineV06(),bars,"H1","TEST_SYNTHETIC_ONLY",.0001,1.5,.2,3);
  assertEquals(60,r.summaries().size());
  assertFalse(r.tradeAuthorized());
  assertFalse(r.independentlyValidated());
  assertEquals("RESEARCH_ONLY_UNVERIFIED",r.status());
 }
 @Test void rejectsBadInput() {
  assertThrows(IllegalArgumentException.class,()->ResearchReplayV063.replay(new StrategyEngineV06(),List.of(),"H1","TEST",.0001,1,.2,3));
 }
}
