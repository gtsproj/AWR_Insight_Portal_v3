# modules/oracle_awr_fetcher.py
# ============================================================
# AWR Insight Portal v3 — Direct Oracle AWR Report Generator
#
# Connects to Oracle via sqlplus, queries DBA_HIST_SNAPSHOT
# for snap IDs on a given date, then calls awrrpti.sql for
# each consecutive snap pair to generate AWR HTML reports.
#
# Reports are saved to: awr_reports\<dbname>\<filename>.html
# AWRWatcher then picks them up and queues for parsing.
#
# Prerequisites:
#   - Oracle Administrator Client installed on portal server
#     (provides sqlplus.exe and awrrpti.sql in ORACLE_HOME\rdbms\admin\)
#   - DB user with minimal privileges (see below)
#   - Network access from portal server to Oracle DB on port 1521
#
# Minimum Oracle privileges required:
#   GRANT CONNECT TO awrportal;
#   GRANT SELECT ON DBA_HIST_SNAPSHOT TO awrportal;
#   GRANT SELECT ON DBA_HIST_DATABASE_INSTANCE TO awrportal;
#   GRANT EXECUTE ON DBMS_WORKLOAD_REPOSITORY TO awrportal;
#   -- AWR report generation (awrrpti.sql) requires:
#   GRANT SELECT ANY DICTIONARY TO awrportal;
#   -- OR grant individual DBA_HIST_ views for tighter security
# ============================================================

import os
import sys
import subprocess
import logging
import base64
import tempfile
import re
from datetime import datetime, date, timedelta
from pathlib import Path
from typing import Optional

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))

logger = logging.getLogger('oracle_awr_fetcher')

# ── Password obfuscation (base64 — not encryption, just obfuscation) ─────────
def _encode_password(plain: str) -> str:
    return base64.b64encode(plain.encode('utf-8')).decode('utf-8')

def _decode_password(encoded: str) -> str:
    try:
        return base64.b64decode(encoded.encode('utf-8')).decode('utf-8')
    except Exception:
        return encoded  # return as-is if not base64


# ── Database connection helpers ───────────────────────────────────────────────
def _get_pg_connection():
    from db import get_db_connection
    return get_db_connection()


def get_all_connections() -> list[dict]:
    """Return all oracle connections from awr_oracle_connections."""
    conn = _get_pg_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, db_name, display_name, host, port, service_name,
                       username, sqlplus_path, oracle_home, snap_interval_hrs,
                       enabled, last_run_at, last_snap_id, added_at, added_by
                FROM awr_oracle_connections
                ORDER BY db_name
            """)
            cols = [d[0] for d in cur.description]
            return [dict(zip(cols, row)) for row in cur.fetchall()]
    finally:
        conn.close()


def get_connection_by_id(conn_id: int) -> Optional[dict]:
    """Return one connection including the encoded password."""
    conn = _get_pg_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, db_name, display_name, host, port, service_name,
                       username, password_enc, sqlplus_path, oracle_home,
                       snap_interval_hrs, enabled, last_run_at, last_snap_id
                FROM awr_oracle_connections
                WHERE id = %s
            """, (conn_id,))
            row = cur.fetchone()
            if not row:
                return None
            cols = [d[0] for d in cur.description]
            d = dict(zip(cols, row))
            d['password'] = _decode_password(d['password_enc'])
            return d
    finally:
        conn.close()


