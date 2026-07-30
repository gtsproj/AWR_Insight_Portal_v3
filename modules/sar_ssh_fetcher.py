# modules/sar_ssh_fetcher.py
# ============================================================
# AWR Insight Portal v3 — Multi-Server SAR SSH Delta Extractor
#
# Extracts SAR data deltas from Linux servers via SSH.
#
# How it works:
#   1. SSH into the Linux server
#   2. Run: sar -A -s HH:MM:SS -e HH:MM:SS -f /var/log/sa/saDD
#      to extract only the time window since the last pull
#   3. Capture the text output directly over SSH (no file to SCP)
#   4. Save as <hostname>_saDD_HHMMSS.txt in sar_drop/<hostname>/
#   5. SARWatcher picks it up and queues for parsing
#
# Benefits over binary pull:
#   • No binary file transfer (only text delta)
#   • No WSL conversion needed on the portal server
#   • Zero duplicate data — only new intervals are extracted
#   • Works across midnight: when date changes, extracts
#     00:00 onwards from the new SA file automatically
#
# Schedule: every pull_interval_hrs — default 1 hour
#   00:00 → sa01 starts  (or sa<today_day> on Linux)
#   01:00 → extract sa<today> -s 00:00:00 -e 01:00:00
#   02:00 → extract sa<today> -s 01:00:00 -e 02:00:00
#   ...
#   23:00 → extract sa<today> -s 22:00:00 -e 23:00:00
#   00:00 next day → new SA file starts, extract resumes
#
# Prerequisites: pip install paramiko
#
# SSH authentication priority:
#   1. SSH key file (ssh_key_path)
#   2. Password (password_enc)
# ============================================================

import os
import sys
import base64
import logging
from datetime import datetime, date, time, timedelta
from typing import Optional

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))

from logger_utils import get_logger
logger = get_logger('sar_ssh_fetcher')


# ── Password helpers ──────────────────────────────────────────────────────────
def _encode_password(plain: str) -> str:
    return base64.b64encode(plain.encode('utf-8')).decode('utf-8')

def _decode_password(encoded: str) -> str:
    if not encoded:
        return ''
    try:
        return base64.b64decode(encoded.encode('utf-8')).decode('utf-8')
    except Exception:
        return encoded


# ── PostgreSQL helper ─────────────────────────────────────────────────────────
def _pg():
    from db import get_db_connection
    return get_db_connection()


# ── CRUD ──────────────────────────────────────────────────────────────────────
def get_all_connections() -> list:
    """Return all SAR SSH connections (no passwords)."""
    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, hostname, display_name, ssh_host, ssh_port,
                       ssh_user, ssh_key_path, remote_sar_path,
                       pull_interval_hrs, enabled,
                       last_pull_at, last_pull_time, last_pull_date,
                       added_at, added_by
                FROM sar_ssh_connections
                ORDER BY hostname
            """)
            cols = [d[0] for d in cur.description]
            rows = []
            for row in cur.fetchall():
                d = dict(zip(cols, row))
                # Serialise non-JSON types
                for k in ('last_pull_at', 'added_at'):
                    if d.get(k):
                        d[k] = d[k].strftime('%Y-%m-%d %H:%M:%S')
                if d.get('last_pull_time'):
                    d['last_pull_time'] = str(d['last_pull_time'])
                if d.get('last_pull_date'):
                    d['last_pull_date'] = str(d['last_pull_date'])
                if d.get('pull_interval_hrs') is not None:
                    d['pull_interval_hrs'] = float(d['pull_interval_hrs'])
                rows.append(d)
            return rows
    finally:
        conn.close()


def get_connection_by_id(conn_id: int) -> Optional[dict]:
    """Return one connection including password_enc."""
    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, hostname, display_name, ssh_host, ssh_port,
                       ssh_user, ssh_key_path, password_enc, remote_sar_path,
                       pull_interval_hrs, enabled,
                       last_pull_at, last_pull_time, last_pull_date
                FROM sar_ssh_connections
                WHERE id = %s
            """, (conn_id,))
            row = cur.fetchone()
            if not row:
                return None
            cols = [d[0] for d in cur.description]
            d = dict(zip(cols, row))
            if d.get('last_pull_at'):
                d['last_pull_at'] = d['last_pull_at'].strftime('%Y-%m-%d %H:%M:%S')
            if d.get('last_pull_time'):
                d['last_pull_time'] = str(d['last_pull_time'])
            if d.get('last_pull_date'):
                d['last_pull_date'] = str(d['last_pull_date'])
            if d.get('pull_interval_hrs') is not None:
                d['pull_interval_hrs'] = float(d['pull_interval_hrs'])
            return d
    finally:
        conn.close()


