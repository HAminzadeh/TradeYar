# TradeYar | ØªØ±ÛŒØ¯ÛŒØ§Ø±

Java-first bilingual forex research workstation. **Development scaffold only.** Persian (RTL) is the default UI language; English (LTR) can be selected.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [All stages and modules](docs/PHASES.md)
- [Development API](docs/API.md)

## Generate the full scaffold

From PowerShell in the repository:

```powershell
.\scripts\Build-TradeYar.ps1 -Stage All -Verify
.\scripts\Setup-TradeYar.ps1 -InstallDependencies
.\scripts\Start-TradeYar.ps1
```

Dashboard http://localhost:5173 â€” Backend http://localhost:8080/api/health

**Important:** only synthetic demo quotes are generated; paper orders and user preferences are stored in memory, the Python AI model is untrained, the MT5 bridge is read-only, and live order submission is hard-locked. PostgreSQL and Redis are provisioned but not yet connected to backend repositories. No real-money trading capability is provided.