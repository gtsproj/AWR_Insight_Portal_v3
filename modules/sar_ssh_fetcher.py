# modules/sar_ssh_fetcher.py
# ============================================================
# AWR Insight Portal v3 — Multi-Server SAR SSH Pull
#
# Pulls SAR files (sa01..sa31) from multiple Linux servers
# via SSH/SFTP using paramiko. One row per server in the
# sar_ssh_connections table.
#
# Files are saved to: sar_drop\<hostname>\sa01 (binary)
# SARWatcher picks them up and queues for parsing.
#
# Prerequisites:
#   pip install paramiko
#
# SSH authentication (in priority order):
#   1. SSH key file (ssh_key_path)
#   2. Password (password_enc — base64 obfuscated)
#   3. SSH agent (if available)
# ============================================================

import os
import sys
import base64
import logging
from datetime import datetime, date
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
                       pull_interval_hrs, enabled, last_pull_at, added_at, added_by
                FROM sar_ssh_connections
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
                       ssh_user, ssh_key_path, password_enc, remote_sar_path,
                       pull_interval_hrs, enabled, last_pull_at
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
            if d.get('pull_interval_hrs') is not None:
                d['pull_interval_hrs'] = float(d['pull_interval_hrs'])
            return d
    finally:
        conn.close()


def save_connection(data: dict, added_by: str = 'admin') -> dict:
    """Insert or update a SAR SSH connection. Returns {ok, id, error}."""
    hostname        = (data.get('hostname') or '').strip()
    display_name    = (data.get('display_name') or hostname).strip()
    ssh_host        = (data.get('ssh_host') or '').strip()
    ssh_port        = int(data.get('ssh_port') or 22)
    ssh_user        = (data.get('ssh_user') or '').strip()
    ssh_key_path    = (data.get('ssh_key_path') or '').strip()
    password        = (data.get('password') or '').strip()
    remote_sar_path = (data.get('remote_sar_path') or '/var/log/sa').strip()
    pull_interval_hrs = float(data.get('pull_interval_hrs') or 24)
    enabled         = bool(data.get('enabled', True))

    if not hostname:
        return {'ok': False, 'error': 'Hostname is required'}
    if not ssh_host:
        return {'ok': False, 'error': 'SSH Host is required'}
    if not ssh_user:
        return {'ok': False, 'error': 'SSH Username is required'}

    # Determine password to store
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


# ── SSH connectivity test ──────────────────────────────────────────────────────
def test_connection(conn_id: int) -> dict:
    """Test SSH connectivity and list SAR files available."""
    cfg = get_connection_by_id(conn_id)
    if not cfg:
        return {'ok': False, 'message': f'Connection {conn_id} not found'}

    try:
        import paramiko
    except ImportError:
        return {
            'ok': False,
            'message': 'paramiko not installed. Run: pip install paramiko'
        }

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    kw = {
        'hostname': cfg['ssh_host'],
        'port':     cfg['ssh_port'],
        'username': cfg['ssh_user'],
        'timeout':  20
    }
    key_path = cfg.get('ssh_key_path', '').strip()
    password  = _decode_password(cfg.get('password_enc', ''))

    if key_path and os.path.exists(key_path):
        kw['key_filename'] = key_path
    elif password:
        kw['password'] = password

    try:
        ssh.connect(**kw)
        sftp = ssh.open_sftp()
        remote = cfg.get('remote_sar_path', '/var/log/sa')
        try:
            files = [f.filename for f in sftp.listdir_attr(remote)
                     if f.filename.startswith('sa') and f.filename[2:].isdigit()]
            files.sort()
        except Exception as e:
            sftp.close(); ssh.close()
            return {'ok': False, 'message': f'Connected but cannot list {remote}: {e}'}

        sftp.close()
        ssh.close()
        return {
            'ok': True,
            'message': (f'Connected to {cfg["ssh_host"]} as {cfg["ssh_user"]}. '
                        f'{len(files)} SAR file(s) found in {remote}: '
                        + (', '.join(files[:6]) + ('...' if len(files) > 6 else '')
                           if files else 'none')),
            'file_count': len(files)
        }
    except Exception as e:
        return {'ok': False, 'message': f'SSH connection failed: {e}'}


