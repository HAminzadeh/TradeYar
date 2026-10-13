package com.tradeyar.app.research;

import com.tradeyar.app.market.MarketService;
import com.tradeyar.app.strategies.StrategyService;
import com.tradeyar.app.technical.TechnicalService;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class ResearchReadinessContractTest {
  private final MarketService market = new MarketService();
  private final StrategyService strategy = new StrategyService(market, new TechnicalService());
  private final ResearchReadinessController controller = new ResearchReadinessController(strategy);

  @Test void strictConsensusIsNeverFaked() {
    var result = controller.consensus("EURUSD", "INTRADAY");
    assertEquals(20, result.get("strategyCount"));
    assertEquals(3L, result.get("evaluatedCount"));
    assertEquals(16, result.get("minimumAligned"));
    assertEquals("INSUFFICIENT_EVIDENCE", result.get("outcome"));
    assertEquals(false, result.get("eligibleForRealTrading"));
  }

  @Test void zeroCoverageIsReportedAsZero() {
    var result = controller.knowledge("EURUSD", "SWING");
    assertEquals("WAITING_FOR_DATA", result.get("status"));
    assertEquals(0, result.get("verifiedCoverageYears"));
    assertEquals(false, result.get("validatedModel"));
    assertEquals(false, result.get("decisionAuthorization"));
  }

  @Test void expectedProfilesAreAvailable() {
    var result = controller.profiles();
    assertEquals(false, result.get("executionEnabled"));
    assertEquals(6, ((java.util.List<?>)result.get("profiles")).size());
  }

  @Test void rejectUnsupportedStyleOrSymbol() {
    assertThrows(IllegalArgumentException.class, ()->controller.consensus("EURUSD", "INVALID"));
    assertThrows(IllegalArgumentException.class, ()->controller.knowledge("BTCUSD", "INTRADAY"));
  }
}
