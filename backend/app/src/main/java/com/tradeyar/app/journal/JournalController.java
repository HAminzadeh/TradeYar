package com.tradeyar.app.journal;

import com.tradeyar.app.paper.PaperTradingService;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/journal")
public class JournalController {
  private final PaperTradingService paper;
  public JournalController(PaperTradingService paper) { this.paper=paper; }
  @GetMapping public Map<String,Object> journal() {
    return Map.of("entries",paper.all(),"scope","PAPER_ONLY",
      "persistence","MEMORY_ONLY","realizedPnLAvailable",false);
  }
}