package com.tradeyar.app.reports;

import com.tradeyar.app.paper.PaperTradingService;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/reports")
public class ReportsController {
  private final PaperTradingService paper;
  public ReportsController(PaperTradingService paper) { this.paper=paper; }
  @GetMapping("/overview") public Map<String,Object> overview() {
    return Map.of("paperOrders",paper.all().size(),"realizedPnLAvailable",false,
       "winRateAvailable",false,"source","MEMORY_ONLY","liveTrades",0,
       "disclaimer","Fill counts only; positions, costs and closing P/L are not modeled");
  }
}