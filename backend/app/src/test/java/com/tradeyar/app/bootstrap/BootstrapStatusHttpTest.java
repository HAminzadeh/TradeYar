package com.tradeyar.app.bootstrap;

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
class BootstrapStatusHttpTest {
    @Autowired MockMvc mvc;

    @Test void dependencyApiReportsLiveLockWithoutSecrets() throws Exception {
        mvc.perform(get("/api/v1/bootstrap/status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.liveTradingEnabled").value(false))
                .andExpect(jsonPath("$.automaticTradingEnabled").value(false))
                .andExpect(jsonPath("$.components.length()").value(17));
    }

    @Test void liveOrderEndpointRemainsLocked() throws Exception {
        mvc.perform(post("/api/live/orders").contentType("application/json").content("{}"))
                .andExpect(status().is(423));
    }
}
