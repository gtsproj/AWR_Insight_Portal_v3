# ============================================================
# DAR Portal v3 — Dockerfile
# Database Analysis and Recommendations Portal
# Avekshaa Technologies
#
# ── PLATFORM COMPATIBILITY ───────────────────────────────────
# This is a LINUX container image (python:3.13-slim = Debian).
# It runs on:
#   ✅ Windows 10/11 with Docker Desktop (WSL2 backend)
#   ✅ Windows Server 2019/2022 with Docker Desktop (WSL2)
#   ✅ Any Linux server with Docker Engine
#   ❌ Windows Containers mode (requires Windows base image)
#
# Docker Desktop uses WSL2 (a lightweight Linux VM) to run
# Linux containers on Windows — the containers are unaware
# of the Windows host. No Linux knowledge required on the
# Windows side; Docker Desktop handles everything.
#
# Build:  docker build -t dar-portal:v3 .
# Run:    docker-compose up -d  (see docker-compose.yml)
# ============================================================

FROM python:3.13-slim

LABEL maintainer="Avekshaa Technologies" \
      description="DAR Portal v3 — Database Analysis and Recommendations" \
      version="3.0"

# ── System dependencies ───────────────────────────────────────
# postgresql-client : provides psql for schema installation
#                     and pg_isready for health checks
# libpq-dev + gcc   : required to compile psycopg2
# openssh-client    : SSH client for SAR delta extraction (paramiko)
# curl              : portal /health endpoint health check
RUN apt-get update && apt-get install -y --no-install-recommends \
        postgresql-client \
        libpq-dev \
        gcc \
        openssh-client \
        curl \
    && rm -rf /var/lib/apt/lists/*

# ── Application directory ─────────────────────────────────────
WORKDIR /app

# ── Python dependencies ───────────────────────────────────────
# Copied first for Docker layer caching — only rebuilds when
# requirements.txt changes, not on every code change
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
 && pip install --no-cache-dir "oracledb>=2.0" paramiko

# ── Application code ──────────────────────────────────────────
COPY . .

# ── Runtime directories ───────────────────────────────────────
# Created inside the container; mapped to Docker volumes
# in docker-compose.yml for persistence across restarts
RUN mkdir -p \
        awr_reports \
        archive \
        sar_drop \
        sar_archive \
        queues \
        sar_queues \
        logs \
        logs/services

# ── Entrypoint ────────────────────────────────────────────────
RUN chmod +x docker/entrypoint.sh
ENTRYPOINT ["docker/entrypoint.sh"]

# ── Port ──────────────────────────────────────────────────────
EXPOSE 8000

# ── Health check ──────────────────────────────────────────────
# Checks the /health endpoint every 30s
# start_period=90s gives time for schema installation on first run
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -sf http://localhost:8000/health || exit 1
