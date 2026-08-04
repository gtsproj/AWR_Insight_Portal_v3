# modules/awr_remote_fetcher.py
# ============================================================
# AWR Insight Portal v3 — AWR Remote Source Fetcher
# (two-tier: remote servers + per-database subpaths)
#
# Supports two connection types per server:
#   unc — Windows network share, authenticated via `net use`
#         (root_path is a UNC prefix, e.g. \\host\share\awr_reports)
#   ssh — Linux server, authenticated via paramiko SFTP
#         (root_path is a remote directory, e.g. /opt/oracle/awr_reports)
#
# One server (host + credentials) can host many databases — each
# database is just a subfolder name under the server's root_path.
# Only the subfolder differs per database; IP/user/password are
# shared at the server level.
#
#   Full remote location = server.root_path + '/' + db.remote_subpath
#
# Prerequisites:
#   - unc: none beyond filesystem access from the portal server
#   - ssh: pip install paramiko
# ============================================================

import os
import sys
import re
import shutil
import base64
import logging
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Optional

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))

from logger_utils import get_logger
logger = get_logger('awr_remote_fetcher')


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


# ══════════════════════════════════════════════════════════════════
# SERVER CRUD (Tier 1 — shared connection/credentials)
# ══════════════════════════════════════════════════════════════════

def get_all_servers() -> list:
    """Return all remote servers (no passwords)."""
    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, display_name, connection_type, host, root_path,
                       ssh_port, ssh_key_path, username, auto_discover,
                       pull_interval_hrs, enabled, last_pull_at,
                       added_at, added_by
                FROM awr_remote_servers
                ORDER BY display_name
            """)
            cols = [d[0] for d in cur.description]
            rows = []
            for row in cur.fetchall():
                d = dict(zip(cols, row))
                if d.get('added_at'):
                    d['added_at'] = d['added_at'].strftime('%Y-%m-%d %H:%M:%S')
                if d.get('last_pull_at'):
                    d['last_pull_at'] = d['last_pull_at'].strftime('%Y-%m-%d %H:%M:%S')
                if d.get('pull_interval_hrs') is not None:
                    d['pull_interval_hrs'] = float(d['pull_interval_hrs'])
                rows.append(d)
            return rows
    finally:
        conn.close()


def get_server_by_id(server_id: int) -> Optional[dict]:
    """Return one server including password_enc."""
    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, display_name, connection_type, host, root_path,
                       ssh_port, ssh_key_path, username, password_enc,
                       auto_discover, pull_interval_hrs, enabled, last_pull_at
                FROM awr_remote_servers
                WHERE id = %s
            """, (server_id,))
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


