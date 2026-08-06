# modules/nmon_ssh_fetcher.py
# ============================================================
# AWR Insight Portal v3 — NMON SSH Fetcher
#
# Pulls .nmon files from IBM AIX servers via SSH/SFTP and deposits
# them under nmon_drop/<hostname>/ for the NMONWatcher service.
#
# Mirrors modules/sar_ssh_fetcher.py but simplified:
#   - No delta-extraction (no sar -A command) — just SFTP download
#   - No binary conversion — NMON files are always plain-text CSV
#   - Pulls any *.nmon file in remote_nmon_path modified after
#     last_pull_at and not already present in the local drop folder
#
# Prerequisites: pip install paramiko
# ============================================================

import os
import sys
import base64
from datetime import datetime
from typing import Optional

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))

from logger_utils import get_logger
logger = get_logger('nmon_ssh_fetcher')


# ── Password helpers (identical to sar_ssh_fetcher) ───────────────────────────
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
    """Return all NMON SSH connections (no passwords)."""
    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, hostname, display_name, ssh_host, ssh_port,
                       ssh_user, ssh_key_path, remote_nmon_path,
                       pull_interval_hrs, enabled,
                       last_pull_at, added_at
                FROM nmon_ssh_connections
                ORDER BY hostname
            """)
            cols = [d[0] for d in cur.description]
            rows = []
            for row in cur.fetchall():
                d = dict(zip(cols, row))
                for k in ('last_pull_at', 'added_at'):
                    if d.get(k):
                        d[k] = d[k].strftime('%Y-%m-%d %H:%M:%S')
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
                       ssh_user, ssh_key_path, password_enc,
                       remote_nmon_path, pull_interval_hrs, enabled, last_pull_at
                FROM nmon_ssh_connections
                WHERE id = %s
            """, (conn_id,))
            row = cur.fetchone()
            if not row:
                return None
            cols = [d[0] for d in cur.description]
            d = dict(zip(cols, row))
            if d.get('last_pull_at'):
                d['last_pull_at'] = d['last_pull_at'].strftime('%Y-%m-%d %H:%M:%S')
            if d.get('pull_interval_hrs') is not None:
                d['pull_interval_hrs'] = float(d['pull_interval_hrs'])
            return d
    finally:
        conn.close()


