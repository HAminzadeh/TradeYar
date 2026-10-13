package com.tradeyar.app.core;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

class ModulesControllerTest {
  @Test void hasTwentyModules() { assertEquals(20,new ModulesController().modules().size()); }
  @Test void liveIsLocked() {
    assertEquals("LOCKED",new ModulesController().modules().get(19).get("status"));
  }
}