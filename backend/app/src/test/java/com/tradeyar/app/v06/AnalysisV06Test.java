package com.tradeyar.app.v06;

import com.tradeyar.app.market.MarketService;
import com.tradeyar.app.v05.MarketBars;
import org.junit.jupiter.api.Test;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

class AnalysisV06Test {
 private final AnalysisV06 service=new AnalysisV06(new MarketBars(new MarketService()),new StrategyEngineV06());
 @Test void unverifiedSyntheticDataCannotAuthorizeTrading(){
   Map<String,Object> r=service.snapshot("EURUSD","M15","INTRADAY");
   assertEquals(false,r.get("entryAllowed"));assertEquals(false,r.get("realExecutionEnabled"));
   assertEquals("DEMO_DATA_NOT_TRADEABLE",r.get("decision"));
   assertEquals("DEMO_NOT_ARCHIVED_AS_MARKET_EVIDENCE",r.get("analysisArchiveStatus"));
   assertEquals(20,((List<?>)r.get("strategies")).size());
 }
 @Test void unsafeSymbolAndStyleAreRejected(){
   assertThrows(IllegalArgumentException.class,()->service.snapshot("HACK","H1","INTRADAY"));
   assertThrows(IllegalArgumentException.class,()->service.snapshot("EURUSD","H1","HACK"));
 }
}
