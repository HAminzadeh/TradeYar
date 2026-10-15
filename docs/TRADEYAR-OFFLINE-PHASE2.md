# TradeYar v0.6.3 — Phase 2, shared MinIO and offline ClickHouse

## Design

TradeYar **reuses the operator's already-running MinIO service** and does not start a new MinIO container or copy its credentials. Its identity and possible S3 API host port are saved in `D:\ChatGPT_Projects\TradeYar-OfflineDepot\manifests\shared-minio.json` (outside Git). This manifest is inventory, **not proof of authenticated access**, and not a backup of a shared MinIO image or data. Do not modify or delete the shared service/volume. Ensure permission to access the existing bucket or create a dedicated TradeYar bucket with least-privileged credentials via its administrator. Do not reuse MinIO root credentials in Git.

Because `platform/v063/tradeyar_core/storage.py` currently only contains PostgreSQL/Timescale helpers, a MinIO-specific client is **not yet implemented**. Configure an operator-approved `TRADEYAR_OBJECT_ENDPOINT`, access key, and secret locally when a MinIO adapter is introduced; do not claim object-store integration is complete from image inventory alone. A localhost endpoint hint may require adjustment for TLS or Docker-internal clients (`host.docker.internal`).

### Resolved ClickHouse version

The old `clickhouse/clickhouse-server:25.3` registry request returned `403 Forbidden` on the operator's machine. This kit explicitly changes Compose and image lock to `clickhouse:25.3.14.14` (Docker Official Image) **only after** a real `linux/amd64` Docker image is acquired, exported, SHA-256 checked, and then loaded/validated offline. The exact version is deliberate; no `latest` or implicit fallback. Archive: `clickhouse-25.3.14.14.tar`.

### Initial acquisition (requires internet, explicitly approved)

After inspecting the scripts, run on the operator's Windows machine with Docker Desktop in Linux/amd64 mode:

```powershell
$Kit = "$HOME\Downloads\TradeYar-Phase2-SharedMinIO-Kit"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Kit\01-Inspect-Running-MinIO.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Kit\02-Get-ClickHouse-ONLINE.ps1" -ApproveNetworkDownload -OutputFolder "$HOME\Downloads"
```

This creates `clickhouse-25.3.14.14-linux-amd64.tar`, `.sha256`, and `.json` locally. If the registry gives 403 again, stop and report the failure; do **not** silently choose a different image, mirror, or unverified tar.

### Offline install (can disconnect network now)

```powershell
$Project = 'D:\ChatGPT_Projects\TradeYar'
$Kit = "$HOME\Downloads\TradeYar-Phase2-SharedMinIO-Kit"
$Archive = "$HOME\Downloads\clickhouse-25.3.14.14-linux-amd64.tar"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Kit\03-Install-Phase2-OFFLINE.ps1" -ProjectPath $Project -ClickHouseArchive $Archive -DryRun
if ($LASTEXITCODE -ne 0) { throw 'Phase2 dry-run failed' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Kit\03-Install-Phase2-OFFLINE.ps1" -ProjectPath $Project -ClickHouseArchive $Archive -Apply
if ($LASTEXITCODE -ne 0) { throw 'Phase2 offline apply failed' }
```

The installer checks SHA-256 and the original Docker image ID; uses only `docker load` and local files; backs up Compose, lock, manager, launcher, tests and docs to an offline depot outside Git. It records the exact running MinIO container name and image ID. **Neither a MinIO root credential nor any Docker volume is changed.** If more than one candidate MinIO container is running, use `-MinioContainerName EXACT_NAME` with the approved name; the installer will not guess.

### Finish and verify offline

```powershell
$Manager = Join-Path $Project 'scripts\Manage-TradeYar-OfflineImages.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Manager -ProjectPath $Project -Mode Seed
if ($LASTEXITCODE -ne 0) { throw 'Seed failed; check which local image is missing' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Manager -ProjectPath $Project -Mode Verify
if ($LASTEXITCODE -ne 0) { throw 'Verify failed' }
py -3 -m unittest discover -s "$Project\tests" -p 'test_offline_image_manifest.py' -v
```

The installer already seeds and verifies the three dedicated image archives (TimescaleDB, Neo4j, ClickHouse), and the commands above can recheck them; MinIO remains the existing **external runtime**. This is deliberate and does not mean the shared MinIO itself is backed up. Full offline DR of the shared MinIO service must be handled by its owner. TradeYar's normal startup still uses `--pull never`.

### Safety notes

- `docker compose up` for TradeYar cannot start a new `minio` service after this change; the service was removed from this Compose definition, but no existing container or volume is removed.
- Existing TimescaleDB and Neo4j exact image tags are unchanged. No general JDK/Maven/npm/Python caches are mirrored.
- Do not run `docker compose down -v` or `docker system prune` against shared development resources.
- Backups are source backups; live database volumes require a separate DR plan.
- TradeYar live broker execution remains disabled; nothing in this kit enables trading.
