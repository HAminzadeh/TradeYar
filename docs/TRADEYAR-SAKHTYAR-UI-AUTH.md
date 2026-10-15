# TradeYar v0.6.3 — SakhtYar-inspired theme & optional user access

## What was reviewed
Source reference: `HAminzadeh/SakhtYar` on GitHub, especially `frontend/src/ui/tokens.ts`, `frontend/src/styles/global.css`, `frontend/src/pages/LoginPage.tsx`, `frontend/src/pages/UsersPage.tsx`, `frontend/src/auth/AuthProvider.tsx` and `backend/modules/identity`.

### UI behavior
- SakhtYar light design tokens (`#2563EB`, `#F6F8FC`, `#0F766E`) with RTL, responsive navigation, 44–48px accessible controls, rounded cards and consistent forms.
- Installed `B Nazanin` is the preferred font; font binaries **are not bundled or copied** (copyright/license and Windows availability). Fallback to Vazirmatn/IRANSansX/Tahoma.
- Self-contained SVG financial illustration used instead of any construction/property images; no runtime external-image request. `frontend/public/assets/trading-market.svg`.
- Frontend wrap is additive: existing module routes, strategy logic, dashboard, charting, MT5 and live-order HTTP 423 remain unchanged. Existing theme selector can still select other themes; the default becomes `day` for new profiles.
- Login, registration (PENDING), user cards, admin status/role editing, password reset, lock reset and logout.

### Server permission model
| Role | Grants |
| --- | --- |
| ADMIN | USER_MANAGE, RESEARCH_READ, RESEARCH_RUN, PAPER_TRADE, AUDIT_READ |
| RESEARCH_MANAGER | RESEARCH_READ, RESEARCH_RUN, PAPER_TRADE, AUDIT_READ |
| ANALYST | RESEARCH_READ, RESEARCH_RUN |
| VIEWER | RESEARCH_READ |

No role has or can grant live order execution. This feature is opt-in so v0.6.3 regression tests and prior demo-mode APIs remain unaffected until explicitly activated. In enabled mode all `/api/**` routes require a valid session except `/api/health`, `/api/v1/auth/status`, registration and login. Server-side filter enforces permissions on admin endpoints, read and write paths. **The Python AI service (port 8001), direct broker integrations and non-`/api/` endpoints need separate authentication review before any network exposure.** Keep loopback binds and the existing live-order lock.

### Security design and limitations
- PostgreSQL **dedicated TradeYar schema** with prepared SQL statements. No SakhtYar tables/volumes are modified.
- PBKDF2-HMAC-SHA256 310k rounds and random 16-byte salt; unique username/email; password policy >=12 characters with letter, digit and symbol.
- Server-generated, random session tokens in `HttpOnly; SameSite=Strict` cookies, only token hashes in the DB, 12h expiry; `Secure` flag when Spring sees an HTTPS request.
- Server-side CSRF token checked on mutating routes, browser-origin restriction, temporary lock after five failed logins, audit of registration/login/admin operations, session invalidation on role/status/password change.
- Registration defaults to VIEWER / PENDING; admin must approve. Bootstrap admin requires an **explicitly supplied temporary secret**; no default passwords or seeded demo credentials.
- Must configure HTTPS proxy/forwarded headers correctly for secure cookies if running behind TLS proxy. Allowed browser origins must be explicitly reviewed for deployment. Not penetration-tested. Does not implement OIDC, MFA, password recovery email or independent authorization of external services.
- This is a new source implementation; not a claim that runtime auth, database migration, or browser E2E tests have passed on operator Windows.

## Install (Windows PowerShell 5.1)
Extract the kit outside the Git working tree, then:

