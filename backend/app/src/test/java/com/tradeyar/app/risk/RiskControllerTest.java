package com.tradeyar.app.risk;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

class RiskControllerTest {
  @Test void rejectsOversizedRisk() {
    var risk=new RiskController();
    assertThrows(IllegalArgumentException.class, () -> risk.size(new RiskController.RiskRequest(1000,3,20,10)));
  }
  @Test void calculatesBudget() {
    var risk=new RiskController();
    assertEquals(10.0,(double)risk.size(new RiskController.RiskRequest(1000,1,20,10)).get("riskBudget"));
  }
}