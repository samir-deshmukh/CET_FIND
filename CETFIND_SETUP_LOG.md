# CETFind Local Setup Record

Date: 2026-11-16
Device: DESKTOP-TR57MRK (Windows 11 Pro)
Repository: CAP_FIND

## Completed setup
1. Enabled WSL and Virtual Machine Platform, then restarted Windows.
2. Installed Ubuntu 24.04.5 under WSL 2. Verified kernel 6.18.58.1-microsoft-standard-WSL2.
3. Installed Docker Desktop 4.99.0 using winget after administrator approval.
4. Verified Docker Engine 29.9.3 and Docker Compose v5.7.0 with the WSL 2 backend.
5. Added C:\Program Files\Docker\Docker\resources\bin to the current Windows user's PATH so docker-credential-desktop.exe is discoverable.
6. Checked .env.docker-local without printing values. POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB, DATABASE_URL, and CET_ADMIN_SESSION_SECRET are set.
7. Validated Compose configuration successfully.
8. Built the CAP_FIND backend image and started PostgreSQL and backend using compose.yaml plus compose.local.yaml.

## Verification
- PostgreSQL container: healthy.
- CAP_FIND backend container: healthy.
- http://127.0.0.1:8000/healthz: HTTP 200, {"ok":true}.
- http://127.0.0.1:8000/: HTTP 200.
- http://127.0.0.1:8000/admin: HTTP 200.
- Local extraction worker is running on 127.0.0.1:8765.
- Worker /health: HTTP 200; idle, no active or queued job.
- CAPFIND_REMOTE_WORKER_TOKEN exists in Windows User environment; value intentionally not recorded.
- Worker launch script targets https://cetfind-backend.onrender.com.
- Live backend /healthz: HTTP 200 on retry; one earlier request timed out while service was waking.

## Important limitation
The new local PostgreSQL volume has the application schema (39 tables), but data tables are empty: institutes=0, cutoffs=0, seats=0, programs=0, admin_users=0. Local pages and health checks respond, but this is not yet a populated local CETFind demo database. Do not use local college search for the demo until the intended dataset/database backup is loaded and a local admin account is provisioned.

No real remote extraction job was submitted in this setup pass. Worker health and live backend health are verified, but end-to-end remote upload, extraction, and staging remain unverified.

## Change record
- No .env values or worker token values are recorded.
- No Render configuration or production data was changed.
- No Git-tracked CAP_FIND files were modified; this file is a new local record.
- No actions were performed on Vedant's laptop.

## Start commands
From the CAP_FIND folder:

```powershell
docker compose --env-file .env.docker-local -f compose.yaml -f compose.local.yaml up -d --build
```

Check status:

```powershell
docker compose --env-file .env.docker-local -f compose.yaml -f compose.local.yaml ps
```

Stop containers without deleting database volumes:

```powershell
docker compose --env-file .env.docker-local -f compose.yaml -f compose.local.yaml stop
```

## One-key VS Code startup fix (2026-11-16)

The original VS Code F5 configuration launched Chrome at port 8080 but did not start a frontend server. The backend root on port 8000 intentionally redirects to the production static website, so starting only PostgreSQL/FastAPI left localhost:8080 unavailable.

Implemented:
- Added a local-only Nginx `web` service to `compose.local.yaml`, serving `site/` read-only at `http://127.0.0.1:8080`.
- Added `scripts/start_cetfind.ps1` to validate the local environment file, resolve Docker CLI/helper PATH, start Docker Desktop if needed, start Compose services, and wait for backend and frontend HTTP readiness.
- Added `.vscode/tasks.json` and linked the task as `preLaunchTask` in `.vscode/launch.json`. F5 now starts the full local stack before opening Chrome.
- Updated the VS Code launch name to `CETFind: Run locally (Docker + Website)`.

Verification on DESKTOP-TR57MRK:
- Compose configuration validation passed.
- Startup script completed with exit code 0.
- Backend `http://127.0.0.1:8000/healthz`: HTTP 200.
- Frontend `http://127.0.0.1:8080/`: HTTP 200 and returned the CETFind page title.
- PostgreSQL and backend containers healthy; Nginx frontend container running.
- Docker credential helper PATH issue encountered during first test was fixed inside the startup script; no credentials were recorded.

For another Windows PC, install Docker Desktop, create its own `.env.docker-local` from the example, open the cloned repository folder in VS Code, and press F5. The first run needs internet access to pull the Nginx image/build dependencies. Local PostgreSQL remains a separate empty database unless the intended demo dataset is imported; this startup fix does not populate it.
