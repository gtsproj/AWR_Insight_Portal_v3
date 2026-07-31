#!/bin/bash
# ============================================================
# DAR Portal v3 — Container Entrypoint
# ============================================================
# Runs inside the Linux container on every start.
# On Windows: Docker Desktop runs this inside WSL2 Linux VM.
#
# Sequence:
#   1. Wait for PostgreSQL (pg_isready — reliable, no netcat needed)
#   2. Run schema install_fresh.sql  (first start only)
#   3. Update settings.yaml from Docker environment variables
#   4. Import Grafana dashboards (first start only)
#   5. Start queue_processor, awr_watcher, sar_watcher (background)
#   6. Start uvicorn portal web server (foreground — keeps container alive)
# ============================================================

set -e

echo "============================================================"
echo " DAR Portal v3 — Starting"
echo " $(date)"
echo "============================================================"

# Defaults (can be overridden by docker-compose.yml environment)
DB_HOST="${DAR_DB_HOST:-dar-postgres}"
DB_PORT="${DAR_DB_PORT:-5432}"
DB_NAME="${DAR_DB_NAME:-postgres}"
DB_USER="${DAR_DB_USER:-postgres}"
export PGPASSWORD="${DAR_DB_PASSWORD:-}"


# ── Step 1: Wait for PostgreSQL ───────────────────────────────
# Uses pg_isready (from postgresql-client package) — more reliable
# than nc/netcat and directly tests the PostgreSQL protocol
echo "Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."
until pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -q; do
    echo "  PostgreSQL not ready — retrying in 3 seconds..."
    sleep 3
done
echo "  PostgreSQL is ready."


# ── Step 2: Schema installation (first run only) ──────────────
# portal_config table presence = schema already installed
SCHEMA_COUNT=$(psql -h "${DB_HOST}" -p "${DB_PORT}" \
    -U "${DB_USER}" -d "${DB_NAME}" \
    -tAc "SELECT COUNT(*) FROM information_schema.tables
          WHERE table_schema='public'
          AND table_name='portal_config';" 2>/dev/null || echo "0")

if [ "${SCHEMA_COUNT}" = "0" ]; then
    echo "First run — running schema installation..."
    echo "  (Installing 80 tables, 88 indexes, 1918 wait events...)"
    psql -h "${DB_HOST}" -p "${DB_PORT}" \
         -U "${DB_USER}" -d "${DB_NAME}" \
         -v ON_ERROR_STOP=0 \
         -f schema/install_fresh.sql \
         2>&1 | grep -v "^NOTICE\|^$" || true
    echo "  Schema installation complete."
else
    echo "  Schema already installed (${SCHEMA_COUNT} — skipping)."
fi


# ── Step 3: Configure settings.yaml from environment ─────────
echo "Updating settings.yaml from Docker environment..."
python3 << 'PYEOF'
import yaml, os, sys

cfg_path = 'config/settings.yaml'
try:
    with open(cfg_path) as f:
        cfg = yaml.safe_load(f) or {}
except FileNotFoundError:
    cfg = {}

e = os.environ
cfg.setdefault('database', {})
cfg['database']['host']     = e.get('DAR_DB_HOST',     'dar-postgres')
cfg['database']['port']     = int(e.get('DAR_DB_PORT', '5432'))
cfg['database']['dbname']   = e.get('DAR_DB_NAME',     'postgres')
cfg['database']['user']     = e.get('DAR_DB_USER',     'postgres')
cfg['database']['password'] = e.get('DAR_DB_PASSWORD', '')

cfg.setdefault('grafana', {})
cfg['grafana']['base_url']       = e.get('DAR_GRAFANA_URL',  'http://dar-grafana:3000')
cfg['grafana']['admin_user']     = e.get('DAR_GRAFANA_USER', 'admin')
cfg['grafana']['admin_password'] = e.get('DAR_GRAFANA_PASS', 'admin')

cfg.setdefault('portal', {})
cfg['portal']['base_url'] = e.get('DAR_PORTAL_URL', 'http://localhost:8000')

cfg.setdefault('paths', {})
cfg['paths']['watch_directory']       = 'awr_reports'
cfg['paths']['archive_directory']     = 'archive'
cfg['paths']['sar_drop_directory']    = 'sar_drop'
cfg['paths']['sar_archive_directory'] = 'sar_archive'
cfg['paths']['queues_directory']      = 'queues'
cfg['paths']['sar_queues_directory']  = 'sar_queues'

with open(cfg_path, 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False, allow_unicode=True)
print('  settings.yaml updated.')
PYEOF


# ── Step 4: Import Grafana dashboards (first run only) ────────
# Flag file prevents re-import on every restart
IMPORT_FLAG="/app/.grafana_imported"
if [ ! -f "${IMPORT_FLAG}" ]; then
    echo "Importing Grafana dashboards (first run)..."
    # Wait for Grafana to be ready
    GRAFANA_URL="${DAR_GRAFANA_URL:-http://dar-grafana:3000}"
    RETRIES=20
    until curl -sf "${GRAFANA_URL}/api/health" > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
        echo "  Waiting for Grafana... ($RETRIES retries left)"
        sleep 5
        RETRIES=$((RETRIES - 1))
    done
    if curl -sf "${GRAFANA_URL}/api/health" > /dev/null 2>&1; then
        python3 bulk_import.py 2>&1 | tail -3 && \
        touch "${IMPORT_FLAG}" && \
        echo "  Dashboards imported successfully."
    else
        echo "  Grafana not reachable — dashboards not imported. Run py bulk_import.py manually."
    fi
else
    echo "  Grafana dashboards already imported — skipping."
fi


# ── Step 5: Start background services ─────────────────────────
echo "Starting background services..."

python3 queue_processor.py --daemon --workers 4 --sar-workers 2 \
    >> logs/queue_processor.log 2>&1 &
echo "  Queue processor   PID=$!"

python3 awr_watcher.py >> logs/awr_watcher.log 2>&1 &
echo "  AWR watcher       PID=$!"

python3 sar_watcher/sar_watcher.py >> logs/sar_watcher.log 2>&1 &
echo "  SAR watcher       PID=$!"


# ── Step 6: Start portal web server (foreground) ──────────────
echo "============================================================"
echo " Starting DAR Portal on http://0.0.0.0:8000"
echo " Open: http://localhost:8000   (or http://<server>:8000)"
echo " Login: admin / Admin@123"
echo "============================================================"

exec python3 -m uvicorn portal.app:app \
    --host 0.0.0.0 \
    --port 8000 \
    --workers 1 \
    --log-level info