def save_connection(data: dict, added_by: str = 'admin') -> dict:
    """Insert or update an oracle connection. Returns {ok, id, error}."""
    db_name      = (data.get('db_name') or '').strip().upper()
    display_name = (data.get('display_name') or db_name).strip()
    host         = (data.get('host') or '').strip()
    port         = int(data.get('port') or 1521)
    service_name = (data.get('service_name') or '').strip()
    username     = (data.get('username') or '').strip()
    password     = (data.get('password') or '').strip()
    sqlplus_path = (data.get('sqlplus_path') or 'sqlplus').strip()
    oracle_home  = (data.get('oracle_home') or '').strip()
    snap_interval_hrs = int(data.get('snap_interval_hrs') or 1)
    enabled      = bool(data.get('enabled', True))

    if not db_name:
        return {'ok': False, 'error': 'db_name is required'}
    if not host:
        return {'ok': False, 'error': 'host is required'}
    if not service_name:
        return {'ok': False, 'error': 'service_name is required'}
    if not username:
        return {'ok': False, 'error': 'username is required'}

    # Only encode password if a new one was supplied
    if password:
        password_enc = _encode_password(password)
    else:
        # Check if row already exists — keep existing password
        conn = _get_pg_connection()
        try:
            with conn.cursor() as cur:
                cur.execute('SELECT password_enc FROM awr_oracle_connections WHERE db_name=%s',
                            (db_name,))
                row = cur.fetchone()
                password_enc = row[0] if row else _encode_password('')
        finally:
            conn.close()

    conn = _get_pg_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO awr_oracle_connections
                    (db_name, display_name, host, port, service_name, username,
                     password_enc, sqlplus_path, oracle_home, snap_interval_hrs,
                     enabled, added_by)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (db_name) DO UPDATE SET
                    display_name       = EXCLUDED.display_name,
                    host               = EXCLUDED.host,
                    port               = EXCLUDED.port,
                    service_name       = EXCLUDED.service_name,
                    username           = EXCLUDED.username,
                    password_enc       = CASE
                        WHEN EXCLUDED.password_enc != '' THEN EXCLUDED.password_enc
                        ELSE awr_oracle_connections.password_enc END,
                    sqlplus_path       = EXCLUDED.sqlplus_path,
                    oracle_home        = EXCLUDED.oracle_home,
                    snap_interval_hrs  = EXCLUDED.snap_interval_hrs,
                    enabled            = EXCLUDED.enabled,
                    added_by           = EXCLUDED.added_by
                RETURNING id
            """, (db_name, display_name, host, port, service_name, username,
                  password_enc, sqlplus_path, oracle_home, snap_interval_hrs,
                  enabled, added_by))
            new_id = cur.fetchone()[0]
        conn.commit()
        return {'ok': True, 'id': new_id}
    except Exception as e:
        logger.error(f'save_connection failed: {e}')
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def delete_connection(conn_id: int) -> dict:
    conn = _get_pg_connection()
    try:
        with conn.cursor() as cur:
            cur.execute('DELETE FROM awr_oracle_connections WHERE id=%s', (conn_id,))
        conn.commit()
        return {'ok': True}
    except Exception as e:
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


# ── sqlplus runner ────────────────────────────────────────────────────────────
def _run_sqlplus(sqlplus_path: str, connect_str: str,
                 sql_script: str, timeout: int = 120) -> tuple[int, str, str]:
    """
    Run a SQL script via sqlplus. Returns (returncode, stdout, stderr).
    sql_script is written to a temp file — avoids shell injection.
    """
    with tempfile.NamedTemporaryFile(
        mode='w', suffix='.sql', delete=False, encoding='utf-8'
    ) as f:
        f.write(sql_script)
        tmp_path = f.name

    try:
        result = subprocess.run(
            [sqlplus_path, '-S', connect_str, '@' + tmp_path],
            capture_output=True, text=True, timeout=timeout,
            creationflags=0x08000000 if os.name == 'nt' else 0  # CREATE_NO_WINDOW
        )
        return result.returncode, result.stdout, result.stderr
    except FileNotFoundError:
        return -1, '', f'sqlplus not found at: {sqlplus_path}'
    except subprocess.TimeoutExpired:
        return -2, '', f'sqlplus timed out after {timeout}s'
    except Exception as e:
        return -3, '', str(e)
    finally:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass


# ── Snap ID discovery ─────────────────────────────────────────────────────────
def get_snaps_for_date(conn_cfg: dict, snap_date: date) -> list[dict]:
    """
    Query DBA_HIST_SNAPSHOT for all snaps on snap_date from 00:00 onwards.
    Returns list of {snap_id, begin_interval_time, end_interval_time, dbid, instance_number}.
    Ordered by snap_id ASC.
    """
    connect_str = (
        f"{conn_cfg['username']}/{_decode_password(conn_cfg['password_enc'])}"
        f"@{conn_cfg['host']}:{conn_cfg['port']}/{conn_cfg['service_name']}"
    )
    date_str = snap_date.strftime('%Y-%m-%d')

    sql = f"""
SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SET LINESIZE 200
SET TRIMSPOOL ON
SELECT snap_id
     ||'|'||TO_CHAR(begin_interval_time,'YYYY-MM-DD HH24:MI:SS')
     ||'|'||TO_CHAR(end_interval_time,'YYYY-MM-DD HH24:MI:SS')
     ||'|'||dbid
     ||'|'||instance_number
