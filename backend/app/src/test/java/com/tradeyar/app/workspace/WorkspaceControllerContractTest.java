package com.tradeyar.app.workspace;

import com.tradeyar.app.market.MarketService;
import com.tradeyar.app.strategies.StrategyService;
import com.tradeyar.app.technical.TechnicalService;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import java.util.List;
import java.util.Map;

class WorkspaceControllerContractTest {
  private final MarketService market = new MarketService();
  private final StrategyService strategies = new StrategyService(market,new TechnicalService());
  private final WorkspaceController controller = new WorkspaceController(market,strategies);

  @Test void allTwentyStrategiesHaveHonestStatuses() {
    Map<String,Object> result=controller.snapshot("EURUSD","INTRADAY");
    assertEquals(20, ((List<?>)result.get("strategies")).size());
    assertEquals(3,result.get("implementedCount"));
    assertEquals("INSUFFICIENT_EVIDENCE",result.get("decision"));
    assertEquals(false,result.get("entryAllowed"));
    assertEquals(false,result.get("realExecutionEnabled"));
    assertEquals(false,result.get("actualLiveMarketFeed"));
    assertEquals(false,result.get("requestedTimeframeApplied"));
    Map<?,?> counts=(Map<?,?>)result.get("counts");
    assertEquals(17,counts.get("NOT_IMPLEMENTED"));
    assertEquals(100,((List<?>)result.get("candles")).size());
  }
  @Test void rejectsUnsupportedInputs() {
    assertThrows(IllegalArgumentException.class,()->controller.snapshot("INVALID","INTRADAY"));
    assertThrows(IllegalArgumentException.class,()->controller.snapshot("EURUSD","INVALID"));
  }
  @Test void cannotFakeTrainingProgress() {
    assertEquals(false,controller.trainingStatus().get("readyToStart"));
    assertEquals(0,controller.trainingStatus().get("trainedModels"));
    assertEquals(false,controller.trainingPreflight().get("started"));
  }
}
