package com.tradeyar.app.bootstrap;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Read-only runtime probe. Does not execute downloaded binaries, manage credentials, or trade. */
@Component
@EnableScheduling
public class StartupDependencyMonitor {
    private static final Logger LOG = LoggerFactory.getLogger(StartupDependencyMonitor.class);
    public record Check(String id, String state, boolean required, String message) {}
    private volatile List<Check> last = List.of();
    private volatile String checkedAt = "NOT_SCANNED";
    private final Path root;

    public StartupDependencyMonitor() {
        this.root = projectRoot();
    }

    private static Path projectRoot() {
        String override = System.getenv("TRADEYAR_PROJECT_ROOT");
        Path probe = Path.of(override != null && !override.isBlank() ? override : System.getProperty("user.dir"))
                .toAbsolutePath().normalize();
        for (int i = 0; i < 7 && probe != null; i++, probe = probe.getParent()) {
            if (Files.isRegularFile(probe.resolve("backend/app/pom.xml"))
                    && Files.isDirectory(probe.resolve("scripts"))) return probe;
        }
        return null;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void onReady() {
        LOG.info("[BOOTSTRAP] Startup dependency inventory began; backend is ready for DEMO/RESEARCH");
        scan(true);
        LOG.info("[BOOTSTRAP] Live broker order execution remains LOCKED (HTTP 423)");
        if ("true".equalsIgnoreCase(System.getenv("TRADEYAR_AUTO_REPAIR_ON_STARTUP"))) {
            launchEnrolledRepair();
        } else {
            LOG.info("[BOOTSTRAP] Managed repair disabled. Set TRADEYAR_AUTO_REPAIR_ON_STARTUP=true after local enrollment to opt in");
        }
    }

    @Scheduled(initialDelay = 60000, fixedDelayString = "${tradeyar.bootstrap.scan-interval-ms:120000}")
    public void scheduledScan() { scan(false); }

    public synchronized List<Check> scan(boolean forceLog) {
        List<Check> next = new ArrayList<>();
        String javaVersion = System.getProperty("java.version", "unknown");
        int feature = Runtime.version().feature();
        next.add(new Check("JAVA", feature >= 21 ? "READY" : "UNSUPPORTED", true,
                "JVM " + javaVersion + "; Java 21+ required"));
        next.add(cachedCommand("NODE", "node.exe", "node", "node.exe", "node", "Vite UI runtime"));
        next.add(cachedCommand("NPM", "npm.cmd", "npm", "npm.cmd", "node", "Frontend dependency installer"));
        boolean pyVenv = root != null && Files.isRegularFile(root.resolve("python/ai-service/.venv/Scripts/python.exe"));
        Check py = command("PYTHON", "python.exe", "python3", false, "Python AI/MT5 support");
        next.add(pyVenv ? new Check("PYTHON", "READY", false, "Project-local Python environment available") : (py.state().equals("READY") ? py : cachedCommand("PYTHON", "python.exe", "python3", "python.exe", "python", "Python AI/MT5 support")));
        next.add(new Check("MAVEN_LAUNCHER", root != null && Files.isRegularFile(root.resolve("scripts/Invoke-TradeYar-Maven.ps1")) ? "AVAILABLE" : "NOT_FOUND", false,
                "Project-local Maven launcher; dependency resolution is verified by running Maven tests"));
        next.add(new Check("FRONTEND_PACKAGES", root != null && Files.isDirectory(root.resolve("frontend/node_modules")) ? "PRESENT_UNVERIFIED" : "NOT_INSTALLED", false,
                "npm packages on disk; package-lock integrity needs npm ci/build verification"));
        next.add(pythonModule("PY_PSYCOPG", "psycopg", "PostgreSQL Python adapter"));
        next.add(pythonModule("PY_MT5", "MetaTrader5", "Optional read-only MT5 Python adapter"));
        next.add(command("PSQL_CLI", "psql.exe", "psql", false, "Database maintenance client"));
        next.add(port("POSTGRES_PORT", 5432, "PostgreSQL listener only; not an authentication check"));
        next.add(port("REDIS_PORT", 6379, "Redis listener only; optional"));
        next.add(port("AI_SERVICE", 8001, "Optional local AI service listener"));
        String dsn = System.getenv("TRADEYAR_PG_DSN");
        next.add(new Check("PG_CONFIGURATION", dsn != null && !dsn.isBlank() ? "CONFIGURED" : "NOT_CONFIGURED", false,
                "Private PostgreSQL connection string " + (dsn != null && !dsn.isBlank() ? "is set (contents never logged)" : "is not configured")));
        next.add(mt5Check());
        boolean hasArchive = hasArchive();
        next.add(new Check("MARKET_HISTORY", hasArchive ? "AVAILABLE" : "NOT_COLLECTED", false,
                hasArchive ? "Local archive manifest detected (integrity not verified by this probe)" : "No history manifest found; read-only collector is optional"));
        boolean enrolled = root != null && Files.isRegularFile(root.resolve(".tradeyar-runtime/bootstrap-policy.json"));
        next.add(new Check("MANAGED_REPAIR", enrolled ? "ENROLLED" : "NOT_ENROLLED", false,
                enrolled ? "Local operator policy exists; repair still requires explicit startup opt-in" : "Run approved Windows launcher -Mode Enroll once"));
        next.add(new Check("LIVE_EXECUTION", "LOCKED", true, "Broker order API is intentionally disabled"));
        Map<String, Check> before = new LinkedHashMap<>();
        last.forEach(c -> before.put(c.id(), c));
        int ready = 0;
        for (Check check : next) {
            if (check.state().equals("READY") || check.state().equals("AVAILABLE") || check.state().equals("CONFIGURED") || check.state().equals("LOCKED") || check.state().equals("ENROLLED")) ready++;
            Check old = before.get(check.id());
            if (forceLog || old == null || !Objects.equals(old.state(), check.state())) {
                if (check.required() && check.state().equals("UNSUPPORTED"))
                    LOG.error("[BOOTSTRAP] {} -> {} | {}", check.id(), check.state(), check.message());
                else LOG.info("[BOOTSTRAP] {} -> {} | {}", check.id(), check.state(), check.message());
            }
        }
        last = List.copyOf(next);
        checkedAt = Instant.now().toString();
        if (forceLog) LOG.info("[BOOTSTRAP] Inventory complete: {}/{} in ready/configured/locked states. Optional missing components do not authorize trading", ready, next.size());
        return last;
    }

    public Map<String, Object> status() {
        return Map.of("checkedAtUtc", checkedAt, "components", last, "liveTradingEnabled", false,
                "automaticTradingEnabled", false, "policy", "FAIL_CLOSED_REAL_ORDERS");
    }

    private Check cachedCommand(String id, String windowsName, String unixName, String binary, String packageId, String description) {
        Check system = command(id, windowsName, unixName, false, description);
        if (system.state().equals("READY") || root == null) return system;
        Path tools = root.resolve(".tradeyar-runtime/tools/" + packageId);
        if (!Files.isDirectory(tools)) return system;
        try (var walk = Files.walk(tools, 4)) {
            if (walk.anyMatch(p -> Files.isRegularFile(p) && p.getFileName().toString().equalsIgnoreCase(binary))) {
                return new Check(id, "LOCAL_FILE_UNVERIFIED", false, "Project-local runtime detected; bootstrap launcher must verify cache and active executable");
            }
        } catch (Exception ignored) { }
        return system;
    }

    private Check pythonModule(String id, String module, String explanation) {
        String python = System.getProperty("os.name", "").toLowerCase(Locale.ROOT).contains("win") ? "py" : "python3";
        List<String> args = new ArrayList<>(List.of(python));
        if (python.equals("py")) args.add("-3");
        args.add("-c");
        args.add("import importlib.util,sys;sys.exit(0 if importlib.util.find_spec('" + module + "') else 1)");
        try {
            Process p = new ProcessBuilder(args).redirectErrorStream(true).start();
            boolean finished = p.waitFor(2500, TimeUnit.MILLISECONDS);
            if (!finished) p.destroyForcibly();
            return new Check(id, finished && p.exitValue() == 0 ? "AVAILABLE" : "NOT_INSTALLED", false, explanation);
        } catch (Exception ignored) {
            return new Check(id, "NOT_INSTALLED", false, explanation + "; Python interpreter unavailable");
        }
    }

    private static Check command(String id, String windowsName, String unixName, boolean required, String explanation) {
        String command = System.getProperty("os.name", "").toLowerCase(Locale.ROOT).contains("win") ? windowsName : unixName;
        String finder = System.getProperty("os.name", "").toLowerCase(Locale.ROOT).contains("win") ? "where.exe" : "which";
        boolean found = false;
        try {
            Process process = new ProcessBuilder(finder, command).redirectErrorStream(true).start();
            found = process.waitFor(1300, TimeUnit.MILLISECONDS) && process.exitValue() == 0;
            if (process.isAlive()) process.destroyForcibly();
        } catch (Exception ignored) { /* missing executable is a normal diagnostic outcome */ }
        return new Check(id, found ? "READY" : "MISSING", required, explanation);
    }

    private static Check port(String id, int port, String description) {
        try (Socket socket = new Socket()) {
            socket.connect(new InetSocketAddress("127.0.0.1", port), 280);
            return new Check(id, "PORT_OPEN", false, description + "; application health is NOT confirmed");
        } catch (Exception ex) {
            return new Check(id, "PORT_CLOSED", false, description);
        }
    }

    private Check mt5Check() {
        String configured = System.getenv("TRADEYAR_MT5_PATH");
        List<Path> candidates = new ArrayList<>();
        if (configured != null && !configured.isBlank()) {
            try { candidates.add(Path.of(configured)); } catch (RuntimeException ignored) { }
        }
        String program = System.getenv("ProgramFiles");
        if (program != null) candidates.add(Path.of(program, "MetaTrader 5", "terminal64.exe"));
        String local = System.getenv("LOCALAPPDATA");
        if (local != null) candidates.add(Path.of(local, "Programs", "MetaTrader 5", "terminal64.exe"));
        boolean installed = candidates.stream().anyMatch(Files::isRegularFile);
        return new Check("MT5_TERMINAL", installed ? "INSTALLED_UNVERIFIED" : "NOT_FOUND", false,
                installed ? "Terminal executable present; login, broker permissions and feed are NOT confirmed" : "Optional MT5 terminal not detected; nothing launched");
    }

    private boolean hasArchive() {
        String local = System.getenv("LOCALAPPDATA");
        if (local == null || local.isBlank()) return false;
        Path base = Path.of(local, "TradeYar", "history");
        if (!Files.isDirectory(base)) return false;
        try (var stream = Files.find(base, 3, (p, attrs) -> attrs.isRegularFile() && p.getFileName().toString().equals("_manifest.json"))) {
            return stream.findFirst().isPresent();
        } catch (Exception ignored) { return false; }
    }

    private void launchEnrolledRepair() {
        if (root == null) {
            LOG.warn("[BOOTSTRAP] Auto-repair skipped: TradeYar project root not found; configure TRADEYAR_PROJECT_ROOT");
            return;
        }
        Path script = root.resolve("scripts/Start-TradeYar-Managed.ps1");
        Path policy = root.resolve(".tradeyar-runtime/bootstrap-policy.json");
        if (!Files.isRegularFile(script) || !Files.isRegularFile(policy)) {
            LOG.warn("[BOOTSTRAP] Auto-repair skipped: signed-off local script/policy not found. Run -Mode Enroll");
            return;
        }
        if (!System.getProperty("os.name", "").toLowerCase(Locale.ROOT).contains("win")) {
            LOG.warn("[BOOTSTRAP] Auto-repair only supports Windows at present");
            return;
        }
        String windir = System.getenv("WINDIR");
        if (windir == null) windir = "C:\\Windows";
        Path powershell = Path.of(windir, "System32", "WindowsPowerShell", "v1.0", "powershell.exe");
        if (!Files.isRegularFile(powershell)) {
            LOG.warn("[BOOTSTRAP] Windows PowerShell not available; repair skipped");
            return;
        }
        try {
            ProcessBuilder builder = new ProcessBuilder(powershell.toString(), "-NoProfile", "-NonInteractive", "-File",
                    script.toString(), "-Mode", "Repair", "-ProjectPath", root.toString());
            builder.directory(root.toFile());
            builder.redirectErrorStream(true);
            Process process = builder.start();
            Thread reader = new Thread(() -> {
                try (BufferedReader out = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
                    String line;
                    while ((line = out.readLine()) != null) LOG.info("[BOOTSTRAP:REPAIR] {}", line);
                    int exit = process.waitFor();
                    if (exit == 0) LOG.info("[BOOTSTRAP:REPAIR] Completed. Re-scanning dependencies on next interval");
                    else LOG.warn("[BOOTSTRAP:REPAIR] Exited with code {}", exit);
                } catch (Exception e) {
                    Thread.currentThread().interrupt();
                    LOG.warn("[BOOTSTRAP:REPAIR] Could not read repair status: {}", e.getClass().getSimpleName());
                }
            }, "tradeyar-bootstrap-log-reader");
            reader.setDaemon(true);
            reader.start();
        } catch (Exception e) {
            LOG.warn("[BOOTSTRAP] Auto-repair launch failed: {}", e.getClass().getSimpleName());
        }
    }
}

@RestController
@RequestMapping("/api/v1/bootstrap")
class BootstrapStatusController {
    private final StartupDependencyMonitor monitor;
    BootstrapStatusController(StartupDependencyMonitor monitor) { this.monitor = monitor; }
    @GetMapping("/status") Map<String, Object> status() { return monitor.status(); }
}