FROM   DBA_HIST_SNAPSHOT
WHERE  TRUNC(begin_interval_time) = DATE '{date_str}'
ORDER  BY snap_id;
EXIT;
"""
    rc, stdout, stderr = _run_sqlplus(conn_cfg.get('sqlplus_path', 'sqlplus'),
                                      connect_str, sql)
    if rc != 0:
        logger.error(f"get_snaps_for_date failed rc={rc} err={stderr[:200]}")
        return []

    snaps = []
    for line in stdout.strip().splitlines():
        line = line.strip()
        if not line or '|' not in line:
            continue
        parts = line.split('|')
        if len(parts) < 5:
            continue
        try:
            snaps.append({
                'snap_id':             int(parts[0]),
                'begin_interval_time': parts[1],
                'end_interval_time':   parts[2],
                'dbid':                int(parts[3]),
                'instance_number':     int(parts[4]),
            })
        except (ValueError, IndexError):
            continue

    logger.info(f"Found {len(snaps)} snaps on {date_str} for {conn_cfg['db_name']}")
    return snaps


# ── AWR report generation ─────────────────────────────────────────────────────
def generate_awr_report(conn_cfg: dict,
                        begin_snap: int, end_snap: int,
                        dbid: int, instance_number: int,
                        output_dir: str) -> dict:
    """
    Generate one AWR HTML report using awrrpti.sql (bundled with Oracle client).
    Saves to: output_dir/<dbname>/<dbname>_<begin>_<end>.html
    Returns {ok, path, error}.
    """
    db_name      = conn_cfg['db_name']
    oracle_home  = conn_cfg.get('oracle_home', '').strip()
    sqlplus_path = conn_cfg.get('sqlplus_path', 'sqlplus')

    # Locate awrrpti.sql
    if oracle_home:
        awrrpti = os.path.join(oracle_home, 'rdbms', 'admin', 'awrrpti.sql')
    else:
        # Try to find via sqlplus location
        sqlplus_dir = os.path.dirname(sqlplus_path) if os.path.isabs(sqlplus_path) else ''
        if sqlplus_dir:
            oracle_home_guess = os.path.abspath(os.path.join(sqlplus_dir, '..'))
            awrrpti = os.path.join(oracle_home_guess, 'rdbms', 'admin', 'awrrpti.sql')
        else:
            awrrpti = 'awrrpti.sql'  # hope it's in PATH

    if not os.path.exists(awrrpti) and awrrpti != 'awrrpti.sql':
        logger.warning(f'awrrpti.sql not found at {awrrpti} — trying awrrpt.sql')
        awrrpti = awrrpti.replace('awrrpti.sql', 'awrrpt.sql')

    # Output file
    out_subdir = os.path.join(output_dir, db_name)
    os.makedirs(out_subdir, exist_ok=True)
    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    out_filename = f'awrrpt_{db_name}_{begin_snap}_{end_snap}_{ts}.html'
    out_path = os.path.join(out_subdir, out_filename)

    connect_str = (
        f"{conn_cfg['username']}/{_decode_password(conn_cfg['password_enc'])}"
        f"@{conn_cfg['host']}:{conn_cfg['port']}/{conn_cfg['service_name']}"
    )

    # awrrpti.sql inputs (in order):
    #   1. DBID
    #   2. Instance number
    #   3. Number of days (blank = list all)
    #   4. Begin snap ID
    #   5. End snap ID
    #   6. Report type: html
    #   7. Report name (output file path)
    sql = f"""
SET FEEDBACK OFF
SET VERIFY OFF
@{awrrpti}
{dbid}
{instance_number}

{begin_snap}
{end_snap}
html
{out_path}
EXIT;
"""

    logger.info(f'Generating AWR: {db_name} snaps {begin_snap}→{end_snap} → {out_filename}')
    rc, stdout, stderr = _run_sqlplus(sqlplus_path, connect_str, sql, timeout=300)

    if rc != 0:
        err = stderr[:300] or stdout[:300]
        logger.error(f'AWR gen failed rc={rc}: {err}')
        return {'ok': False, 'path': None, 'error': err}

    if not os.path.exists(out_path) or os.path.getsize(out_path) < 1000:
        # sqlplus returned 0 but file is missing or tiny — check stdout for error
        err = f'Output file not created or too small. sqlplus output: {stdout[:200]}'
        logger.error(err)
        return {'ok': False, 'path': None, 'error': err}

    logger.info(f'AWR report generated: {out_path} ({os.path.getsize(out_path):,} bytes)')
    return {'ok': True, 'path': out_path, 'error': None}


# ── Test connection ────────────────────────────────────────────────────────────
def test_connection(conn_cfg: dict) -> dict:
    """
    Test Oracle connectivity. Returns {ok, message, snaps_available}.
    """
    connect_str = (
        f"{conn_cfg['username']}/{_decode_password(conn_cfg.get('password_enc',''))}"
        f"@{conn_cfg['host']}:{conn_cfg['port']}/{conn_cfg['service_name']}"
    )
    # Simple connectivity test
    sql = """
SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SELECT 'CONN_OK|'||SYS_CONTEXT('USERENV','DB_NAME')||'|'||USER FROM DUAL;
SELECT COUNT(*) FROM DBA_HIST_SNAPSHOT WHERE ROWNUM <= 1;
EXIT;
"""
    rc, stdout, stderr = _run_sqlplus(
        conn_cfg.get('sqlplus_path', 'sqlplus'), connect_str, sql, timeout=30
    )
    if rc != 0:
        return {'ok': False,
                'message': f'Connection failed: {(stderr or stdout)[:200]}',
                'snaps_available': False}

    if 'CONN_OK' not in stdout:
        return {'ok': False,
                'message': f'Unexpected response: {stdout[:200]}',
                'snaps_available': False}

    # Parse db name from response
    m = re.search(r'CONN_OK\|(\w+)\|(\w+)', stdout)
    db_name = m.group(1) if m else '?'
    user    = m.group(2) if m else '?'

    # Check if DBA_HIST_SNAPSHOT is accessible
    snaps_ok = 'ORA-' not in stdout and rc == 0

    return {
        'ok': True,
        'message': f'Connected successfully to {db_name} as {user}',
        'snaps_available': snaps_ok
    }


# ── Main fetch workflow ────────────────────────────────────────────────────────
def fetch_awrs_for_date(conn_id: int, snap_date: date,
                        awr_reports_dir: str,
                        begin_snap_override: int = None) -> dict:
    """
    Full workflow for one Oracle DB:
      1. Get connection config
      2. Query snaps for snap_date
      3. Generate AWR report for each consecutive snap pair
      4. Return summary

    begin_snap_override: if set, only generate snaps from this snap ID onwards.
    """
    cfg = get_connection_by_id(conn_id)
    if not cfg:
        return {'ok': False, 'error': f'Connection {conn_id} not found', 'reports': []}

    if not cfg.get('enabled'):
        return {'ok': False, 'error': 'Connection is disabled', 'reports': []}

    db_name = cfg['db_name']
    logger.info(f'Fetching AWRs for {db_name} on {snap_date}')

    # Get snaps
    snaps = get_snaps_for_date(cfg, snap_date)
    if len(snaps) < 2:
        return {
            'ok': True,
            'db_name': db_name,
            'error': None,
            'message': f'Only {len(snaps)} snap(s) found for {snap_date} — need at least 2',
            'reports': []
        }

    # Filter from begin_snap_override if supplied
    if begin_snap_override:
        snaps = [s for s in snaps if s['snap_id'] >= begin_snap_override]
        if len(snaps) < 2:
            return {
                'ok': True,
                'db_name': db_name,
                'error': None,
                'message': f'No new snap pairs after snap {begin_snap_override}',
                'reports': []
            }

    reports = []
    last_ok_snap = None

    # Generate one report per consecutive snap pair
    for i in range(len(snaps) - 1):
        begin = snaps[i]
        end   = snaps[i + 1]
        result = generate_awr_report(
            cfg,
            begin['snap_id'], end['snap_id'],
            begin['dbid'], begin['instance_number'],
            awr_reports_dir
        )
        reports.append({
            'begin_snap': begin['snap_id'],
            'end_snap':   end['snap_id'],
            'begin_time': begin['begin_interval_time'],
            'end_time':   end['end_interval_time'],
            'ok':         result['ok'],
            'path':       result.get('path'),
            'error':      result.get('error'),
        })
        if result['ok']:
            last_ok_snap = end['snap_id']

    # Update last_run_at and last_snap_id
    if last_ok_snap:
        pg = _get_pg_connection()
        try:
            with pg.cursor() as cur:
                cur.execute("""
                    UPDATE awr_oracle_connections
                    SET last_run_at = NOW(), last_snap_id = %s
                    WHERE id = %s
                """, (last_ok_snap, conn_id))
            pg.commit()
        finally:
            pg.close()

    ok_count  = sum(1 for r in reports if r['ok'])
    err_count = len(reports) - ok_count
    logger.info(f'{db_name}: {ok_count} reports generated, {err_count} errors')

    return {
        'ok': True,
        'db_name': db_name,
        'snap_date': str(snap_date),
        'reports_generated': ok_count,
        'errors': err_count,
        'reports': reports,
        'error': None
    }


def fetch_awrs_all_dbs(snap_date: date, awr_reports_dir: str) -> list[dict]:
    """Run fetch_awrs_for_date for ALL enabled oracle connections."""
    connections = get_all_connections()
    enabled     = [c for c in connections if c.get('enabled')]
    results     = []
    for c in enabled:
        try:
            result = fetch_awrs_for_date(c['id'], snap_date, awr_reports_dir)
            results.append(result)
        except Exception as e:
            logger.error(f"fetch_awrs_all_dbs: error for {c['db_name']}: {e}")
            results.append({'ok': False, 'db_name': c['db_name'], 'error': str(e)})
    return results
