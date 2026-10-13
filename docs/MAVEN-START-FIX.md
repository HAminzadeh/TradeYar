# TradeYar: Spring Boot Maven startup

The Maven reactor has a parent `backend/pom.xml` (packaging `pom`) and an application module `backend/app/pom.xml` (packaging `jar`). The Spring Boot run goal must execute **against the application POM**, not the parent reactor with `-am`.

The source-controlled wrapper `scripts/Invoke-TradeYar-Maven.ps1` now:

- Uses `backend/pom.xml` for `Test` and `Package`.
- Uses `backend/app/pom.xml` for `Start`.
- Calls `org.springframework.boot:spring-boot-maven-plugin:<version>:run` by fully qualified coordinates. The version is synchronized with `backend/pom.xml` by the repair script when applied.
- Uses project-only Maven Central settings unless the user explicitly selects `-UseSystemSettings`. No global Maven configuration is modified.

## Test

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-TradeYar-Maven.ps1 -Goal Test
```

## Start

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-TradeYar-Maven.ps1 -Goal Start
```

A successful server start shows Spring Boot listening on port 8080; it keeps the terminal open until Ctrl+C.
From a second PowerShell window run `scripts/Smoke-Test-TradeYar.ps1`.

The source changes must be committed and pushed to GitHub to persist across other computers. Do not run an older Maven repair installer afterward: it may rewrite the wrapper with the legacy `-am spring-boot:run` command.