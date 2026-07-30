-- ============================================================
-- seed_data.sql
-- AWR Insight Portal v3 — Complete Seed Data
--
-- Run AFTER the full schema:
--   psql -U postgres -d postgres -f schema\awr_portal_full_schema_extracted_from_database.sql
--   psql -U postgres -d postgres -f schema\awr_oracle_connections.sql
--   psql -U postgres -d postgres -f schema\sar_ssh_connections.sql
--   psql -U postgres -d postgres -f schema\seed_data.sql
--   psql -U postgres -d postgres -f schema\wait_event_master_update.sql
--
-- Seeds:
--   1. portal_config  — 30 default configuration keys
--   2. portal_users   — default admin (admin / Admin@123)
--
-- Safe to re-run: ON CONFLICT DO NOTHING on all rows
-- ============================================================

\echo '============================================================'
\echo 'AWR Insight Portal v3 — Seeding default data'
\echo '============================================================'

-- ── 1. portal_config ─────────────────────────────────────────────────
\echo 'Seeding portal_config...'

INSERT INTO portal_config (key, value, section, updated_by, updated_at) VALUES
-- AI
('ai_mode',              'rules',                  'ai',        'seed', NOW()),
('ai_local_url',         'http://localhost:11434',  'ai',        'seed', NOW()),
('ai_local_model',       'llama3',                 'ai',        'seed', NOW()),
('ai_cloud_provider',    'anthropic',              'ai',        'seed', NOW()),
('ai_cloud_api_key',     '',                       'ai',        'seed', NOW()),
('ai_cloud_model',       'claude-sonnet-4-6',      'ai',        'seed', NOW()),
('ai_monthly_limit',     '1000',                   'ai',        'seed', NOW()),
-- Anomaly
('anomaly_z_threshold',  '2.0',                    'anomaly',   'seed', NOW()),
('anomaly_baseline_days','30',                     'anomaly',   'seed', NOW()),
('anomaly_min_samples',  '5',                      'anomaly',   'seed', NOW()),
-- AWR Source
('awr_source_type',      'local',                  'awr_source','seed', NOW()),
('awr_local_path',       'awr_reports',            'awr_source','seed', NOW()),
('awr_network_path',     '',                       'awr_source','seed', NOW()),
('awr_db_host',          '',                       'awr_source','seed', NOW()),
('awr_db_port',          '1521',                   'awr_source','seed', NOW()),
('awr_db_service',       '',                       'awr_source','seed', NOW()),
('awr_db_user',          '',                       'awr_source','seed', NOW()),
('awr_db_password',      '',                       'awr_source','seed', NOW()),
-- SAR Source
('sar_source_type',      'local',                  'sar_source','seed', NOW()),
('sar_tz_offset',        'Asia/Kolkata',           'sar_source','seed', NOW()),
('sar_local_path',       'sar_drop',               'sar_source','seed', NOW()),
-- License
('license_key',          '',                       'license',   'seed', NOW()),
('license_customer',     '',                       'license',   'seed', NOW()),
('license_db_count',     '0',                      'license',   'seed', NOW()),
('license_sar_count',    '0',                      'license',   'seed', NOW()),
('license_expiry',       '',                       'license',   'seed', NOW()),
('license_mac_override', '',                       'license',   'seed', NOW()),
-- Access
('portal_login_required','false',                  'access',    'seed', NOW()),
('portal_url',           'http://localhost:8000',  'access',    'seed', NOW()),
('grafana_url',          'http://localhost:3000',  'access',    'seed', NOW()),
('session_timeout_mins', '480',                    'access',    'seed', NOW()),
('admin_reset_pin',      '1234',                   'access',    'seed', NOW()),
('metadata_refresh_days','30',                     'access',    'seed', NOW())
ON CONFLICT (key) DO NOTHING;

\echo '  portal_config: OK'


-- ── 2. portal_users — default admin ──────────────────────────────────
-- Password: Admin@123  (bcrypt cost 12)
-- Change immediately after first login:
--   Settings → Users → Change Password
\echo 'Seeding portal_users (admin / Admin@123)...'

INSERT INTO portal_users
    (username, full_name, password_hash, role, is_active, created_at, updated_at)
VALUES
    ('admin', 'Administrator',
     '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TiGniMDPbFMnb9h1TCcB8V2/.SvS',
     'admin', TRUE, NOW(), NOW())
ON CONFLICT (username) DO NOTHING;

\echo '  portal_users: OK'


\echo ''
\echo 'Seed complete. Run next:'
\echo '  psql -U postgres -d postgres -f schema\wait_event_master_update.sql'
\echo '  py bulk_import.py'
\echo '  Open http://localhost:8000  login: admin / Admin@123'
\echo '============================================================'