def save_server(data: dict, added_by: str = 'admin') -> dict:
    """Insert or update a remote server. Returns {ok, id, error}."""
    display_name      = (data.get('display_name') or '').strip()
    connection_type   = (data.get('connection_type') or 'unc').strip().lower()
    host              = (data.get('host') or '').strip()
    root_path         = (data.get('root_path') or '').strip()
    ssh_port          = int(data.get('ssh_port') or 22)
    ssh_key_path      = (data.get('ssh_key_path') or '').strip()
    username          = (data.get('username') or '').strip()
    password          = (data.get('password') or '').strip()
    auto_discover     = bool(data.get('auto_discover', True))
    pull_interval_hrs = float(data.get('pull_interval_hrs') or 1)
    enabled           = bool(data.get('enabled', True))

    if not display_name:
        return {'ok': False, 'error': 'Display Name is required'}
    if connection_type not in ('unc', 'ssh'):
        return {'ok': False, 'error': "connection_type must be 'unc' or 'ssh'"}
    if not host:
        return {'ok': False, 'error': 'Host is required'}
    if not root_path:
        return {'ok': False, 'error': 'Root Path is required'}
    if connection_type == 'unc' and not (root_path.startswith('\\\\') or root_path.startswith('//')):
        return {'ok': False, 'error': 'Root Path must start with \\\\server\\share for UNC servers'}
    if connection_type == 'ssh' and not username and not ssh_key_path:
        return {'ok': False, 'error': 'SSH servers require a username (with password or key file)'}

    if password:
        password_enc = _encode_password(password)
    else:
        conn = _pg()
        try:
            with conn.cursor() as cur:
                cur.execute('SELECT password_enc FROM awr_remote_servers WHERE display_name=%s',
                            (display_name,))
                row = cur.fetchone()
                password_enc = row[0] if row else ''
        finally:
            conn.close()

    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO awr_remote_servers
                    (display_name, connection_type, host, root_path, ssh_port,
                     ssh_key_path, username, password_enc, auto_discover,
                     pull_interval_hrs, enabled, added_by)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (display_name) DO UPDATE SET
                    connection_type    = EXCLUDED.connection_type,
                    host               = EXCLUDED.host,
                    root_path          = EXCLUDED.root_path,
                    ssh_port           = EXCLUDED.ssh_port,
                    ssh_key_path       = EXCLUDED.ssh_key_path,
                    username           = EXCLUDED.username,
                    password_enc       = CASE
                        WHEN EXCLUDED.password_enc != ''
                        THEN EXCLUDED.password_enc
                        ELSE awr_remote_servers.password_enc END,
                    auto_discover      = EXCLUDED.auto_discover,
                    pull_interval_hrs  = EXCLUDED.pull_interval_hrs,
                    enabled            = EXCLUDED.enabled,
                    added_by           = EXCLUDED.added_by
                RETURNING id
            """, (display_name, connection_type, host, root_path, ssh_port,
                  ssh_key_path, username, password_enc, auto_discover,
                  pull_interval_hrs, enabled, added_by))
            new_id = cur.fetchone()[0]
        conn.commit()
        return {'ok': True, 'id': new_id}
    except Exception as e:
        logger.error(f'save_server: {e}')
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def delete_server(server_id: int) -> dict:
    """Delete a server and (via FK cascade) all its database paths."""
    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute('DELETE FROM awr_remote_servers WHERE id=%s', (server_id,))
        conn.commit()
        return {'ok': True}
    except Exception as e:
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def _update_server_last_pull(server_id: int):
    pg = _pg()
    try:
        with pg.cursor() as cur:
            cur.execute("""
                UPDATE awr_remote_servers SET last_pull_at = NOW()
                WHERE id = %s
            """, (server_id,))
        pg.commit()
    except Exception as e:
        logger.error(f'_update_server_last_pull: {e}')
    finally:
        pg.close()


# ══════════════════════════════════════════════════════════════════
# DATABASE PATH CRUD (Tier 2 — per-database subfolder)
# ══════════════════════════════════════════════════════════════════

def get_all_db_paths() -> list:
    """Return all database paths, joined with their server's display info."""
    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT p.id, p.server_id, p.db_name, p.display_name,
                       p.remote_subpath, p.pull_interval_hrs, p.enabled,
                       p.last_pull_at, s.display_name AS server_name,
                       s.connection_type, s.host, s.enabled AS server_enabled,
                       s.auto_discover
                FROM awr_remote_db_paths p
                JOIN awr_remote_servers s ON s.id = p.server_id
                ORDER BY s.display_name, p.db_name
            """)
            cols = [d[0] for d in cur.description]
            rows = []
            for row in cur.fetchall():
                d = dict(zip(cols, row))
                if d.get('last_pull_at'):
                    d['last_pull_at'] = d['last_pull_at'].strftime('%Y-%m-%d %H:%M:%S')
                if d.get('pull_interval_hrs') is not None:
                    d['pull_interval_hrs'] = float(d['pull_interval_hrs'])
                rows.append(d)
            return rows
    finally:
        conn.close()


def get_db_path_by_id(path_id: int) -> Optional[dict]:
    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, server_id, db_name, display_name, remote_subpath,
                       pull_interval_hrs, enabled, last_pull_at
                FROM awr_remote_db_paths
                WHERE id = %s
            """, (path_id,))
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


