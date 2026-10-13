package com.tradeyar.app;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class ApiContractRegressionTest {
  @Autowired MockMvc mvc;

  @Test void marketCandlesWithQueryParametersReturn100Bars() throws Exception {
    mvc.perform(get("/api/market/candles").param("symbol","EURUSD").param("limit","100"))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.source").value("SYNTHETIC_DEMO"))
      .andExpect(jsonPath("$.candles.length()").value(100));
  }

  @Test void invalidSymbolReturns400() throws Exception {
    mvc.perform(get("/api/market/candles").param("symbol","INVALID").param("limit","100"))
      .andExpect(status().isBadRequest());
  }

  @Test void quoteAndTechnicalSummaryUseExplicitQueryNames() throws Exception {
    mvc.perform(get("/api/market/quote").param("symbol","EURUSD"))
      .andExpect(status().isOk());
    mvc.perform(get("/api/technical/summary").param("symbol","EURUSD"))
      .andExpect(status().isOk());
  }

  @Test void backtestAndStrategyPreviewUseQueryNames() throws Exception {
    mvc.perform(get("/api/strategies/evaluate")
      .param("symbol","EURUSD").param("strategy","SMA_CROSS"))
      .andExpect(status().isOk());
    mvc.perform(get("/api/backtest/run")
      .param("symbol","EURUSD").param("strategy","SMA_CROSS"))
      .andExpect(status().isOk());
  }

  @Test void liveOrderSubmissionRemainsLocked() throws Exception {
    mvc.perform(post("/api/live/orders").contentType("application/json").content("{}"))
      .andExpect(status().is(423));
  }
}