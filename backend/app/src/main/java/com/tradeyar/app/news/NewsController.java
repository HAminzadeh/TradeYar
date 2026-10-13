package com.tradeyar.app.news;

import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

/** Explicit sample events, not current market/economic news. */
@RestController
@RequestMapping("/api/news")
public class NewsController {
  @GetMapping("/events") public Map<String,Object> events() {
    return Map.of("connected",false,"source","STATIC_EXAMPLES","live",false,
      "events",List.of(Map.of("title","Sample central bank decision","currency","USD","impact","HIGH"),
                       Map.of("title","Sample inflation release","currency","EUR","impact","MEDIUM")));
  }
}