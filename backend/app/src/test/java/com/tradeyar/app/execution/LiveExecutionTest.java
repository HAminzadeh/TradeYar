package com.tradeyar.app.execution;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

class LiveExecutionTest {
  @Test void alwaysRejects() {
    var controller=new LiveExecutionController();
    assertEquals(false,controller.status().get("enabled"));
    assertThrows(ResponseStatusException.class,() -> controller.reject("{}"));
  }
}