def save_db_path(data: dict, added_by: str = 'admin') -> dict:
    """Insert or update a database path under a server. Returns {ok, id, error}."""
    server_id         = data.get('server_id')
    db_name           = (data.get('db_name') or '').strip().upper()
    display_name      = (data.get('display_name') or db_name).strip()
    remote_subpath    = (data.get('remote_subpath') or '').strip().strip('\\/')
    pull_interval_hrs = float(data.get('pull_interval_hrs') or 1)
    enabled           = bool(data.get('enabled', True))

    if not server_id:
        return {'ok': False, 'error': 'Server is required'}
    if not db_name:
        return {'ok': False, 'error': 'DB Name is required'}
    if not remote_subpath:
        return {'ok': False, 'error': 'Remote Subpath is required'}

    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO awr_remote_db_paths
                    (server_id, db_name, display_name, remote_subpath,
                     pull_interval_hrs, enabled, added_by)
                VALUES (%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (server_id, db_name) DO UPDATE SET
                    display_name      = EXCLUDED.display_name,
                    remote_subpath     = EXCLUDED.remote_subpath,
                    pull_interval_hrs = EXCLUDED.pull_interval_hrs,
                    enabled           = EXCLUDED.enabled,
                    added_by          = EXCLUDED.added_by
                RETURNING id
            """, (server_id, db_name, display_name, remote_subpath,
                  pull_interval_hrs, enabled, added_by))
            new_id = cur.fetchone()[0]
        conn.commit()
        return {'ok': True, 'id': new_id}
    except Exception as e:
        logger.error(f'save_db_path: {e}')
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def delete_db_path(path_id: int) -> dict:
    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute('DELETE FROM awr_remote_db_paths WHERE id=%s', (path_id,))
        conn.commit()
        return {'ok': True}
    except Exception as e:
        return {'ok': False, 'error': str(e)}
    finally:
        conn.close()


def _update_last_pull(path_id: int):
    pg = _pg()
    try:
        with pg.cursor() as cur:
            cur.execute("""
                UPDATE awr_remote_db_paths SET last_pull_at = NOW()
                WHERE id = %s
            """, (path_id,))
        pg.commit()
    except Exception as e:
        logger.error(f'_update_last_pull: {e}')
    finally:
        pg.close()


# ══════════════════════════════════════════════════════════════════
# UNC (Windows) helpers
# ══════════════════════════════════════════════════════════════════

def _share_root(unc_path: str) -> Optional[str]:
    """Extract \\\\server\\share from a full UNC path — net use
    authenticates against the share root, not a sub-path."""
    m = re.match(r'^(\\\\[^\\]+\\[^\\]+)', unc_path.strip())
    return m.group(1) if m else None


def _connect_unc_share(root_path: str, username: str, password: str) -> dict:
    """Authenticate to a UNC share via `net use`. No-op if no username set."""
    if not username:
        return {'ok': True, 'connected': False, 'share_root': None, 'error': None}
    if os.name != 'nt':
        return {'ok': False, 'connected': False, 'share_root': None,
                 'error': 'Credentialed UNC access requires Windows (net use). '
                          'This portal server is not Windows.'}
    share_root = _share_root(root_path)
    if not share_root:
        return {'ok': False, 'connected': False, 'share_root': None,
                 'error': f'Could not parse share root from UNC path: {root_path}'}
    try:
        result = subprocess.run(
            ['net', 'use', share_root, password, f'/user:{username}'],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            err = (result.stderr or result.stdout or '').strip()
            return {'ok': False, 'connected': False, 'share_root': share_root,
                     'error': f'net use failed for {share_root}: {err}'}
        return {'ok': True, 'connected': True, 'share_root': share_root, 'error': None}
    except Exception as e:
        return {'ok': False, 'connected': False, 'share_root': share_root,
                 'error': f'net use error: {e}'}


def _disconnect_unc_share(share_root: Optional[str]):
    if not share_root or os.name != 'nt':
        return
    try:
        subprocess.run(['net', 'use', share_root, '/delete', '/y'],
                        capture_output=True, text=True, timeout=15)
    except Exception as e:
        logger.warning(f'Could not disconnect share {share_root}: {e}')


# ══════════════════════════════════════════════════════════════════
# SSH (Linux) helpers
# ══════════════════════════════════════════════════════════════════

def _ssh_connect(server: dict):
    """Open a paramiko SSH connection using a server's credentials."""
    try:
        import paramiko
    except ImportError:
        raise ImportError('paramiko not installed. Run: pip install paramiko')

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    kw = {
        'hostname': server['host'],
        'port':     int(server.get('ssh_port') or 22),
        'username': server.get('username') or '',
        'timeout':  30
    }
    key_path = (server.get('ssh_key_path') or '').strip()
    password = _decode_password(server.get('password_enc') or '')

    if key_path and os.path.exists(key_path):
        kw['key_filename'] = key_path
    elif password:
        kw['password'] = password
    else:
        raise ValueError('No SSH key file or password configured for this server.')

    ssh.connect(**kw)
    return ssh


# ══════════════════════════════════════════════════════════════════
# Connectivity test — works for either connection type
# ══════════════════════════════════════════════════════════════════

def test_server(server_id: int) -> dict:
    """Test connectivity to a remote server's root_path (UNC or SSH)."""
    server = get_server_by_id(server_id)
    if not server:
        return {'ok': False, 'message': f'Server {server_id} not found'}

    if server['connection_type'] == 'unc':
        username = server.get('username') or ''
        password = _decode_password(server.get('password_enc') or '')
        conn_result = _connect_unc_share(server['root_path'], username, password)
        if not conn_result['ok']:
            return {'ok': False, 'message': conn_result['error']}
        try:
            root = Path(server['root_path'])
            if not root.exists():
                return {'ok': False,
                         'message': f'Root path not accessible: {server["root_path"]}'}
            subfolders = [p.name for p in root.iterdir() if p.is_dir()]
            auth_note = f' (authenticated as {username})' if conn_result['connected'] else ''
            return {'ok': True,
                     'message': (f'Connected to {server["root_path"]}{auth_note}. '
                                 f'{len(subfolders)} subfolder(s) found.'),
                     'subfolders': subfolders[:20]}
        except Exception as e:
            return {'ok': False, 'message': f'Test failed: {e}'}
        finally:
            _disconnect_unc_share(conn_result.get('share_root'))

    else:  # ssh
        try:
            ssh = _ssh_connect(server)
        except ImportError as e:
            return {'ok': False, 'message': str(e)}
        except Exception as e:
            return {'ok': False, 'message': f'SSH connection failed: {e}'}
        try:
            sftp = ssh.open_sftp()
            try:
                entries = sftp.listdir(server['root_path'])
            except IOError:
                return {'ok': False,
                         'message': f'Root path not found on remote server: {server["root_path"]}'}
            return {'ok': True,
                     'message': (f'Connected to {server["host"]} via SSH as '
                                 f'{server.get("username", "?")}. '
                                 f'{len(entries)} item(s) found under {server["root_path"]}.'),
                     'subfolders': entries[:20]}
        except Exception as e:
            return {'ok': False, 'message': f'SFTP test failed: {e}'}
        finally:
            try:
                ssh.close()
            except Exception:
                pass


# ══════════════════════════════════════════════════════════════════
# Fetch — core function, dispatches by connection type
# ══════════════════════════════════════════════════════════════════

def fetch_new_files(path_id: int, awr_local_drop: str) -> dict:
    """
    Copy new AWR HTML files for one database path into
    awr_reports/<db_name>/. Dispatches to UNC or SSH depending on
    the parent server's connection_type.

    Returns {ok, db_name, files_pulled, file_list, error}.
    """
    dp = get_db_path_by_id(path_id)
    if not dp:
        return {'ok': False, 'error': f'DB path {path_id} not found',
                 'db_name': 'unknown', 'files_pulled': 0, 'file_list': []}
    if not dp.get('enabled'):
        return {'ok': False, 'error': 'DB path disabled',
                 'db_name': dp.get('db_name', '?'), 'files_pulled': 0, 'file_list': []}

    server = get_server_by_id(dp['server_id'])
    if not server:
        return {'ok': False, 'error': 'Parent server not found',
                 'db_name': dp['db_name'], 'files_pulled': 0, 'file_list': []}
    if not server.get('enabled'):
        return {'ok': False, 'error': 'Parent server disabled',
                 'db_name': dp['db_name'], 'files_pulled': 0, 'file_list': []}

    since = None
    if dp.get('last_pull_at'):
        try:
            since = datetime.strptime(dp['last_pull_at'], '%Y-%m-%d %H:%M:%S')
        except (ValueError, TypeError):
            since = None

    if server['connection_type'] == 'unc':
        result = _fetch_unc(server, dp, awr_local_drop, since)
    else:
        result = _fetch_ssh(server, dp, awr_local_drop, since)

    if result.get('ok'):
        _update_last_pull(path_id)
    return result


def _fetch_unc(server: dict, dp: dict, awr_local_drop: str, since) -> dict:
    db_name  = dp['db_name']
    full_path = os.path.join(server['root_path'], dp['remote_subpath'])
    username = server.get('username') or ''
    password = _decode_password(server.get('password_enc') or '')

    conn_result = _connect_unc_share(server['root_path'], username, password)
    if not conn_result['ok']:
        return {'ok': False, 'db_name': db_name, 'files_pulled': 0,
                 'file_list': [], 'error': conn_result['error']}

    try:
        src_root = Path(full_path)
        if not src_root.exists():
            return {'ok': False, 'db_name': db_name, 'files_pulled': 0,
                     'file_list': [], 'error': f'Path not accessible: {full_path}'}

        dest_dir = Path(awr_local_drop) / db_name
        dest_dir.mkdir(parents=True, exist_ok=True)

        fetched = []
        for html_file in src_root.rglob('*.html'):
            try:
                file_mtime = datetime.fromtimestamp(html_file.stat().st_mtime)
                if since and file_mtime <= since:
                    continue
                dest = dest_dir / html_file.name
                if not dest.exists():
                    shutil.copy2(str(html_file), str(dest))
                    fetched.append(html_file.name)
                    logger.info(f'Fetched AWR ({db_name}) via UNC: {html_file.name}')
            except Exception as e:
                logger.warning(f'Failed to copy {html_file}: {e}')

        return {'ok': True, 'db_name': db_name, 'files_pulled': len(fetched),
                 'file_list': fetched, 'error': None}
    except Exception as e:
        logger.error(f'_fetch_unc [{db_name}]: {e}')
        return {'ok': False, 'db_name': db_name, 'files_pulled': 0,
                 'file_list': [], 'error': str(e)}
    finally:
        _disconnect_unc_share(conn_result.get('share_root'))


def _fetch_ssh(server: dict, dp: dict, awr_local_drop: str, since) -> dict:
    db_name   = dp['db_name']
    remote_dir = server['root_path'].rstrip('/') + '/' + dp['remote_subpath'].strip('/')

    try:
        ssh = _ssh_connect(server)
    except Exception as e:
        return {'ok': False, 'db_name': db_name, 'files_pulled': 0,
                 'file_list': [], 'error': f'SSH connect failed: {e}'}

    try:
        sftp = ssh.open_sftp()
        try:
            entries = sftp.listdir_attr(remote_dir)
        except IOError:
            return {'ok': False, 'db_name': db_name, 'files_pulled': 0,
                     'file_list': [], 'error': f'Remote path not found: {remote_dir}'}

        dest_dir = Path(awr_local_drop) / db_name
        dest_dir.mkdir(parents=True, exist_ok=True)

        fetched = []
        for entry in entries:
            if not entry.filename.lower().endswith('.html'):
                continue
            file_mtime = datetime.fromtimestamp(entry.st_mtime)
            if since and file_mtime <= since:
                continue

            dest = dest_dir / entry.filename
            if not dest.exists():
                remote_file = remote_dir + '/' + entry.filename
                try:
                    sftp.get(remote_file, str(dest))
                    fetched.append(entry.filename)
                    logger.info(f'Fetched AWR ({db_name}) via SSH: {entry.filename}')
                except Exception as e:
                    logger.warning(f'Failed to download {remote_file}: {e}')

        return {'ok': True, 'db_name': db_name, 'files_pulled': len(fetched),
                 'file_list': fetched, 'error': None}
    except Exception as e:
        logger.error(f'_fetch_ssh [{db_name}]: {e}')
        return {'ok': False, 'db_name': db_name, 'files_pulled': 0,
                 'file_list': [], 'error': str(e)}
    finally:
        try:
            ssh.close()
        except Exception:
            pass


def pull_all_paths(awr_local_drop: str) -> list:
    """Run fetch_new_files for all enabled database paths on enabled servers."""
    paths   = get_all_db_paths()
    enabled = [p for p in paths if p.get('enabled') and p.get('server_enabled')]
    results = []
    for p in enabled:
        try:
            result = fetch_new_files(p['id'], awr_local_drop)
            results.append(result)
        except Exception as e:
            logger.error(f'pull_all_paths [{p["db_name"]}]: {e}')
            results.append({'ok': False, 'db_name': p['db_name'], 'error': str(e),
                             'files_pulled': 0, 'file_list': []})
    return results


# ══════════════════════════════════════════════════════════════════
# AUTO-DISCOVER — single login, scan every subfolder under root_path
# as a database. This is the primary/simple mode (auto_discover=TRUE).
# ══════════════════════════════════════════════════════════════════

def fetch_server_databases(server_id: int, awr_local_drop: str) -> dict:
    """
    Log in to a server ONCE, scan every immediate subfolder under its
    root_path, and copy new *.html files from each into
    awr_reports/<subfolder_name>/ — no per-database config needed.

    Returns {ok, server_name, databases_found, files_pulled, results, error}.
    """
    server = get_server_by_id(server_id)
    if not server:
        return {'ok': False, 'error': f'Server {server_id} not found',
                 'server_name': 'unknown', 'databases_found': 0,
                 'files_pulled': 0, 'results': []}
    if not server.get('enabled'):
        return {'ok': False, 'error': 'Server disabled',
                 'server_name': server.get('display_name', '?'),
                 'databases_found': 0, 'files_pulled': 0, 'results': []}

    since = None
    if server.get('last_pull_at'):
        try:
            since = datetime.strptime(server['last_pull_at'], '%Y-%m-%d %H:%M:%S')
        except (ValueError, TypeError):
            since = None

    if server['connection_type'] == 'unc':
        result = _discover_unc(server, awr_local_drop, since)
    else:
        result = _discover_ssh(server, awr_local_drop, since)

    if result.get('ok'):
        _update_server_last_pull(server_id)
    return result


def _discover_unc(server: dict, awr_local_drop: str, since) -> dict:
    server_name = server['display_name']
    username    = server.get('username') or ''
    password    = _decode_password(server.get('password_enc') or '')

    conn_result = _connect_unc_share(server['root_path'], username, password)
    if not conn_result['ok']:
        return {'ok': False, 'server_name': server_name, 'databases_found': 0,
                 'files_pulled': 0, 'results': [], 'error': conn_result['error']}

    try:
        root = Path(server['root_path'])
        if not root.exists():
            return {'ok': False, 'server_name': server_name, 'databases_found': 0,
                     'files_pulled': 0, 'results': [],
                     'error': f'Root path not accessible: {server["root_path"]}'}

        subfolders = [p for p in root.iterdir() if p.is_dir()]
        results, total_files = [], 0

        for sub in subfolders:
            db_name = sub.name
            try:
                dest_dir = Path(awr_local_drop) / db_name
                dest_dir.mkdir(parents=True, exist_ok=True)

                fetched = []
                for html_file in sub.rglob('*.html'):
                    file_mtime = datetime.fromtimestamp(html_file.stat().st_mtime)
                    if since and file_mtime <= since:
                        continue
                    dest = dest_dir / html_file.name
                    if not dest.exists():
                        shutil.copy2(str(html_file), str(dest))
                        fetched.append(html_file.name)
                        logger.info(f'Fetched AWR ({db_name}) via UNC auto-discover: {html_file.name}')

                total_files += len(fetched)
                results.append({'ok': True, 'db_name': db_name,
                                 'files_pulled': len(fetched), 'file_list': fetched})
            except Exception as e:
                logger.warning(f'_discover_unc [{db_name}]: {e}')
                results.append({'ok': False, 'db_name': db_name, 'error': str(e),
                                 'files_pulled': 0, 'file_list': []})

        return {'ok': True, 'server_name': server_name,
                 'databases_found': len(subfolders), 'files_pulled': total_files,
                 'results': results, 'error': None}
    except Exception as e:
        logger.error(f'_discover_unc [{server_name}]: {e}')
        return {'ok': False, 'server_name': server_name, 'databases_found': 0,
                 'files_pulled': 0, 'results': [], 'error': str(e)}
    finally:
        _disconnect_unc_share(conn_result.get('share_root'))


def _discover_ssh(server: dict, awr_local_drop: str, since) -> dict:
    server_name = server['display_name']
    root_path   = server['root_path'].rstrip('/')

    try:
        ssh = _ssh_connect(server)
    except Exception as e:
        return {'ok': False, 'server_name': server_name, 'databases_found': 0,
                 'files_pulled': 0, 'results': [], 'error': f'SSH connect failed: {e}'}

    try:
        sftp = ssh.open_sftp()
        try:
            import stat as _stat
            entries = sftp.listdir_attr(root_path)
            subfolders = [e.filename for e in entries if _stat.S_ISDIR(e.st_mode)]
        except IOError:
            return {'ok': False, 'server_name': server_name, 'databases_found': 0,
                     'files_pulled': 0, 'results': [],
                     'error': f'Root path not found on remote server: {root_path}'}

        results, total_files = [], 0

        for db_name in subfolders:
            remote_dir = root_path + '/' + db_name
            try:
                dest_dir = Path(awr_local_drop) / db_name
                dest_dir.mkdir(parents=True, exist_ok=True)

                fetched = []
                for entry in sftp.listdir_attr(remote_dir):
                    if not entry.filename.lower().endswith('.html'):
                        continue
                    file_mtime = datetime.fromtimestamp(entry.st_mtime)
                    if since and file_mtime <= since:
                        continue
                    dest = dest_dir / entry.filename
                    if not dest.exists():
                        remote_file = remote_dir + '/' + entry.filename
                        try:
                            sftp.get(remote_file, str(dest))
                            fetched.append(entry.filename)
                            logger.info(f'Fetched AWR ({db_name}) via SSH auto-discover: {entry.filename}')
                        except Exception as e:
                            logger.warning(f'Failed to download {remote_file}: {e}')

                total_files += len(fetched)
                results.append({'ok': True, 'db_name': db_name,
                                 'files_pulled': len(fetched), 'file_list': fetched})
            except Exception as e:
                logger.warning(f'_discover_ssh [{db_name}]: {e}')
                results.append({'ok': False, 'db_name': db_name, 'error': str(e),
                                 'files_pulled': 0, 'file_list': []})

        return {'ok': True, 'server_name': server_name,
                 'databases_found': len(subfolders), 'files_pulled': total_files,
                 'results': results, 'error': None}
    except Exception as e:
        logger.error(f'_discover_ssh [{server_name}]: {e}')
        return {'ok': False, 'server_name': server_name, 'databases_found': 0,
                 'files_pulled': 0, 'results': [], 'error': str(e)}
    finally:
        try:
            ssh.close()
        except Exception:
            pass


def pull_all_auto_servers(awr_local_drop: str) -> list:
    """Run fetch_server_databases for every enabled server with auto_discover=TRUE."""
    servers = get_all_servers()
    enabled = [s for s in servers if s.get('enabled') and s.get('auto_discover')]
    results = []
    for s in enabled:
        try:
            results.append(fetch_server_databases(s['id'], awr_local_drop))
        except Exception as e:
            logger.error(f'pull_all_auto_servers [{s["display_name"]}]: {e}')
            results.append({'ok': False, 'server_name': s['display_name'], 'error': str(e),
                             'databases_found': 0, 'files_pulled': 0, 'results': []})
    return results

