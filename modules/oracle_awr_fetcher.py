# modules/oracle_awr_fetcher.py
# ============================================================
# AWR Insight Portal v3 — Direct Oracle AWR Report Generator
#
# Uses the oracledb Python package (thin mode — no Oracle Client
# installation required on the portal server) to:
#   1. Connect directly to Oracle databases
#   2. Query DBA_HIST_SNAPSHOT for available snap IDs
#   3. Call DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML to generate
#      AWR HTML reports as Python strings
#   4. Save reports to awr_reports\<DBNAME>\<filename>.html
#   5. AWRWatcher picks them up and queues for parsing
#
# Install:  pip install oracledb>=2.0
#
# Minimum Oracle privileges for the portal user (no DBA needed):
#   GRANT CREATE SESSION TO awrportal;
#   GRANT SELECT_CATALOG_ROLE TO awrportal;
#   GRANT EXECUTE ON SYS.DBMS_WORKLOAD_REPOSITORY TO awrportal;
#
# SELECT_CATALOG_ROLE grants read-only access to all DBA_HIST_*
# views needed by AWR_REPORT_HTML. It does NOT grant access to
# actual application data and is NOT the DBA role.
# ============================================================

import os
import sys
import logging
import base64
from datetime import datetime, date
from typing import Optional

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))

logger = logging.getLogger('oracle_awr_fetcher')


# ── Password obfuscation ──────────────────────────────────────────────────────
def _encode_password(plain: str) -> str:
    """Base64 obfuscation — not encryption, just prevents plain-text storage."""
    return base64.b64encode(plain.encode('utf-8')).decode('utf-8')

def _decode_password(encoded: str) -> str:
    try:
        return base64.b64decode(encoded.encode('utf-8')).decode('utf-8')
    except Exception:
        return encoded  # already plain text


# ── PostgreSQL helpers ────────────────────────────────────────────────────────
def _pg():
    from db import get_db_connection
    return get_db_connection()


# ── Oracle connection helper ──────────────────────────────────────────────────
def _oracle_connect(cfg: dict):
    """
    Open an oracledb thin-mode connection.
    Thin mode requires no Oracle Client on the portal server.
    Raises ImportError if oracledb is not installed.
    Raises oracledb.DatabaseError on connection failure.
    """
    try:
        import oracledb
    except ImportError:
        raise ImportError(
            "oracledb is not installed. Run: pip install oracledb>=2.0"
        )

    password = _decode_password(cfg.get('password_enc', ''))
    dsn = f"{cfg['host']}:{cfg['port']}/{cfg['service_name']}"

    return oracledb.connect(
        user=cfg['username'],
        password=password,
        dsn=dsn
        # Thin mode is the default — no Oracle Client needed
        # For thick mode (if thin fails): pass thick_mode={}
    )


# ── CRUD: awr_oracle_connections ──────────────────────────────────────────────
def get_all_connections() -> list:
    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, db_name, display_name, host, port, service_name,
                       username, snap_interval_hrs,
                       enabled, last_run_at, last_snap_id, added_at, added_by
                FROM awr_oracle_connections
                ORDER BY db_name
            """)
            cols = [d[0] for d in cur.description]
            rows = []
            for row in cur.fetchall():
                d = dict(zip(cols, row))
                # Convert datetime objects to strings for JSON serialisation
                for k in ('last_run_at', 'added_at'):
                    if d.get(k) is not None:
                        d[k] = d[k].strftime('%Y-%m-%d %H:%M:%S')
                rows.append(d)
            return rows
    finally:
        conn.close()


def get_connection_by_id(conn_id: int) -> Optional[dict]:
    """Returns connection including password_enc."""
    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, db_name, display_name, host, port, service_name,
                       username, password_enc,
                       snap_interval_hrs, enabled, last_run_at, last_snap_id
                FROM awr_oracle_connections
                WHERE id = %s
            """, (conn_id,))
            row = cur.fetchone()
            if not row:
                return None
            cols = [d[0] for d in cur.description]
            return dict(zip(cols, row))
    finally:
        conn.close()


