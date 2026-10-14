package com.tradeyar.app.v06;

import com.tradeyar.app.v05.MarketBars.Bar;
import org.junit.jupiter.api.Test;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

class StrategyEngineV06Test {
 private final StrategyEngineV06 engine=new StrategyEngineV06();
 private List<Bar> candles(int n){List<Bar> rows=new ArrayList<>();for(int i=0;i<n;i++){
   double mid=1.1+.001*Math.sin(i*.25)+.00001*i;
   rows.add(new Bar(1767225600L+i*3600L,mid,mid+.00035,mid-.00035,mid,100+i));
 }return rows;}
 @Test void twentyRulesHaveIndependentResearchStatusFalse(){
   var result=engine.evaluateAll(candles(400),"H1");
   assertEquals(20,result.size());
   assertEquals(20,result.stream().map(StrategyEngineV06.Result::id).distinct().count());
   assertTrue(result.stream().allMatch(x->!x.independentlyValidated()));
   assertTrue(result.stream().allMatch(x->Set.of("BUY","SELL","NO_SIGNAL","NOT_EVALUATED").contains(x.signal())));
 }
 @Test void noRuleWorksWithInsufficientHistory(){
   for(String id:StrategyEngineV06.IDS)assertEquals("NOT_EVALUATED",engine.evaluate(id,candles(35),"H1").signal());
 }
 @Test void parameterSetsAreBoundedAndExplicit(){
   assertEquals(3,StrategyEngineV06.PRESETS.size());
   assertThrows(IllegalArgumentException.class,()->new StrategyEngineV06.Parameters("BAD",10,5,14,2.0));
   assertThrows(IllegalArgumentException.class,()->engine.evaluate("FAKE",candles(400),"H1"));
 }
 @Test void multiTimeframeRejectsInsufficientCompletedHigherBars(){
   var result=engine.evaluate("MULTI_TF_EMA_ADX",candles(150),"H1");
   assertEquals("NOT_EVALUATED",result.signal());
 }
}
