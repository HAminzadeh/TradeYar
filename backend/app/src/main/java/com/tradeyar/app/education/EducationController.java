package com.tradeyar.app.education;

import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/education")
public class EducationController {
  @GetMapping("/lessons") public Map<String,Object> lessons(@RequestParam(name="lang", defaultValue="fa") String lang) {
    if (!("fa".equals(lang) || "en".equals(lang))) throw new IllegalArgumentException("lang must be fa or en");
    boolean fa=lang.equals("fa");
    return Map.of("lang",lang,"lessons",List.of(
      Map.of("id","intro","title",fa ? "Ù…Ø¨Ø§Ù†ÛŒ Ø¨Ø§Ø²Ø§Ø± ÙØ§Ø±Ú©Ø³" : "Forex fundamentals"),
      Map.of("id","risk","title",fa ? "Ù…Ø¯ÛŒØ±ÛŒØª Ø±ÛŒØ³Ú© Ùˆ Ø³Ø±Ù…Ø§ÛŒÙ‡" : "Risk and capital management"),
      Map.of("id","backtest","title",fa ? "Ø®Ø·Ø§Ù‡Ø§ÛŒ Ø±Ø§ÛŒØ¬ Ø¯Ø± Ø¨Ú©â€ŒØªØ³Øª" : "Common backtesting mistakes")));
  }
}