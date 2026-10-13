package com.tradeyar.app.paper;

import com.tradeyar.app.market.MarketService;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.*;

@Service
public class PaperTradingService {
  public record PaperRequest(String symbol,String side,double lots) { }
  public record PaperOrder(String id,String symbol,String side,double lots,double fillPrice,
                           String createdAt,String status,String executionMode) { }
  private final ConcurrentHashMap<String,PaperOrder> orders=new ConcurrentHashMap<>();
  private final MarketService market;
  public PaperTradingService(MarketService market) { this.market=market; }
  public PaperOrder submit(PaperRequest request) {
    if (request==null || request.side()==null || !(request.side().equals("BUY") || request.side().equals("SELL")) ||
        !Double.isFinite(request.lots()) || request.lots()<0.01 || request.lots()>1.0)
      throw new IllegalArgumentException("side must be BUY/SELL and lots 0.01..1.0");
    String symbol=market.symbol(request.symbol());
    Map<String,Object> quote=market.quote(symbol);
    double fill=(double) quote.get(request.side().equals("BUY") ? "ask" : "bid");
    String id=UUID.randomUUID().toString();
    PaperOrder order=new PaperOrder(id,symbol,request.side(),request.lots(),fill,
      Instant.now().toString(),"SIMULATED_FILL","PAPER_ONLY");
    orders.put(id,order);
    return order;
  }
  public List<PaperOrder> all() {
    List<PaperOrder> result=new ArrayList<>(orders.values());
    result.sort(Comparator.comparing(PaperOrder::createdAt).reversed());
    return result;
  }
}

@RestController
@RequestMapping("/api/paper")
class PaperController {
  private final PaperTradingService paper;
  PaperController(PaperTradingService paper) { this.paper=paper; }
  @GetMapping("/orders") public Map<String,Object> list() {
    return Map.of("orders",paper.all(),"mode","PAPER_ONLY","persistence","MEMORY_ONLY");
  }
  @PostMapping("/orders") public PaperTradingService.PaperOrder order(
     @RequestBody PaperTradingService.PaperRequest request) { return paper.submit(request); }
}