# ── Pull SAR files for one server ─────────────────────────────────────────────
def pull_sar_files(conn_id: int, sar_drop_dir: str,
                   since: datetime = None) -> dict:
    """
    Pull new/updated SAR files from one Linux server via SFTP.
    Files saved to sar_drop_dir/<hostname>/sa01 etc.
    Returns {ok, hostname, files_pulled, errors, file_list}.
    """
    cfg = get_connection_by_id(conn_id)
    if not cfg:
        return {'ok': False, 'error': f'Connection {conn_id} not found', 'files_pulled': 0}
    if not cfg.get('enabled'):
        return {'ok': False, 'error': 'Connection disabled', 'files_pulled': 0}

    hostname = cfg['hostname']

    try:
        import paramiko
    except ImportError:
        return {'ok': False, 'hostname': hostname,
                'error': 'paramiko not installed — run: pip install paramiko',
                'files_pulled': 0}

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    kw = {
        'hostname': cfg['ssh_host'],
        'port':     cfg['ssh_port'],
        'username': cfg['ssh_user'],
        'timeout':  30
    }
    key_path = cfg.get('ssh_key_path', '').strip()
    password  = _decode_password(cfg.get('password_enc', ''))

    if key_path and os.path.exists(key_path):
        kw['key_filename'] = key_path
    elif password:
        kw['password'] = password
    else:
        return {'ok': False, 'hostname': hostname,
                'error': 'No SSH key or password configured',
                'files_pulled': 0}

    dest_dir = os.path.join(sar_drop_dir, hostname)
    os.makedirs(dest_dir, exist_ok=True)

    remote = cfg.get('remote_sar_path', '/var/log/sa')
    pulled = []
    errors = []

    try:
        ssh.connect(**kw)
        sftp = ssh.open_sftp()
        logger.info(f'SSH connected to {cfg["ssh_host"]} for {hostname}')

        try:
            remote_files = sftp.listdir_attr(remote)
        except Exception as e:
            sftp.close(); ssh.close()
            return {'ok': False, 'hostname': hostname,
                    'error': f'Cannot list {remote}: {e}', 'files_pulled': 0}

        for attr in remote_files:
            fname = attr.filename
            # Only sa01..sa31 binary SAR files
            if not (fname.startswith('sa') and
                    fname[2:].isdigit() and len(fname) == 4):
                continue

            file_mtime = datetime.fromtimestamp(attr.st_mtime)
            if since and file_mtime <= since:
                continue

            remote_path = f"{remote.rstrip('/')}/{fname}"
            local_path  = os.path.join(dest_dir, fname)

            try:
                sftp.get(remote_path, local_path)
                pulled.append(fname)
                logger.info(f'Pulled SAR: {hostname}/{fname} '
                            f'({file_mtime.strftime("%Y-%m-%d %H:%M")})')
            except Exception as e:
                errors.append(f'{fname}: {e}')
                logger.warning(f'Failed to pull {remote_path}: {e}')

        sftp.close()
    except Exception as e:
        return {'ok': False, 'hostname': hostname,
                'error': f'SSH error: {e}', 'files_pulled': 0}
    finally:
        try:
            ssh.close()
        except Exception:
            pass

    # Update last_pull_at
    if pulled:
        pg = _pg()
        try:
            with pg.cursor() as cur:
                cur.execute("""
                    UPDATE sar_ssh_connections
                    SET last_pull_at = NOW()
                    WHERE id = %s
                """, (conn_id,))
            pg.commit()
        finally:
            pg.close()

    logger.info(f'{hostname}: {len(pulled)} file(s) pulled, {len(errors)} error(s)')
    return {
        'ok':          True,
        'hostname':    hostname,
        'files_pulled': len(pulled),
        'file_list':   pulled,
        'errors':      errors,
        'error':       None
    }


def pull_all_servers(sar_drop_dir: str, since: datetime = None) -> list:
    """Pull SAR files from ALL enabled SSH connections."""
    connections = get_all_connections()
    enabled     = [c for c in connections if c.get('enabled')]
    results     = []
    for c in enabled:
        try:
            result = pull_sar_files(c['id'], sar_drop_dir, since)
            results.append(result)
        except Exception as e:
            logger.error(f'pull_all_servers [{c["hostname"]}]: {e}')
            results.append({'ok': False, 'hostname': c['hostname'], 'error': str(e)})
    return results
