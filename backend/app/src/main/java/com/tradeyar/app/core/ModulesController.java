package com.tradeyar.app.core;

import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/modules")
public class ModulesController {
  private static final String[][] MODULES = {
    {"M01","Core","DEMO"},{"M02","Bilingual UI","DEMO"},
    {"M03","Preferences","DEMO"},{"M04","Market data","SYNTHETIC"},
    {"M05","Charts","DEMO"},{"M06","MT5 connector","READ_ONLY"},
    {"M07","Technical analysis","DEMO"},{"M08","Strategies","PARTIAL"},
    {"M09","Backtesting","SYNTHETIC"},{"M10","Signals","DEMO"},
    {"M11","Risk sizing","DEMO"},{"M12","Paper trading","IN_MEMORY"},
    {"M13","Trading journal","IN_MEMORY"},{"M14","News","SAMPLE"},
    {"M15","AI","UNTRAINED"},{"M16","Alerts","IN_MEMORY"},
    {"M17","Reports","DEMO"},{"M18","Education","DEMO"},
    {"M19","Infrastructure","SCAFFOLD"},{"M20","Live execution","LOCKED"}
  };
  @GetMapping
  public List<Map<String,String>> modules() {
    return java.util.Arrays.stream(MODULES)
      .map(row -> Map.of("id",row[0],"name",row[1],"status",row[2])).toList();
  }
}