```powershell
$Kit = Join-Path $HOME 'Downloads\TradeYar-SakhtYar-Theme-Kit'
$Project = 'D:\ChatGPT_Projects\TradeYar'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Kit\Install-TradeYar-SakhtYar-Theme.ps1" -ProjectPath $Project -Stage All
if ($LASTEXITCODE -ne 0) { throw 'Dry-run failed' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Kit\Install-TradeYar-SakhtYar-Theme.ps1" -ProjectPath $Project -Stage All -Apply
if ($LASTEXITCODE -ne 0) { throw 'Apply failed' }
```

`-Stage UI` applies only the new theme/graphic/pages and default appearance. The install preflight refuses dirty tracked targets and existing conflicting files; the apply backs up targeted original source files outside Git. It does not start Docker, create database users, overwrite `.env`, or touch the shared SakhtYar MinIO.

```powershell
cd D:\ChatGPT_Projects\TradeYar\frontend
npm run typecheck
npm run build
```

## Activate authentication only after database setup

1. Ensure a **dedicated TradeYar PostgreSQL database and least-privileged credentials** exist and the PostgreSQL JDBC driver dependency has been installed through an explicitly approved, one-time Maven dependency acquisition. It is **not copied into the specialist offline Docker depot**.
2. Review and manually apply `platform/v063/sql/005_identity.sql` with `psql` against the TradeYar database. Do not run it on SakhtYar DB; do not run unreviewed SQL. Backup first.
3. In the local PowerShell session that starts Spring Boot (not in Git):

```powershell
$env:TRADEYAR_AUTH_ENABLED = 'true'
$env:TRADEYAR_AUTH_DB_URL = 'jdbc:postgresql://127.0.0.1:5433/YOUR_TRADEYAR_DB'
$env:TRADEYAR_AUTH_DB_USER = 'YOUR_LEAST_PRIVILEGED_DB_USER'
$env:TRADEYAR_AUTH_DB_PASSWORD = Read-Host 'TradeYar DB password'
$env:TRADEYAR_AUTH_BOOTSTRAP_USERNAME = 'admin'
$env:TRADEYAR_AUTH_BOOTSTRAP_PASSWORD = Read-Host 'Initial admin password (12+ strong characters)'
$env:TRADEYAR_AUTH_ALLOWED_ORIGINS = 'http://127.0.0.1:5173,http://127.0.0.1:8080'
```

4. Run the backend **from this PowerShell environment** and check `GET http://127.0.0.1:8080/api/v1/auth/status`, which should return `{ "enabled": true, "configured": true }`. Log in once. Then clear temporary bootstrap credentials from the process environment, e.g. `Remove-Item Env:TRADEYAR_AUTH_BOOTSTRAP_PASSWORD, Env:TRADEYAR_AUTH_BOOTSTRAP_USERNAME` and ensure no plaintext secrets are committed.
5. Before calling this production-ready, run local login/logout, PENDING/ACTIVE/SUSPENDED, role isolation, CSRF rejection, expired/revoked session, rate limiting, schema migration, security tests, all legacy Java/frontend regressions and HTTPS cookie checks.

**Operational warning:** do not enable authentication in an environment with missing JDBC dependencies, missing schema or unset credentials. In enabled-but-unconfigured mode the UI fails closed; the normal Demo path is not automatically promoted to a secure deployment.

## Design verification checklist

- `frontend/src/main.tsx` wraps existing App with `AccessPortal` and imports theme stylesheet; no original module implementation replaced.
- `quickstart/config.ts` defaults new users to `day`, but existing saved appearance selections are preserved.
- `AccessPortal` waits for backend capability status before gating; if the backend implementation is absent or disabled, a visible Demo/legacy banner is shown instead of pretending users are protected.
- No social sign-in buttons (Google/Microsoft), password-reset email, or real-market quote claims are drawn: those services have not been integrated.
- No Docker image pulls or automatic secret migration.

## Files and provenance

SakhtYar-inspired UI is an adaptation of the project's component architecture and palette, not a copy of passwords, production configuration, private data or binary assets. Java AccessService and schema are an independent implementation specific to TradeYar, not a drop-in replacement for SakhtYar JWT/Spring Security. Review threat model and access policies before public deployment.