def save_connection(data: dict, added_by: str = 'admin') -> dict:
    """Insert or update one Oracle connection. Returns {ok, id, error}."""
    db_name           = (data.get('db_name') or '').strip().upper()
    display_name      = (data.get('display_name') or db_name).strip()
    host              = (data.get('host') or '').strip()
    port              = int(data.get('port') or 1521)
    service_name      = (data.get('service_name') or '').strip()
    username          = (data.get('username') or '').strip()
    password          = (data.get('password') or '').strip()
    snap_interval_hrs = float(data.get('snap_interval_hrs') or 1)
    enabled           = bool(data.get('enabled', True))

    if not db_name:
        return {'ok': False, 'error': 'db_name is required'}
    if not host:
        return {'ok': False, 'error': 'host is required'}
    if not service_name:
        return {'ok': False, 'error': 'service_name is required'}
    if not username:
        return {'ok': False, 'error': 'username is required'}

    # Determine password to store
    if password:
        password_enc = _encode_password(password)
    else:
        # Keep existing password if row exists
        conn = _pg()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    'SELECT password_enc FROM awr_oracle_connections WHERE db_name=%s',
                    (db_name,))
                row = cur.fetchone()
                password_enc = row[0] if row else _encode_password('')
        finally:
            conn.close()

    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO awr_oracle_connections
                    (db_name, display_name, host, port, service_name, username,
                     password_enc, snap_interval_hrs, enabled, added_by)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (db_name) DO UPDATE SET
                    display_name       = EXCLUDED.display_name,
                    host               = EXCLUDED.host,
                    port               = EXCLUDED.port,
                    service_name       = EXCLUDED.service_name,
                    username           = EXCLUDED.username,
                    password_enc       = CASE
                        WHEN EXCLUDED.password_enc != ''
                        THEN EXCLUDED.password_enc
                        ELSE awr_oracle_connections.password_enc END,
                    snap_interval_hrs  = EXCLUDED.snap_interval_hrs,
                    enabled            = EXCLUDED.enabled,
                    added_by           = EXCLUDED.added_by
                RETURNING id
            """, (db_name, display_name, host, port, service_name, username,
                  password_enc, snap_interval_hrs, enabled, added_by))
            new_id = cur.fetchone()[0]
        conn.commit()
        return {'ok': True, 'id': new_id}
    except Exception as e:
        logger.error(f'save_connection: {e}')
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def delete_connection(conn_id: int) -> dict:
    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute('DELETE FROM awr_oracle_connections WHERE id=%s', (conn_id,))
        conn.commit()
        return {'ok': True}
    except Exception as e:
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


# ── Test connection ────────────────────────────────────────────────────────────
def test_connection(cfg: dict) -> dict:
    """
    Verify Oracle connectivity and required privileges.
    Returns {ok, message, db_name, oracle_version, snap_count, can_generate}.
    """
    try:
        oc = _oracle_connect(cfg)
    except ImportError as e:
        return {'ok': False, 'message': str(e), 'can_generate': False}
    except Exception as e:
        return {
            'ok': False,
            'message': f'Connection failed: {e}',
            'can_generate': False
        }

    try:
        cur = oc.cursor()

        # Basic connectivity + DB name
        cur.execute("""
            SELECT SYS_CONTEXT('USERENV','DB_NAME'),
                   SYS_CONTEXT('USERENV','SESSION_USER'),
                   VERSION
            FROM V$INSTANCE
        """)
        row = cur.fetchone()
        db_name = row[0] if row else '?'
        username = row[1] if row else '?'
        version  = row[2] if row else '?'

        # Check DBA_HIST_SNAPSHOT access
        snap_count = 0
        try:
            cur.execute('SELECT COUNT(*) FROM DBA_HIST_SNAPSHOT')
            snap_count = cur.fetchone()[0]
            hist_ok = True
        except Exception:
            hist_ok = False

        # Check DBMS_WORKLOAD_REPOSITORY execute privilege
        awr_ok = False
        try:
            cur.execute("""
                SELECT COUNT(*) FROM ALL_PROCEDURES
                WHERE OWNER = 'SYS'
                AND OBJECT_NAME = 'DBMS_WORKLOAD_REPOSITORY'
                AND PROCEDURE_NAME = 'AWR_REPORT_HTML'
            """)
            awr_ok = cur.fetchone()[0] > 0
        except Exception:
            pass

        can_generate = hist_ok and awr_ok

        if can_generate:
            msg = (f'Connected to {db_name} as {username} '
                   f'(Oracle {version}). '
                   f'{snap_count:,} snapshots available. '
                   f'AWR generation: ready.')
        else:
            missing = []
            if not hist_ok:
                missing.append('SELECT on DBA_HIST_SNAPSHOT')
            if not awr_ok:
                missing.append('EXECUTE on DBMS_WORKLOAD_REPOSITORY')
            msg = (f'Connected to {db_name} as {username}, '
                   f'but missing privileges: {", ".join(missing)}. '
                   f'Run the grant script.')

        return {
            'ok': True,
            'message': msg,
            'db_name': db_name,
            'oracle_version': version,
            'snap_count': snap_count,
            'can_generate': can_generate
        }

    except Exception as e:
        return {'ok': False, 'message': f'Test query failed: {e}',
                'can_generate': False}
    finally:
        try:
            oc.close()
        except Exception:
            pass


# ── Snap discovery ────────────────────────────────────────────────────────────
def get_snaps_for_date(cfg: dict, snap_date: date) -> dict:
    """
    Query DBA_HIST_SNAPSHOT for all snaps on snap_date.
    Returns {ok, snaps, dbid, instance_number, error}.
    snaps: list of {snap_id, begin_time, end_time}
    """
    try:
        oc = _oracle_connect(cfg)
    except Exception as e:
        return {'ok': False, 'snaps': [], 'error': str(e)}

    try:
        cur = oc.cursor()

        # Get DBID and instance number first
        cur.execute("""
            SELECT dbid, instance_number
            FROM DBA_HIST_DATABASE_INSTANCE
            WHERE ROWNUM = 1
            ORDER BY startup_time DESC
        """)
        row = cur.fetchone()
        if not row:
            return {'ok': False, 'snaps': [],
                    'error': 'Could not determine DBID from DBA_HIST_DATABASE_INSTANCE'}
        dbid, instance_number = row

        # Get snaps for the date
        cur.execute("""
            SELECT snap_id,
                   TO_CHAR(begin_interval_time, 'YYYY-MM-DD HH24:MI:SS'),
                   TO_CHAR(end_interval_time,   'YYYY-MM-DD HH24:MI:SS')
            FROM   DBA_HIST_SNAPSHOT
            WHERE  TRUNC(begin_interval_time) = TO_DATE(:snap_date, 'YYYY-MM-DD')
            AND    dbid            = :dbid
            AND    instance_number = :inst
            ORDER  BY snap_id
        """, snap_date=snap_date.strftime('%Y-%m-%d'),
             dbid=dbid, inst=instance_number)

        snaps = [
            {'snap_id': row[0], 'begin_time': row[1], 'end_time': row[2]}
            for row in cur.fetchall()
        ]

        logger.info(
            f"get_snaps_for_date: {cfg['db_name']} "
            f"{snap_date} → {len(snaps)} snaps (dbid={dbid} inst={instance_number})"
        )
        return {
            'ok': True,
            'snaps': snaps,
            'dbid': dbid,
            'instance_number': instance_number,
            'error': None
        }

    except Exception as e:
        logger.error(f"get_snaps_for_date {cfg['db_name']}: {e}")
        return {'ok': False, 'snaps': [], 'error': str(e)}
    finally:
        try:
            oc.close()
        except Exception:
            pass


# ── AWR report generation ─────────────────────────────────────────────────────
def generate_awr_report(cfg: dict,
                        dbid: int, instance_number: int,
                        begin_snap: int, end_snap: int,
                        output_dir: str) -> dict:
    """
    Generate one AWR HTML report by calling
    DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML directly via oracledb.
    No Oracle Client, no sqlplus, no awrrpti.sql needed.

    The function returns the report as a table of VARCHAR2 rows (one
    per line of HTML). We concatenate them and write to a file.

    Output: output_dir/<DBNAME>/<DBNAME>_<begin>_<end>_<ts>.html
    Returns {ok, path, error, size_bytes}.
    """
    db_name = cfg['db_name']
    out_subdir = os.path.join(output_dir, db_name)
    os.makedirs(out_subdir, exist_ok=True)
    ts = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f'awrrpt_{db_name}_{begin_snap}_{end_snap}_{ts}.html'
    out_path = os.path.join(out_subdir, filename)

    try:
        oc = _oracle_connect(cfg)
    except Exception as e:
        return {'ok': False, 'path': None, 'error': str(e), 'size_bytes': 0}

    try:
        cur = oc.cursor()

        # AWR_REPORT_HTML returns a pipelined table of VARCHAR2(80).
        # Each row is one line of the HTML report.
        # Parameters: (dbid, inst_num, begin_snap, end_snap, options)
        # options=0 is standard report.
        cur.execute("""
            SELECT output
            FROM TABLE(
                DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML(
                    :dbid,
                    :inst_num,
                    :begin_snap,
                    :end_snap,
                    0
                )
            )
        """, dbid=dbid, inst_num=instance_number,
             begin_snap=begin_snap, end_snap=end_snap)

        lines = [row[0] or '' for row in cur.fetchall()]

        if not lines:
            return {
                'ok': False, 'path': None,
                'error': 'AWR_REPORT_HTML returned no output — check snap IDs and privileges',
                'size_bytes': 0
            }

        html = '\n'.join(lines)

        # Sanity check — a real AWR report is at least ~100KB
        if len(html) < 10_000:
            # Might be an error message instead of actual HTML
            snippet = html[:500]
            logger.warning(
                f"AWR report suspiciously small ({len(html)} bytes): {snippet}")

        with open(out_path, 'w', encoding='utf-8') as f:
            f.write(html)

        size = os.path.getsize(out_path)
        logger.info(
            f"AWR report written: {filename} ({size:,} bytes) "
            f"snaps {begin_snap}→{end_snap}"
        )
        return {'ok': True, 'path': out_path, 'error': None, 'size_bytes': size}

    except Exception as e:
        logger.error(f"generate_awr_report {db_name} {begin_snap}→{end_snap}: {e}")
        return {'ok': False, 'path': None, 'error': str(e), 'size_bytes': 0}
    finally:
        try:
            oc.close()
        except Exception:
            pass


# ── Full workflow: one database, one date ─────────────────────────────────────
def fetch_awrs_for_date(conn_id: int, snap_date: date,
                        awr_reports_dir: str,
                        begin_snap_override: int = None) -> dict:
    """
    Complete workflow for one Oracle DB:
      1. Load connection config
      2. Query snaps for snap_date from 00:00 onwards
      3. Generate AWR report for each consecutive snap pair
      4. Update last_run_at and last_snap_id in awr_oracle_connections
      5. Return summary

    begin_snap_override: only process snaps >= this ID (skip already done).
    """
    cfg = get_connection_by_id(conn_id)
    if not cfg:
        return {'ok': False, 'error': f'Connection {conn_id} not found', 'reports': []}
    if not cfg.get('enabled'):
        return {'ok': False, 'error': 'Connection is disabled', 'reports': []}

    db_name = cfg['db_name']
    logger.info(f'fetch_awrs_for_date: {db_name} {snap_date}')

    # Step 1: get snaps
    snap_result = get_snaps_for_date(cfg, snap_date)
    if not snap_result['ok']:
        return {
            'ok': False, 'db_name': db_name,
            'error': snap_result['error'], 'reports': []
        }

    snaps            = snap_result['snaps']
    dbid             = snap_result['dbid']
    instance_number  = snap_result['instance_number']

    if len(snaps) < 2:
        return {
            'ok': True, 'db_name': db_name,
            'message': f'Only {len(snaps)} snap(s) found on {snap_date} — need at least 2',
            'reports': [], 'reports_generated': 0, 'errors': 0
        }

    # Step 2: apply begin_snap_override
    if begin_snap_override:
        snaps = [s for s in snaps if s['snap_id'] >= begin_snap_override]
        if len(snaps) < 2:
            return {
                'ok': True, 'db_name': db_name,
                'message': f'No new snap pairs after snap {begin_snap_override}',
                'reports': [], 'reports_generated': 0, 'errors': 0
            }

    # Step 3: generate one report per consecutive pair
    reports = []
    last_ok_snap = None

    for i in range(len(snaps) - 1):
        b = snaps[i]
        e = snaps[i + 1]
        result = generate_awr_report(
            cfg, dbid, instance_number,
            b['snap_id'], e['snap_id'],
            awr_reports_dir
        )
        reports.append({
            'begin_snap':  b['snap_id'],
            'end_snap':    e['snap_id'],
            'begin_time':  b['begin_time'],
            'end_time':    e['end_time'],
            'ok':          result['ok'],
            'path':        result.get('path'),
            'size_bytes':  result.get('size_bytes', 0),
            'error':       result.get('error'),
        })
        if result['ok']:
            last_ok_snap = e['snap_id']

    # Step 4: update tracking columns
    if last_ok_snap:
        pg = _pg()
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
    total_mb  = sum(r.get('size_bytes', 0) for r in reports if r['ok']) / 1_048_576

    logger.info(
        f'{db_name}: {ok_count} reports generated '
        f'({total_mb:.1f} MB), {err_count} errors'
    )

    return {
        'ok':                True,
        'db_name':           db_name,
        'snap_date':         str(snap_date),
        'reports_generated': ok_count,
        'errors':            err_count,
        'total_mb':          round(total_mb, 2),
        'reports':           reports,
        'error':             None
    }


# ── Full workflow: all enabled databases ──────────────────────────────────────
def fetch_awrs_all_dbs(snap_date: date, awr_reports_dir: str) -> list:
    """Run fetch_awrs_for_date for every enabled Oracle connection."""
    connections = get_all_connections()
    enabled     = [c for c in connections if c.get('enabled')]
    results     = []
    for c in enabled:
        try:
            result = fetch_awrs_for_date(c['id'], snap_date, awr_reports_dir)
            results.append(result)
        except Exception as e:
            logger.error(f'fetch_awrs_all_dbs [{c["db_name"]}]: {e}')
            results.append({
                'ok': False, 'db_name': c['db_name'], 'error': str(e)
            })
    return results
