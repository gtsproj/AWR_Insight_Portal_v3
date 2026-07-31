# ============================================================
# DAR Portal v3 — Dockerfile
# Database Analysis and Recommendations Portal
# Avekshaa Technologies
# ============================================================
#
# Builds the DAR Portal Python application image.
# Uses Python 3.13 slim base for minimal image size.
#
# Build:  docker build -t dar-portal:v3 .
# Run:    docker-compose up -d  (see docker-compose.yml)
# ============================================================

FROM python:3.13-slim

LABEL maintainer="Avekshaa Technologies" \
      description="DAR Portal v3 — Database Analysis and Recommendations" \
      version="3.0"

# ── System dependencies ───────────────────────────────────────
# libpq-dev: PostgreSQL client library (for psycopg2)
# openssh-client: SSH client for SAR delta extraction (paramiko)
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq-dev \
        gcc \
        openssh-client \
        curl \
        netcat-traditional \
    && rm -rf /var/lib/apt/lists/*

# ── Application directory ─────────────────────────────────────
WORKDIR /app

# ── Python dependencies ───────────────────────────────────────
# Copy requirements first for Docker layer caching —
# rebuilds only when requirements change, not on every code change
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
 && pip install --no-cache-dir oracledb>=2.0 paramiko

# ── Application code ──────────────────────────────────────────
COPY . .

# ── Runtime directories ───────────────────────────────────────
# Created inside the container; mapped to Docker volumes via
# docker-compose.yml for persistence across container restarts
RUN mkdir -p \
        awr_reports \
        archive \
        sar_drop \
        sar_archive \
        queues \
        sar_queues \
        logs \
        logs/services

# ── Entrypoint script ─────────────────────────────────────────
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ── Port ──────────────────────────────────────────────────────
EXPOSE 8000

# ── Health check ──────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