def save_connection(data: dict, added_by: str = 'admin') -> dict:
    """Insert or update a SAR SSH connection. Returns {ok, id, error}."""
    hostname          = (data.get('hostname') or '').strip()
    display_name      = (data.get('display_name') or hostname).strip()
    ssh_host          = (data.get('ssh_host') or '').strip()
    ssh_port          = int(data.get('ssh_port') or 22)
    ssh_user          = (data.get('ssh_user') or '').strip()
    ssh_key_path      = (data.get('ssh_key_path') or '').strip()
    password          = (data.get('password') or '').strip()
    remote_sar_path   = (data.get('remote_sar_path') or '/var/log/sa').strip()
    pull_interval_hrs = float(data.get('pull_interval_hrs') or 1)
    enabled           = bool(data.get('enabled', True))

    if not hostname:
        return {'ok': False, 'error': 'Hostname is required'}
    if not ssh_host:
        return {'ok': False, 'error': 'SSH Host is required'}
    if not ssh_user:
        return {'ok': False, 'error': 'SSH Username is required'}

    if password:
        password_enc = _encode_password(password)
    else:
        conn = _pg()
        try:
            with conn.cursor() as cur:
                cur.execute('SELECT password_enc FROM sar_ssh_connections WHERE hostname=%s',
                            (hostname,))
                row = cur.fetchone()
                password_enc = row[0] if row else ''
        finally:
            conn.close()

    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO sar_ssh_connections
                    (hostname, display_name, ssh_host, ssh_port, ssh_user,
                     ssh_key_path, password_enc, remote_sar_path,
                     pull_interval_hrs, enabled, added_by)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (hostname) DO UPDATE SET
                    display_name      = EXCLUDED.display_name,
                    ssh_host          = EXCLUDED.ssh_host,
                    ssh_port          = EXCLUDED.ssh_port,
                    ssh_user          = EXCLUDED.ssh_user,
                    ssh_key_path      = EXCLUDED.ssh_key_path,
                    password_enc      = CASE
                        WHEN EXCLUDED.password_enc != ''
                        THEN EXCLUDED.password_enc
                        ELSE sar_ssh_connections.password_enc END,
                    remote_sar_path   = EXCLUDED.remote_sar_path,
                    pull_interval_hrs = EXCLUDED.pull_interval_hrs,
                    enabled           = EXCLUDED.enabled,
                    added_by          = EXCLUDED.added_by
                RETURNING id
            """, (hostname, display_name, ssh_host, ssh_port, ssh_user,
                  ssh_key_path, password_enc, remote_sar_path,
                  pull_interval_hrs, enabled, added_by))
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
            cur.execute('DELETE FROM sar_ssh_connections WHERE id=%s', (conn_id,))
        conn.commit()
        return {'ok': True}
    except Exception as e:
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def _update_last_pull(conn_id: int, pull_end_time: time, pull_date: date):
    """Update last_pull_at, last_pull_time, last_pull_date after successful pull."""
    pg = _pg()
    try:
        with pg.cursor() as cur:
            cur.execute("""
                UPDATE sar_ssh_connections
                SET last_pull_at   = NOW(),
                    last_pull_time = %s,
                    last_pull_date = %s
                WHERE id = %s
            """, (pull_end_time.strftime('%H:%M:%S'), pull_date, conn_id))
        pg.commit()
    except Exception as e:
        logger.error(f'_update_last_pull: {e}')
    finally:
        pg.close()


# ── SSH client helper ─────────────────────────────────────────────────────────
def _ssh_connect(cfg: dict):
    """Open paramiko SSH connection from connection config."""
    try:
        import paramiko
    except ImportError:
        raise ImportError('paramiko not installed. Run: pip install paramiko')

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    kw = {
        'hostname': cfg['ssh_host'],
        'port':     int(cfg['ssh_port'] or 22),
        'username': cfg['ssh_user'],
        'timeout':  30
    }
    key_path = (cfg.get('ssh_key_path') or '').strip()
    password  = _decode_password(cfg.get('password_enc') or '')

    if key_path and os.path.exists(key_path):
        kw['key_filename'] = key_path
    elif password:
        kw['password'] = password
    else:
        raise ValueError(
            'No SSH key file or password configured. '
            'Provide ssh_key_path or password.'
        )

    ssh.connect(**kw)
    return ssh


# ── Connectivity test ─────────────────────────────────────────────────────────
def test_connection(conn_id: int) -> dict:
    """
    Test SSH connectivity and verify sar/saDF is available on the server.
    Returns {ok, message, sar_available, sa_files}.
    """
    cfg = get_connection_by_id(conn_id)
    if not cfg:
        return {'ok': False, 'message': f'Connection {conn_id} not found'}

    try:
        ssh = _ssh_connect(cfg)
    except ImportError as e:
        return {'ok': False, 'message': str(e)}
    except Exception as e:
        return {'ok': False, 'message': f'SSH connection failed: {e}'}

    try:
        remote = cfg.get('remote_sar_path', '/var/log/sa')

        # Check sar command available
        _, stdout, _ = ssh.exec_command('which sar 2>/dev/null || echo NOT_FOUND')
        sar_path = stdout.read().decode().strip()
        sar_ok = sar_path != 'NOT_FOUND' and bool(sar_path)

        # List SA files
        _, stdout, stderr = ssh.exec_command(f'ls {remote}/sa[0-9][0-9] 2>/dev/null')
        sa_files = [os.path.basename(f) for f in stdout.read().decode().split()
                    if f.strip()]
        sa_files.sort()

        # Try a minimal sar command to confirm it works
        today_day = datetime.now().day
        sa_file   = f"{remote}/sa{today_day:02d}"
        _, stdout, stderr = ssh.exec_command(
            f'sar -u -s 00:00:00 -e 00:01:00 -f {sa_file} 2>&1 | head -5'
        )
        sar_test_out = stdout.read().decode().strip()
        sar_runs_ok  = 'Linux' in sar_test_out or 'Average' in sar_test_out or \
                       'IFACE' in sar_test_out or 'CPU' in sar_test_out

        ssh.close()

        if not sar_ok:
            return {
                'ok': False,
                'message': (f'SSH connected to {cfg["ssh_host"]} as {cfg["ssh_user"]} — '
                            f'but "sar" command not found. Install sysstat package.')
            }

        return {
            'ok':            True,
            'message':       (f'Connected to {cfg["ssh_host"]} as {cfg["ssh_user"]}. '
                              f'sar found at {sar_path}. '
                              f'{len(sa_files)} SA file(s) in {remote}: '
                              + (', '.join(sa_files[:6]) + ('…' if len(sa_files) > 6 else '')
                                 if sa_files else 'none')),
            'sar_available': sar_ok,
            'sar_works':     sar_runs_ok,
            'sa_files':      sa_files
        }
    except Exception as e:
        return {'ok': False, 'message': f'Test query failed: {e}'}
    finally:
        try:
            ssh.close()
        except Exception:
            pass


# ── Delta extraction — core function ──────────────────────────────────────────
def extract_sar_delta(conn_id: int, sar_drop_dir: str,
                      target_date: date = None,
                      start_time: time = None,
                      end_time: time   = None) -> dict:
    """
    Extract SAR delta from a Linux server for a specific time window.

    If start_time/end_time are None, they are derived from last_pull_time:
      - start_time = last_pull_time (or 00:00:00 if first pull of the day)
      - end_time   = start_time + pull_interval_hrs (capped at now)

    If target_date is None, it defaults to today (or yesterday if we're
    within the first few minutes of the day and last_pull was yesterday).

    Runs on remote server:
      sar -A -s HH:MM:SS -e HH:MM:SS -f /var/log/sa/sa<DD>

    Output saved as:
      sar_drop_dir/<hostname>/<hostname>_sa<DD>_<HHMMSS>_<HHMMSS>.txt

    Returns {ok, hostname, file_path, start_time, end_time, lines, error}
    """
    cfg = get_connection_by_id(conn_id)
    if not cfg:
        return {'ok': False, 'error': f'Connection {conn_id} not found',
                'hostname': 'unknown'}

    hostname = cfg['hostname']
    remote   = cfg.get('remote_sar_path', '/var/log/sa')

    # ── Determine time window ──────────────────────────────────────────────
    now          = datetime.now()
    interval_hrs = float(cfg.get('pull_interval_hrs') or 1)

    if target_date is None:
        last_pull_date_str = cfg.get('last_pull_date')
        last_pull_date = (date.fromisoformat(str(last_pull_date_str))
                          if last_pull_date_str else None)
        target_date = now.date()
        # If last pull was today, stay on today's SA file
        # If last pull was before today (overnight gap), start from 00:00
        # on the days in between and today

    if start_time is None:
        last_time_str = cfg.get('last_pull_time')
        if last_time_str and cfg.get('last_pull_date'):
            last_date = date.fromisoformat(str(cfg['last_pull_date']))
            if last_date == target_date:
                # Continue from where we left off on the same day
                parts     = str(last_time_str).split(':')
                start_time = time(int(parts[0]), int(parts[1]),
                                  int(float(parts[2])) if len(parts) > 2 else 0)
            else:
                # Different date — start from 00:00 on the target date
                start_time = time(0, 0, 0)
        else:
            # First ever pull — start from 00:00
            start_time = time(0, 0, 0)

    if end_time is None:
        # Advance by pull_interval_hrs from start
        start_dt = datetime.combine(target_date, start_time)
        end_dt   = start_dt + timedelta(hours=interval_hrs)
        # Cap at current time — don't request data that doesn't exist yet
        if end_dt > now:
            end_dt = now
        end_time = end_dt.time()

    # Nothing to extract
    if start_time >= end_time:
        return {
            'ok':       True,
            'hostname': hostname,
            'file_path': None,
            'start_time': str(start_time),
            'end_time':   str(end_time),
            'lines':    0,
            'message':  'No new data to extract — start_time >= end_time',
            'error':    None
        }

    sa_day      = target_date.day
    sa_filename = f'sa{sa_day:02d}'
    sa_remote   = f'{remote.rstrip("/")}/{sa_filename}'
    s_str       = start_time.strftime('%H:%M:%S')
    e_str       = end_time.strftime('%H:%M:%S')

    logger.info(
        f'SAR delta: {hostname} {target_date} {s_str}–{e_str} '
        f'from {sa_remote}'
    )

    # ── SSH connect ────────────────────────────────────────────────────────
    try:
        ssh = _ssh_connect(cfg)
    except Exception as e:
        return {'ok': False, 'hostname': hostname,
                'error': f'SSH connect failed: {e}'}

    try:
        # Run sar on remote server and capture output
        cmd = f'sar -A -s {s_str} -e {e_str} -f {sa_remote} 2>&1'
        _, stdout, _ = ssh.exec_command(cmd, timeout=120)
        output = stdout.read().decode('utf-8', errors='replace')

        if not output.strip():
            return {
                'ok': False, 'hostname': hostname,
                'error': f'sar returned no output for {sa_remote} {s_str}–{e_str}. '
                         f'SA file may not exist yet or time range has no data.'
            }

        # Check for sar errors
        if 'No such file' in output or 'cannot open' in output.lower():
            return {
                'ok': False, 'hostname': hostname,
                'error': f'SA file not found on remote: {sa_remote}'
            }

        lines = len([l for l in output.splitlines() if l.strip()])

        # ── Save to sar_drop/<hostname>/ ──────────────────────────────────
        dest_dir = os.path.join(sar_drop_dir, hostname)
        os.makedirs(dest_dir, exist_ok=True)

        # Filename: <hostname>_sa<DD>_<HHMMSS>_<HHMMSS>.txt
        s_tag    = start_time.strftime('%H%M%S')
        e_tag    = end_time.strftime('%H%M%S')
        out_name = f'{hostname}_{sa_filename}_{s_tag}_{e_tag}.txt'
        out_path = os.path.join(dest_dir, out_name)

        with open(out_path, 'w', encoding='utf-8') as f:
            f.write(output)

        logger.info(
            f'SAR delta saved: {out_name} ({lines} data lines)'
        )

        # ── Update tracking ────────────────────────────────────────────────
        _update_last_pull(conn_id, end_time, target_date)

        return {
            'ok':        True,
            'hostname':  hostname,
            'file_path': out_path,
            'file_name': out_name,
            'start_time': s_str,
            'end_time':   e_str,
            'lines':     lines,
            'error':     None
        }

    except Exception as e:
        logger.error(f'extract_sar_delta [{hostname}]: {e}')
        return {'ok': False, 'hostname': hostname, 'error': str(e)}
    finally:
        try:
            ssh.close()
        except Exception:
            pass


# ── Catch-up: extract all missed intervals ────────────────────────────────────
def extract_all_missed(cfg: dict, sar_drop_dir: str) -> list:
    """
    If the scheduler was stopped for several hours or overnight,
    extract all missed hourly intervals since last_pull_time/date.

    Handles the date boundary: if last_pull_date was yesterday,
    first completes yesterday's remaining intervals, then extracts
    today's intervals from 00:00 onwards.

    Returns list of {ok, start_time, end_time, lines, error} per interval.
    """
    now          = datetime.now()
    interval_hrs = float(cfg.get('pull_interval_hrs') or 1)
    conn_id      = cfg['id']
    results      = []

    last_date_str = cfg.get('last_pull_date')
    last_time_str = cfg.get('last_pull_time')

    if last_date_str and last_time_str:
        last_date = date.fromisoformat(str(last_date_str))
        parts      = str(last_time_str).split(':')
        last_time  = time(int(parts[0]), int(parts[1]),
                          int(float(parts[2])) if len(parts) > 2 else 0)
    else:
        # First ever pull — start from today 00:00
        last_date = now.date()
        last_time = time(0, 0, 0)

    # Build list of (target_date, start_time, end_time) intervals to extract
    intervals = []
    current_dt = datetime.combine(last_date, last_time)
    target_dt  = now  # don't go past now

    while current_dt < target_dt:
        interval_start = current_dt
        interval_end   = current_dt + timedelta(hours=interval_hrs)
        if interval_end > target_dt:
            interval_end = target_dt

        intervals.append((
            interval_start.date(),
            interval_start.time(),
            interval_end.time()
        ))
        current_dt = interval_end

    if not intervals:
        return []

    if len(intervals) > 1:
        logger.info(
            f'SAR catch-up for {cfg["hostname"]}: '
            f'{len(intervals)} missed interval(s) since '
            f'{last_date} {last_time}'
        )

    for (tgt_date, s_time, e_time) in intervals:
        result = extract_sar_delta(
            conn_id, sar_drop_dir,
            target_date=tgt_date,
            start_time=s_time,
            end_time=e_time
        )
        results.append(result)
        if not result['ok']:
            logger.error(
                f'SAR catch-up failed for {cfg["hostname"]} '
                f'{tgt_date} {s_time}–{e_time}: {result.get("error")}'
            )
            # Stop catch-up on first failure — avoid cascading errors
            break

    return results


# ── Top-level: pull for one server ────────────────────────────────────────────
def pull_sar_files(conn_id: int, sar_drop_dir: str) -> dict:
    """
    Extract the current delta for one server.
    Catches up all missed intervals if the scheduler was paused.
    Returns summary {ok, hostname, intervals_extracted, files, errors}.
    """
    cfg = get_connection_by_id(conn_id)
    if not cfg:
        return {'ok': False, 'error': f'Connection {conn_id} not found',
                'hostname': 'unknown'}
    if not cfg.get('enabled'):
        return {'ok': False, 'error': 'Connection disabled',
                'hostname': cfg.get('hostname', '?')}

    results = extract_all_missed(cfg, sar_drop_dir)
    if not results:
        # Nothing missed — extract the current interval now
        results = [extract_sar_delta(conn_id, sar_drop_dir)]

    ok_count  = sum(1 for r in results if r.get('ok'))
    err_count = len(results) - ok_count

    return {
        'ok':                 True,
        'hostname':           cfg['hostname'],
        'intervals_extracted': ok_count,
        'files':              [r['file_name'] for r in results if r.get('file_name')],
        'errors':             err_count,
        'results':            results,
        'error':              None
    }


def cleanup_sar_archive(sar_archive_dir: str, retain_days: int = 30):
    """
    Delete SAR text files from sar_archive older than retain_days.
    Called by the scheduler periodically to prevent unbounded growth.

    With hourly pulls: 24 files/day/server × retain_days = files kept.
    Default 30 days = 720 files per server retained.
    Each file is ~50-100 KB so 30 days ≈ 35-70 MB per server.
    """
    if not os.path.isdir(sar_archive_dir):
        return {'deleted': 0, 'errors': 0}

    from datetime import datetime, timedelta
    cutoff  = datetime.now() - timedelta(days=retain_days)
    deleted = 0
    errors  = 0

    for hostname_dir in os.scandir(sar_archive_dir):
        if not hostname_dir.is_dir():
            continue
        for entry in os.scandir(hostname_dir.path):
            if not entry.name.endswith('.txt'):
                continue
            try:
                mtime = datetime.fromtimestamp(entry.stat().st_mtime)
                if mtime < cutoff:
                    os.unlink(entry.path)
                    deleted += 1
            except Exception as e:
                logger.warning(f'cleanup_sar_archive: could not delete '
                               f'{entry.path}: {e}')
                errors += 1

    if deleted:
        logger.info(f'SAR archive cleanup: deleted {deleted} file(s) '
                    f'older than {retain_days} days')
    return {'deleted': deleted, 'errors': errors}


def pull_all_servers(sar_drop_dir: str) -> list:
    """Run pull_sar_files for all enabled SSH connections."""
    connections = get_all_connections()
    enabled     = [c for c in connections if c.get('enabled')]
    results     = []
    for c in enabled:
        try:
            result = pull_sar_files(c['id'], sar_drop_dir)
            results.append(result)
        except Exception as e:
            logger.error(f'pull_all_servers [{c["hostname"]}]: {e}')
            results.append({'ok': False, 'hostname': c['hostname'], 'error': str(e)})
    return results
