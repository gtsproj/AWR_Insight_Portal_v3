#!/bin/bash
# ============================================================
# DAR Portal v3 — Container Entrypoint
# ============================================================
# Runs on every container start:
#   1. Wait for PostgreSQL to be ready
#   2. Run schema installation (skipped if already done)
#   3. Start the portal queue processor (background)
#   4. Start the AWR file watcher (background)
#   5. Start the SAR file watcher (background)
#   6. Start the portal web server (foreground)
# ============================================================

set -e

echo "============================================================"
echo " DAR Portal v3 — Starting"
echo " $(date)"
echo "============================================================"

# ── Wait for PostgreSQL ───────────────────────────────────────
echo "Waiting for PostgreSQL at ${DAR_DB_HOST}:${DAR_DB_PORT}..."
until nc -z "${DAR_DB_HOST:-dar-postgres}" "${DAR_DB_PORT:-5432}"; do
    echo "  PostgreSQL not ready — retrying in 2 seconds..."
    sleep 2
done
echo "  PostgreSQL is ready."

# ── Run schema installation if not already done ───────────────
# Check for portal_config table as the indicator of prior install
SCHEMA_CHECK=$(psql -h "${DAR_DB_HOST}" -p "${DAR_DB_PORT}" \
    -U "${DAR_DB_USER}" -d "${DAR_DB_NAME}" \
    -tAc "SELECT COUNT(*) FROM information_schema.tables \
          WHERE table_schema='public' AND table_name='portal_config';" 2>/dev/null || echo "0")

if [ "$SCHEMA_CHECK" = "0" ]; then
    echo "Running schema installation (first run)..."
    psql -h "${DAR_DB_HOST}" -p "${DAR_DB_PORT}" \
         -U "${DAR_DB_USER}" -d "${DAR_DB_NAME}" \
         -v ON_ERROR_STOP=0 \
         -f schema/install_fresh.sql
    echo "  Schema installation complete."
else
    echo "  Schema already installed — skipping."
fi

# ── Update settings.yaml with Docker environment values ───────
echo "Configuring settings.yaml from environment..."
python3 - << 'PYEOF'
import yaml, os

cfg_path = 'config/settings.yaml'
try:
    with open(cfg_path) as f:
        cfg = yaml.safe_load(f) or {}
except FileNotFoundError:
    cfg = {}

# Overlay from environment variables
env = os.environ
cfg.setdefault('database', {})
cfg['database']['host']     = env.get('DAR_DB_HOST',     'dar-postgres')
cfg['database']['port']     = int(env.get('DAR_DB_PORT', '5432'))
cfg['database']['dbname']   = env.get('DAR_DB_NAME',     'postgres')
cfg['database']['user']     = env.get('DAR_DB_USER',     'postgres')
cfg['database']['password'] = env.get('DAR_DB_PASSWORD', '')

cfg.setdefault('grafana', {})
cfg['grafana']['base_url']       = env.get('DAR_GRAFANA_URL',  'http://dar-grafana:3000')
cfg['grafana']['admin_user']     = env.get('DAR_GRAFANA_USER', 'admin')
cfg['grafana']['admin_password'] = env.get('DAR_GRAFANA_PASS', 'admin')

cfg.setdefault('portal', {})
cfg['portal']['base_url'] = env.get('DAR_PORTAL_URL', 'http://localhost:8000')

with open(cfg_path, 'w') as f:
    yaml.dump(cfg, f, default_flow_style=False, allow_unicode=True)
print('  settings.yaml updated from environment.')
PYEOF

# ── Import Grafana dashboards ─────────────────────────────────
echo "Importing Grafana dashboards..."
sleep 5   # Give Grafana a moment to be fully ready
python3 bulk_import.py 2>&1 | tail -5 || echo "  Dashboard import warning (non-fatal)"

# ── Start background services ─────────────────────────────────
echo "Starting background services..."

# Queue processor — parses AWR and SAR files
python3 queue_processor.py --daemon --workers 4 --sar-workers 2 \
    >> logs/queue_processor.log 2>&1 &
echo "  Queue processor started (PID $!)"

# AWR file watcher — monitors awr_reports/ folder
python3 awr_watcher.py >> logs/awr_watcher.log 2>&1 &
echo "  AWR watcher started (PID $!)"

# SAR file watcher — monitors sar_drop/ folder
python3 sar_watcher/sar_watcher.py >> logs/sar_watcher.log 2>&1 &
echo "  SAR watcher started (PID $!)"

echo "============================================================"
echo " Starting DAR Portal web server on port 8000"
echo "============================================================"

# ── Start portal (foreground — container stays alive) ─────────
exec python3 -m uvicorn portal.app:app \
    --host 0.0.0.0 \
    --port 8000 \
    --workers 1 \
    --log-level info
