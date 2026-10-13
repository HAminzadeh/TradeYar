# TradeYar Maven portability and troubleshooting

TradeYar's Maven build originally picked up machine-specific Maven settings pointing at an internal Nexus URL (`172.16.x.x`). If the user is away from that network, Maven can fail before Java tests start. This is a network/repository configuration problem, not proof of a Java source error.

## Recommended build (only if public Maven Central is permitted by your network policy)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-TradeYar-Maven.ps1 -Goal Test
```

The wrapper passes project-local `-s infrastructure/maven/settings-central.xml` and `-gs infrastructure/maven/settings-empty.xml`. It does **not** change global or per-user Maven settings. Maven artifacts are retrieved via HTTPS from `repo.maven.apache.org` using your usual local cache.

To start Java backend directly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-TradeYar-Maven.ps1 -Goal Start
```

To use your organization's approved Maven configuration instead:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-TradeYar-Maven.ps1 -Goal Test -UseSystemSettings
```

This may require corporate VPN, authenticated Nexus access, or a proxy. If both are unreachable, do not edit production application code to work around the network. Fix approved connectivity first.

## Runtime smoke test

When backend is running:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Smoke-Test-TradeYar.ps1
```

This asserts API health, 20 modules, 100 synthetic EURUSD candles, and HTTP 423 rejection of live orders.

## Portability rules

Commit the Maven settings XML files, this doc, the Maven wrapper script, and launcher updates to Git. Do not commit credentials, personal Maven settings, .env, target/, or node_modules/.