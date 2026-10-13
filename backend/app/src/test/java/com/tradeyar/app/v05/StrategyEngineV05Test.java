package com.tradeyar.app.v05;

import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class StrategyEngineV05Test {
 private final StrategyEngineV05 engine=new StrategyEngineV05();
 private List<MarketBars.Bar> bars(){List<MarketBars.Bar> b=new ArrayList<>();for(int i=0;i<180;i++){double price=1.1+0.001*Math.sin(i*.15)+i*.00001;b.add(new MarketBars.Bar(1767225600L+i*3600,price,price+.0003,price-.0003,price,100));}return b;}
 @Test void evaluatesTwentyRuleDefinitionsWithoutGrantingTrading(){
   var results=engine.evaluateAll(bars(),"H1");assertEquals(20,results.size());
   assertEquals(20,results.stream().map(StrategyEngineV05.Result::id).distinct().count());
   assertTrue(results.stream().allMatch(StrategyEngineV05.Result::implemented));
   assertTrue(results.stream().noneMatch(StrategyEngineV05.Result::independentlyValidated));
   assertTrue(results.stream().allMatch(r->Set.of("BUY","SELL","NO_SIGNAL","NOT_EVALUATED").contains(r.signal())));
 }
 @Test void missingHigherTimeframeCannotProduceIndependentSignal(){
   var r=engine.evaluate("MULTI_TF_EMA_ADX",bars(),"H1");assertEquals("NOT_EVALUATED",r.signal());
 }
 @Test void smallHistoryCannotBeSilentlyEvaluated(){
   for(String id:StrategyEngineV05.IDS)assertEquals("NOT_EVALUATED",engine.evaluate(id,bars().subList(0,40),"H1").signal());
 }
 @Test void unknownStrategyIsRejected(){assertThrows(IllegalArgumentException.class,()->engine.evaluate("MAGIC",bars(),"H1"));}
}
