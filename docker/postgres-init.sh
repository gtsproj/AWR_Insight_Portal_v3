#!/bin/bash
# ============================================================
# PostgreSQL Initialization Script
# Runs ONCE on first container start (when data volume is empty)
# Creates the DAR_PORTAL_USER role.
# Schema tables are created by entrypoint.sh using install_fresh.sql
# ============================================================
set -e

echo "PostgreSQL init: creating DAR_PORTAL_USER role..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" << 'EOSQL'
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'DAR_PORTAL_USER') THEN
        CREATE ROLE DAR_PORTAL_USER LOGIN PASSWORD 'ChangeThisPassword123';
        GRANT CONNECT ON DATABASE postgres TO DAR_PORTAL_USER;
        GRANT USAGE   ON SCHEMA public     TO DAR_PORTAL_USER;
        GRANT CREATE  ON SCHEMA public     TO DAR_PORTAL_USER;
        RAISE NOTICE 'DAR_PORTAL_USER created';
    ELSE
        RAISE NOTICE 'DAR_PORTAL_USER already exists';
    END IF;
END $$;
EOSQL

echo "PostgreSQL init: done."
