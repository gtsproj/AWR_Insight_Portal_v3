# DAR Portal v3 — Docker Deployment

## Platform Requirements

| Platform | Support | Notes |
|---|---|---|
| Windows 10/11 with Docker Desktop | ✅ Supported | Enable WSL2 backend in Docker Desktop Settings → General |
| Windows Server 2019/2022 with Docker Desktop | ✅ Supported | Same WSL2 requirement |
| Linux (Ubuntu 20.04+, RHEL 8+, CentOS 8+) | ✅ Supported | Native — best performance |
| Windows Containers mode | ❌ Not supported | Requires Linux container mode (WSL2) |
| macOS with Docker Desktop | ✅ Supported | Tested on Apple Silicon and Intel |

## Windows Setup (Docker Desktop)

1. Install Docker Desktop from the official Docker website
2. During setup or in Settings → General: ensure **"Use WSL 2 based engine"** is checked
3. Apply and restart Docker Desktop
4. Open Command Prompt or PowerShell and verify:
   ```
   docker --version
   docker-compose --version
   ```

## Quick Start

```cmd
:: 1. Copy and configure environment file
copy .env.example .env
:: Edit .env in Notepad — change at minimum:
::   POSTGRES_PASSWORD=<your strong password>
::   GRAFANA_PASSWORD=<your grafana password>
::   DAR_PORTAL_URL=http://<your-server-name>:8000

:: 2. Build and start all containers
docker-compose up -d --build

:: 3. Watch startup progress (first run installs schema — takes ~60s)
docker-compose logs -f dar-portal

:: 4. Check all containers are running
docker-compose ps

:: 5. Open the portal
::   http://localhost:8000
::   Login: admin / Admin@123
```

## Container Architecture

```
┌─────────────────────────────────────────────┐
│  Docker Host (Windows or Linux)             │
│                                             │
│  ┌──────────────┐  ┌────────────────────┐  │
│  │ dar-postgres  │  │   dar-grafana      │  │
│  │ port 5432     │  │   port 3000        │  │
│  │ postgres:16   │  │   grafana-oss:12   │  │
│  └──────┬───────┘  └────────┬───────────┘  │
│         │  dar-network      │               │
│         └──────────┬────────┘               │
│                    │                         │
│  ┌─────────────────┴──────────────────────┐ │
│  │          dar-portal  port 8000         │ │
│  │  FastAPI + Queue Processor             │ │
│  │  AWR Watcher + SAR Watcher            │ │
│  │  Oracle AWR Scheduler                 │ │
│  │  SAR SSH Scheduler                    │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

## Named Volumes (Persistent Data)

| Volume | Contents | Path inside container |
|---|---|---|
| dar_postgres_data | All portal data | /var/lib/postgresql/data |
| dar_grafana_data | Dashboard state | /var/lib/grafana |
| dar_awr_reports | AWR HTML drop | /app/awr_reports |
| dar_sar_drop | SAR text drop | /app/sar_drop |
| dar_archive | AWR archive | /app/archive |
| dar_sar_archive | SAR archive | /app/sar_archive |
| dar_logs | App logs | /app/logs |

**⚠️ Never run `docker-compose down -v` — this destroys all volumes and all parsed data.**

## Operations

```cmd
:: Stop all containers (data preserved)
docker-compose stop

:: Start stopped containers
docker-compose start

:: Upgrade to new version
docker-compose pull
docker-compose up -d --build

:: View logs
docker-compose logs dar-portal
docker-compose logs dar-postgres
docker-compose logs dar-grafana

:: Access PostgreSQL directly
docker exec -it dar-postgres psql -U postgres

:: Backup database
docker exec dar-postgres pg_dump -U postgres postgres > backup.sql

:: Restore database
docker exec -i dar-postgres psql -U postgres postgres < backup.sql
```

## Uploading AWR/SAR Files

AWR HTML reports and SAR text files dropped into the named volumes
are automatically picked up by the watchers inside the container.

**From the host (Windows/Linux):**
```cmd
:: Find volume mount path on Windows Docker Desktop
docker inspect dar_awr_reports --format "{{.Mountpoint}}"

:: Or use docker cp to copy files in
docker cp myawr.html dar-portal:/app/awr_reports/
docker cp mysar.txt  dar-portal:/app/sar_drop/SERVERNAME/
```

## SSH Keys for SAR Server Access

Place SSH private key files in `docker/ssh-keys/`:
```
docker/ssh-keys/
  id_rsa          ← your SSH private key
  server2_key     ← key for a different server
```

These are mounted read-only into the container at `/app/ssh-keys/`.
In Settings → SAR Source, set SSH Key File to `/app/ssh-keys/<filename>`.
