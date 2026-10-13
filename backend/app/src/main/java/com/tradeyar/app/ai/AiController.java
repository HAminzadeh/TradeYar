package com.tradeyar.app.ai;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/ai")
public class AiController {
  private final HttpClient client=HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(2)).build();
  @GetMapping("/status") public Map<String,Object> status() {
    String base=System.getenv().getOrDefault("TRADEYAR_AI_URL","http://127.0.0.1:8001");
    // Only loopback URLs are permitted for the development bridge.
    if (!(base.startsWith("http://127.0.0.1:") || base.startsWith("http://localhost:")))
      return Map.of("status","DISABLED","modelLoaded",false,"reason","Only loopback AI URLs are permitted");
    try {
      URI uri=URI.create(base+"/health");
      HttpRequest req=HttpRequest.newBuilder(uri).timeout(Duration.ofSeconds(2)).GET().build();
      HttpResponse<String> resp=client.send(req,HttpResponse.BodyHandlers.ofString());
      return Map.of("status",resp.statusCode()==200 ? "CONNECTED" : "UNAVAILABLE",
        "modelLoaded",false,"readyForTrading",false,"httpStatus",resp.statusCode());
    } catch (InterruptedException ex) {
      Thread.currentThread().interrupt();
      return Map.of("status","UNAVAILABLE","modelLoaded",false,"readyForTrading",false);
    } catch (Exception ex) {
      return Map.of("status","UNAVAILABLE","modelLoaded",false,"readyForTrading",false);
    }
  }
}