def save_connection(data: dict, added_by: str = 'admin') -> dict:
    """Insert or update a NMON SSH connection. Returns {ok, id, error}."""
    hostname          = (data.get('hostname') or '').strip()
    display_name      = (data.get('display_name') or hostname).strip()
    ssh_host          = (data.get('ssh_host') or '').strip()
    ssh_port          = int(data.get('ssh_port') or 22)
    ssh_user          = (data.get('ssh_user') or '').strip()
    ssh_key_path      = (data.get('ssh_key_path') or '').strip()
    remote_nmon_path  = (data.get('remote_nmon_path') or '/home/oracle/nmon').strip()
    pull_interval_hrs = float(data.get('pull_interval_hrs') or 1)
    enabled           = bool(data.get('enabled', True))
    password          = (data.get('password') or '').strip()

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
                cur.execute('SELECT password_enc FROM nmon_ssh_connections WHERE hostname=%s',
                            (hostname,))
                row = cur.fetchone()
                password_enc = row[0] if row else ''
        finally:
            conn.close()

    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO nmon_ssh_connections
                    (hostname, display_name, ssh_host, ssh_port, ssh_user,
                     ssh_key_path, password_enc, remote_nmon_path,
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
                        ELSE nmon_ssh_connections.password_enc END,
                    remote_nmon_path  = EXCLUDED.remote_nmon_path,
                    pull_interval_hrs = EXCLUDED.pull_interval_hrs,
                    enabled           = EXCLUDED.enabled,
                    added_by          = EXCLUDED.added_by
                RETURNING id
            """, (hostname, display_name, ssh_host, ssh_port, ssh_user,
                  ssh_key_path, password_enc, remote_nmon_path,
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
            cur.execute('DELETE FROM nmon_ssh_connections WHERE id=%s', (conn_id,))
        conn.commit()
        return {'ok': True}
    except Exception as e:
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def _update_last_pull(conn_id: int):
    pg = _pg()
    try:
        with pg.cursor() as cur:
            cur.execute("""
                UPDATE nmon_ssh_connections SET last_pull_at = NOW()
                WHERE id = %s
            """, (conn_id,))
        pg.commit()
    except Exception as e:
        logger.error(f'_update_last_pull: {e}')
    finally:
        pg.close()


# ── SSH helper ────────────────────────────────────────────────────────────────
def _ssh_connect(cfg: dict):
    """Open a paramiko SSH connection from connection config."""
    try:
        import paramiko
    except ImportError:
        raise ImportError('paramiko not installed. Run: pip install paramiko')

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    kw = {
        'hostname': cfg['ssh_host'],
        'port':     int(cfg.get('ssh_port') or 22),
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
        raise ValueError('No SSH key file or password configured.')

    ssh.connect(**kw)
    return ssh


# ── Connectivity test ─────────────────────────────────────────────────────────
def test_connection(conn_id: int) -> dict:
    """
    Test SSH connectivity and verify remote_nmon_path contains .nmon files.
    Returns {ok, message, nmon_files}.
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
        remote = cfg.get('remote_nmon_path', '/home/oracle/nmon')

        # List .nmon files on the remote server
        _, stdout, _ = ssh.exec_command(
            f'ls {remote}/*.nmon 2>/dev/null || echo NO_FILES'
        )
        output = stdout.read().decode().strip()

        if output == 'NO_FILES' or not output:
            return {
                'ok': True,
                'message': (f'Connected to {cfg["ssh_host"]} as {cfg["ssh_user"]}. '
                            f'No .nmon files found in {remote}. '
                            f'Verify NMON is running and writing to this path.'),
                'nmon_files': []
            }

        files = [os.path.basename(f) for f in output.split() if f.endswith('.nmon')]
        files.sort()

        return {
            'ok':        True,
            'message':   (f'Connected to {cfg["ssh_host"]} as {cfg["ssh_user"]}. '
                          f'{len(files)} .nmon file(s) in {remote}: '
                          + (', '.join(files[:5]) + ('…' if len(files) > 5 else ''))),
            'nmon_files': files
        }
    except Exception as e:
        return {'ok': False, 'message': f'Test query failed: {e}'}
    finally:
        try:
            ssh.close()
        except Exception:
            pass


# ── Pull — core function ──────────────────────────────────────────────────────
def pull_nmon_files(conn_id: int, nmon_drop_dir: str) -> dict:
    """
    Pull new .nmon files from one AIX server via SFTP and deposit them
    under nmon_drop_dir/<hostname>/ for the NMONWatcher service.

    Only downloads files modified after last_pull_at (all files on first
    pull for this connection). Files already present in the local drop
    folder are skipped.

    Returns {ok, hostname, files_pulled, file_list, error}.
    """
    cfg = get_connection_by_id(conn_id)
    if not cfg:
        return {'ok': False, 'error': f'Connection {conn_id} not found',
                'hostname': 'unknown', 'files_pulled': 0, 'file_list': []}
    if not cfg.get('enabled'):
        return {'ok': False, 'error': 'Connection disabled',
                'hostname': cfg.get('hostname', '?'), 'files_pulled': 0, 'file_list': []}

    hostname = cfg['hostname']
    remote   = cfg.get('remote_nmon_path', '/home/oracle/nmon').rstrip('/')

    since = None
    if cfg.get('last_pull_at'):
        try:
            since = datetime.strptime(cfg['last_pull_at'], '%Y-%m-%d %H:%M:%S')
        except (ValueError, TypeError):
            since = None

    try:
        ssh = _ssh_connect(cfg)
    except Exception as e:
        return {'ok': False, 'hostname': hostname, 'files_pulled': 0,
                'file_list': [], 'error': f'SSH connect failed: {e}'}

    try:
        sftp = ssh.open_sftp()

        try:
            entries = sftp.listdir_attr(remote)
        except IOError:
            return {'ok': False, 'hostname': hostname, 'files_pulled': 0,
                    'file_list': [], 'error': f'Remote path not found: {remote}'}

        dest_dir = os.path.join(nmon_drop_dir, hostname)
        os.makedirs(dest_dir, exist_ok=True)

        fetched = []
        for entry in entries:
            if not entry.filename.lower().endswith('.nmon'):
                continue
            file_mtime = datetime.fromtimestamp(entry.st_mtime)
            if since and file_mtime <= since:
                continue

            local_path = os.path.join(dest_dir, entry.filename)
            if os.path.exists(local_path):
                continue  # already downloaded

            remote_path = f'{remote}/{entry.filename}'
            try:
                sftp.get(remote_path, local_path)
                fetched.append(entry.filename)
                logger.info(f'Pulled NMON ({hostname}): {entry.filename}')
            except Exception as e:
                logger.warning(f'Failed to download {remote_path}: {e}')

        _update_last_pull(conn_id)

        return {
            'ok':          True,
            'hostname':    hostname,
            'files_pulled': len(fetched),
            'file_list':   fetched,
            'error':       None
        }

    except Exception as e:
        logger.error(f'pull_nmon_files [{hostname}]: {e}')
        return {'ok': False, 'hostname': hostname, 'files_pulled': 0,
                'file_list': [], 'error': str(e)}
    finally:
        try:
            ssh.close()
        except Exception:
            pass


def pull_all_servers(nmon_drop_dir: str) -> list:
    """Run pull_nmon_files for all enabled connections."""
    connections = get_all_connections()
    enabled     = [c for c in connections if c.get('enabled')]
    results     = []
    for c in enabled:
        try:
            results.append(pull_nmon_files(c['id'], nmon_drop_dir))
        except Exception as e:
            logger.error(f'pull_all_servers [{c["hostname"]}]: {e}')
            results.append({'ok': False, 'hostname': c['hostname'], 'error': str(e),
                            'files_pulled': 0, 'file_list': []})
    return results



# ══════════════════════════════════════════════════════════════════════════════
# INCREMENTAL PULL + PARSE  —  1-hour lag strategy (mirrors SAR SSH fetcher)
# ══════════════════════════════════════════════════════════════════════════════
#
# How it works (compare with sar_ssh_fetcher.extract_sar_delta):
#   SAR:  SSH → run `sar -A -s HH:MM -e HH:MM -f /var/log/sa/saDD`
#             ON REMOTE SERVER → capture text delta → save .txt →
#             SARWatcher queues → queue_processor parses
#         The binary SA file is converted to text ON THE LINUX SERVER
#         (where `sar`/sysstat is already installed) — NO WSL needed.
#
#   NMON: SSH → SFTP download the active .nmon file to nmon_cache/<host>/
#             → parse only tokens with seq > last_token_seq (tracked in
#               nmon_parse_log) → insert new rows directly
#         NMON files are always plain-text CSV — no binary conversion ever.
#         nmon_cache/ is NOT watched by NMONWatcher (avoids race condition).
#         NMONWatcher only watches nmon_drop/ (for manually dropped files).
#
# Catch-up: if the scheduler was stopped for multiple hours, all missed
#   token ranges are processed automatically on next pull (same file,
#   nmon_parse_log knows where we left off).
#
# State tracking:
#   nmon_ssh_connections.last_pull_at   — when we last pulled (like SAR)
#   nmon_parse_log.last_token_seq       — last Txxxx processed per hostname+file
# ══════════════════════════════════════════════════════════════════════════════

def get_active_nmon_filename(conn_id: int) -> Optional[str]:
    """
    SSH into the AIX server and return the filename of the currently active
    NMON file (the most recently modified .nmon file in remote_nmon_path).
    """
    cfg = get_connection_by_id(conn_id)
    if not cfg:
        return None
    remote = cfg.get('remote_nmon_path', '/home/oracle/nmon').rstrip('/')
    try:
        ssh  = _ssh_connect(cfg)
        sftp = ssh.open_sftp()
        try:
            entries    = sftp.listdir_attr(remote)
            nmon_files = [e for e in entries if e.filename.lower().endswith('.nmon')]
            if not nmon_files:
                return None
            return max(nmon_files, key=lambda e: e.st_mtime).filename
        finally:
            ssh.close()
    except Exception as e:
        logger.error(f'get_active_nmon_filename [{conn_id}]: {e}')
        return None


def pull_and_parse_incremental(conn_id: int, nmon_cache_dir: str) -> dict:
    """
    NMON 1-hour lag pull — mirrors extract_sar_delta() in sar_ssh_fetcher.py.

    1. SSH into the AIX server via paramiko
    2. SFTP-download the currently active .nmon file to
       nmon_cache_dir/<hostname>/<filename>.nmon
       (always overwrites — NMON appends new lines to the same file)
    3. Call process_nmon_file_incremental() — reads nmon_parse_log to find
       last_token_seq, skips already-processed tokens, parses and inserts
       only the new ones, then updates nmon_parse_log.last_token_seq
    4. Update nmon_ssh_connections.last_pull_at

    nmon_cache_dir is a dedicated cache folder NOT watched by NMONWatcher,
    preventing the race condition where both the watcher and the SSH fetcher
    would try to process the same file simultaneously.

    Returns {ok, hostname, filename, new_snapshots, error}.
    """
    cfg = get_connection_by_id(conn_id)
    if not cfg:
        return {'ok': False, 'error': f'Connection {conn_id} not found',
                'hostname': 'unknown', 'filename': None}
    if not cfg.get('enabled'):
        return {'ok': False, 'error': 'Connection disabled',
                'hostname': cfg.get('hostname', '?'), 'filename': None}

    hostname = cfg['hostname']
    remote   = cfg.get('remote_nmon_path', '/home/oracle/nmon').rstrip('/')

    # ── SSH + SFTP download ────────────────────────────────────────────────────
    try:
        ssh  = _ssh_connect(cfg)
        sftp = ssh.open_sftp()
    except Exception as e:
        return {'ok': False, 'hostname': hostname, 'filename': None,
                'error': f'SSH connect failed: {e}'}

    try:
        try:
            entries = sftp.listdir_attr(remote)
        except IOError:
            return {'ok': False, 'hostname': hostname, 'filename': None,
                    'error': f'Remote NMON path not found: {remote}'}

        nmon_files = [e for e in entries if e.filename.lower().endswith('.nmon')]
        if not nmon_files:
            return {'ok': True, 'hostname': hostname, 'filename': None,
                    'message': f'No .nmon files in {remote}', 'error': None}

        # Most recently modified = currently active NMON file
        active     = max(nmon_files, key=lambda e: e.st_mtime)
        fname      = active.filename
        remote_path = f'{remote}/{fname}'

        # Download to nmon_cache/<hostname>/ (NOT nmon_drop/ — avoids NMONWatcher race)
        dest_dir   = os.path.join(nmon_cache_dir, hostname)
        os.makedirs(dest_dir, exist_ok=True)
        local_path = os.path.join(dest_dir, fname)

        sftp.get(remote_path, local_path)
        logger.info(
            f'NMON cache: downloaded {fname} '
            f'({active.st_size:,} bytes) for {hostname}'
        )

    except Exception as e:
        logger.error(f'pull_and_parse_incremental SFTP [{hostname}]: {e}')
        return {'ok': False, 'hostname': hostname, 'filename': None, 'error': str(e)}
    finally:
        try:
            ssh.close()
        except Exception:
            pass

    # ── Incremental parse ──────────────────────────────────────────────────────
    # process_nmon_file_incremental() reads nmon_parse_log for last_token_seq,
    # parses only new tokens, inserts rows, and updates nmon_parse_log.
    # Catch-up is automatic: if the scheduler was paused for several hours,
    # all missed tokens are processed in this single call (the NMON file
    # already has them all — nmon_parse_log.last_token_seq tracks position).
    try:
        sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'modules', 'nmon'))
        from nmon_master_parser import process_nmon_file_incremental
        success = process_nmon_file_incremental(local_path, hostname_override=hostname)
    except Exception as e:
        logger.error(f'pull_and_parse_incremental PARSE [{hostname}]: {e}')
        _update_last_pull(conn_id)
        return {'ok': False, 'hostname': hostname, 'filename': fname, 'error': str(e)}

    _update_last_pull(conn_id)

    if success:
        logger.info(f'NMON incremental pull+parse complete: {hostname} / {fname}')
    else:
        logger.warning(f'NMON incremental pull+parse partial: {hostname} / {fname}')

    return {
        'ok':      success,
        'hostname': hostname,
        'filename': fname,
        'error':   None,
    }


def pull_and_parse_all_incremental(nmon_cache_dir: str) -> list:
    """Run pull_and_parse_incremental for all enabled NMON SSH connections."""
    connections = get_all_connections()
    results     = []
    for c in connections:
        if not c.get('enabled'):
            continue
        try:
            results.append(pull_and_parse_incremental(c['id'], nmon_cache_dir))
        except Exception as e:
            logger.error(f'pull_and_parse_all_incremental [{c["hostname"]}]: {e}')
            results.append({'ok': False, 'hostname': c['hostname'],
                            'error': str(e), 'filename': None})
    return results
