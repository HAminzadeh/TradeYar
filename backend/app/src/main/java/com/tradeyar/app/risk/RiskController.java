package com.tradeyar.app.risk;

import java.util.Map;
import org.springframework.web.bind.annotation.*;

/** Indicative forex lot sizing; not an order authorization or broker quote. */
@RestController
@RequestMapping("/api/risk")
public class RiskController {
  public record RiskRequest(double equity, double riskPercent, double stopLossPips, double pipValuePerLot) { }
  @PostMapping("/position-size") public Map<String,Object> size(@RequestBody RiskRequest request) {
    if (request==null || !Double.isFinite(request.equity()) || request.equity()<=0 ||
        !Double.isFinite(request.riskPercent()) || request.riskPercent()<=0 || request.riskPercent()>1 ||
        !Double.isFinite(request.stopLossPips()) || request.stopLossPips()<1 ||
        !Double.isFinite(request.pipValuePerLot()) || request.pipValuePerLot()<=0)
      throw new IllegalArgumentException("Invalid input; riskPercent must be <= 1%");
    double budget=request.equity()*request.riskPercent()/100.0;
    double raw=budget/(request.stopLossPips()*request.pipValuePerLot());
    double lots=Math.floor(Math.min(raw,10.0)*100.0)/100.0;
    return Map.of("lots",Math.max(lots,0),"riskBudget",budget,"riskPercent",request.riskPercent(),
      "note","Indicative only; broker symbol specs, conversion, margin and slippage are not verified",
      "authorizedToTrade",false);
  }
}