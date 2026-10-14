package com.tradeyar.app.bootstrap;

import java.util.List;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class StartupDependencyMonitorTest {
    @Test void startupInventoryNeverAuthorizesRealTrading() {
        StartupDependencyMonitor monitor = new StartupDependencyMonitor();
        List<StartupDependencyMonitor.Check> checks = monitor.scan(false);
        assertTrue(checks.stream().anyMatch(c -> c.id().equals("JAVA") && c.required()));
        assertTrue(checks.stream().anyMatch(c -> c.id().equals("POSTGRES_PORT")));
        assertTrue(checks.stream().anyMatch(c -> c.id().equals("MT5_TERMINAL")));
        assertTrue(checks.stream().anyMatch(c -> c.id().equals("LIVE_EXECUTION") && c.state().equals("LOCKED")));
        assertEquals(false, monitor.status().get("liveTradingEnabled"));
        assertEquals(checks.size(), ((List<?>) monitor.status().get("components")).size());
    }
}
