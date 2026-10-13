package com.tradeyar.app.v05;

import com.tradeyar.app.market.MarketService;
import org.junit.jupiter.api.Test;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

class AnalysisV05Test {
 private final AnalysisV05 svc=new AnalysisV05(new MarketBars(new MarketService()),new StrategyEngineV05());
 @Test void syntheticFeedNeverApprovesAnEntry(){
   Map<String,Object> r=svc.snapshot("EURUSD","M15","INTRADAY");
   assertEquals(false,r.get("entryAllowed"));assertEquals(false,r.get("realExecutionEnabled"));
   assertEquals(false,r.get("requestedTimeframeApplied"));assertEquals("H1",r.get("effectiveTimeframe"));
   assertEquals(20,((List<?>)r.get("strategies")).size());assertEquals("DEMO_DATA_NOT_TRADEABLE",r.get("decision"));
 }
 @Test void rejectsUntrustedInput(){
   assertThrows(IllegalArgumentException.class,()->svc.snapshot("INVALID","H1","INTRADAY"));
   assertThrows(IllegalArgumentException.class,()->svc.snapshot("EURUSD","INVALID","INTRADAY"));
   assertThrows(IllegalArgumentException.class,()->svc.snapshot("EURUSD","H1","INVALID"));
 }
}
