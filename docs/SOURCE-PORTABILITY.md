# TradeYar: source portability and regression tests

This change is SOURCE-LEVEL. It is not merely an edit to a running JVM.

## What was repaired

1. `@RequestParam(name="...")` is explicit in controllers, so endpoint queries
   do not depend solely on reflection parameter-name metadata.
2. `maven-compiler-plugin` sets `<parameters>true</parameters>`.
3. `scripts/Build-TradeYar.ps1` contains the same changes and is stored as
   UTF-8 with BOM (important for Windows PowerShell 5.1 and Persian literals).
4. `.editorconfig` requests UTF-8 BOM for `.ps1` and UTF-8 for UI source.
5. `ApiContractRegressionTest` verifies 100 synthetic EURUSD bars over HTTP,
   other query endpoints, and HTTP 423 for live order requests.

## On another Windows computer

Clone the GitHub repository AFTER committing/pushing these changes.
Run PowerShell from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-TradeYar.ps1 -Stage All
.\scripts\Setup-TradeYar.ps1 -InstallDependencies
mvn -f .\backend\pom.xml clean test
.\scripts\Start-TradeYar.ps1
```

Visit http://127.0.0.1:5173 to test Persian/English and the chart.
The market data is SYNTHETIC; this is not a real trading service.

## Avoid regressions

- Do not overwrite the repaired sources with an OLD downloaded builder.
- Never commit `.env`, broker credentials or `.tradeyar-backups`.
- After future changes run `mvn -f backend/pom.xml clean test` and
  `npm run build` from the `frontend` directory.
- Restart Spring Boot after compiling. An already running JVM keeps old classes.