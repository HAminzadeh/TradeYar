package com.tradeyar.app.alerts;

import com.tradeyar.app.market.MarketService;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.web.bind.annotation.*;

/** Development alerts are evaluated on demand; no notifications are sent. */
@RestController
@RequestMapping("/api/alerts")
public class AlertsController {
  public record Alert(String id,String symbol,String when,double threshold) { }
  public record AlertRequest(String symbol,String when,double threshold) { }
  private final ConcurrentHashMap<String,Alert> alerts=new ConcurrentHashMap<>();
  private final MarketService market;
  public AlertsController(MarketService market) { this.market=market; }
  @GetMapping public Map<String,Object> list() {
    return Map.of("alerts",alerts.values(),"persistence","MEMORY_ONLY","deliveryEnabled",false);
  }
  @PostMapping public Alert create(@RequestBody AlertRequest request) {
    if (request==null || !("ABOVE".equals(request.when()) || "BELOW".equals(request.when())) ||
      !Double.isFinite(request.threshold()) || request.threshold()<=0)
      throw new IllegalArgumentException("Invalid threshold/condition");
    Alert alert=new Alert(UUID.randomUUID().toString(),market.symbol(request.symbol()),
      request.when(),request.threshold());
    alerts.put(alert.id(),alert);
    return alert;
  }
  @GetMapping("/check") public Map<String,Object> check() {
    var results=alerts.values().stream().map(alert -> {
      double bid=(double)market.quote(alert.symbol()).get("bid");
      boolean triggered=alert.when().equals("ABOVE") ? bid>alert.threshold() : bid<alert.threshold();
      return Map.of("id",alert.id(),"triggered",triggered,"price",bid,"source","SYNTHETIC_DEMO");
    }).toList();
    return Map.of("results",results,"deliveryEnabled",false);
  }
}