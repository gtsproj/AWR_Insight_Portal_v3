# modules/awr_unc_fetcher.py
# ============================================================
# AWR Insight Portal v3 — Multi-Database AWR UNC Path Fetcher
#
# Replaces the single global awr_network_path setting with a
# per-database connection manager, mirroring the pattern used by
# modules/sar_ssh_fetcher.py (SAR SSH pull).
#
# How it works:
#   1. Each row in awr_unc_connections is one Oracle database,
#      with its own UNC path (no shared root / subfolder convention
#      required — e.g. \\server\share\ORCL_awr, \\server2\share\NEODB_awr)
#   2. On each pull, new *.html files in that UNC path (modified
#      after last_pull_at) are copied to awr_reports/<db_name>/
#   3. AWR queue processor / watcher picks them up from there,
#      exactly as it does for local-folder and single-UNC sources
#
# Optional username/password is provided for environments where the
# UNC share requires explicit authentication (net use / mapped
# credentials) rather than the portal service account's own access.
#
# Prerequisites: none beyond filesystem access to the UNC path from
# the portal server (same requirement as the existing single-path
# 'network' source type).
# ============================================================

import os
import sys
import shutil
import base64
import logging
from datetime import datetime
from pathlib import Path
from typing import Optional

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))

from logger_utils import get_logger
logger = get_logger('awr_unc_fetcher')


# ── Password helpers (same convention as sar_ssh_fetcher) ─────────────────────
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
    """Return all AWR UNC connections (no passwords)."""
    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, db_name, display_name, unc_path, username,
                       pull_interval_hrs, enabled, last_pull_at,
                       added_at, added_by
                FROM awr_unc_connections
                ORDER BY db_name
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
                SELECT id, db_name, display_name, unc_path, username,
                       password_enc, pull_interval_hrs, enabled, last_pull_at
                FROM awr_unc_connections
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
    """Insert or update an AWR UNC connection. Returns {ok, id, error}."""
    db_name           = (data.get('db_name') or '').strip().upper()
    display_name      = (data.get('display_name') or db_name).strip()
    unc_path          = (data.get('unc_path') or '').strip()
    username          = (data.get('username') or '').strip()
    password          = (data.get('password') or '').strip()
    pull_interval_hrs = float(data.get('pull_interval_hrs') or 1)
    enabled           = bool(data.get('enabled', True))

    if not db_name:
        return {'ok': False, 'error': 'DB Name is required'}
    if not unc_path:
        return {'ok': False, 'error': 'UNC Path is required'}
    if not (unc_path.startswith('\\\\') or unc_path.startswith('//')):
        return {'ok': False, 'error': 'UNC Path must start with \\\\server\\share'}

    if password:
        password_enc = _encode_password(password)
    else:
        conn = _pg()
        try:
            with conn.cursor() as cur:
                cur.execute('SELECT password_enc FROM awr_unc_connections WHERE db_name=%s',
                            (db_name,))
                row = cur.fetchone()
                password_enc = row[0] if row else ''
        finally:
            conn.close()

    conn = _pg()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO awr_unc_connections
                    (db_name, display_name, unc_path, username, password_enc,
                     pull_interval_hrs, enabled, added_by)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (db_name) DO UPDATE SET
                    display_name      = EXCLUDED.display_name,
                    unc_path          = EXCLUDED.unc_path,
                    username          = EXCLUDED.username,
                    password_enc      = CASE
                        WHEN EXCLUDED.password_enc != ''
                        THEN EXCLUDED.password_enc
                        ELSE awr_unc_connections.password_enc END,
                    pull_interval_hrs = EXCLUDED.pull_interval_hrs,
                    enabled           = EXCLUDED.enabled,
                    added_by          = EXCLUDED.added_by
                RETURNING id
            """, (db_name, display_name, unc_path, username, password_enc,
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
            cur.execute('DELETE FROM awr_unc_connections WHERE id=%s', (conn_id,))
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
                UPDATE awr_unc_connections SET last_pull_at = NOW()
                WHERE id = %s
            """, (conn_id,))
        pg.commit()
    except Exception as e:
        logger.error(f'_update_last_pull: {e}')
    finally:
        pg.close()


# ── Connectivity test ─────────────────────────────────────────────────────────
def test_connection(conn_id: int) -> dict:
    """
    Verify the UNC path is reachable and count AWR HTML files in it.
    Returns {ok, message, html_count}.
    """
    cfg = get_connection_by_id(conn_id)
    if not cfg:
        return {'ok': False, 'message': f'Connection {conn_id} not found'}

    unc_path = cfg.get('unc_path', '')
    try:
        src = Path(unc_path)
        if not src.exists():
            return {'ok': False,
                     'message': f'UNC path not accessible: {unc_path}. '
                                f'Check the path, share permissions, and that '
                                f'the portal service account has read access.'}
        if not src.is_dir():
            return {'ok': False, 'message': f'UNC path is not a folder: {unc_path}'}

        html_files = list(src.rglob('*.html'))
        return {
            'ok': True,
            'message': (f'Connected to {unc_path}. '
                        f'{len(html_files)} HTML report(s) found.'),
            'html_count': len(html_files)
        }
    except Exception as e:
        return {'ok': False, 'message': f'Test failed: {e}'}


# ── Fetch — core function ─────────────────────────────────────────────────────
def fetch_new_files(conn_id: int, awr_local_drop: str) -> dict:
    """
    Copy new AWR HTML files from one database's UNC path to
    awr_reports/<db_name>/.

    Only copies *.html files modified after last_pull_at (or all
    files on the first-ever pull for this connection).

    Returns {ok, db_name, files_pulled, file_list, error}.
    """
    cfg = get_connection_by_id(conn_id)
    if not cfg:
        return {'ok': False, 'error': f'Connection {conn_id} not found',
                'db_name': 'unknown', 'files_pulled': 0, 'file_list': []}
    if not cfg.get('enabled'):
        return {'ok': False, 'error': 'Connection disabled',
                'db_name': cfg.get('db_name', '?'), 'files_pulled': 0, 'file_list': []}

    db_name  = cfg['db_name']
    unc_path = cfg.get('unc_path', '')
    since    = None
    if cfg.get('last_pull_at'):
        try:
            since = datetime.strptime(cfg['last_pull_at'], '%Y-%m-%d %H:%M:%S')
        except (ValueError, TypeError):
            since = None

    try:
        src_root = Path(unc_path)
        if not src_root.exists():
            return {'ok': False, 'db_name': db_name, 'files_pulled': 0,
                     'file_list': [],
                     'error': f'UNC path not accessible: {unc_path}'}

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
                    logger.info(f'Fetched AWR ({db_name}): {html_file.name}')

            except Exception as e:
                logger.warning(f'Failed to copy {html_file}: {e}')

        _update_last_pull(conn_id)

        return {
            'ok': True,
            'db_name': db_name,
            'files_pulled': len(fetched),
            'file_list': fetched,
            'error': None
        }

    except Exception as e:
        logger.error(f'fetch_new_files [{db_name}]: {e}')
        return {'ok': False, 'db_name': db_name, 'files_pulled': 0,
                 'file_list': [], 'error': str(e)}


def pull_all_connections(awr_local_drop: str) -> list:
    """Run fetch_new_files for all enabled AWR UNC connections."""
    connections = get_all_connections()
    enabled     = [c for c in connections if c.get('enabled')]
    results     = []
    for c in enabled:
        try:
            result = fetch_new_files(c['id'], awr_local_drop)
            results.append(result)
        except Exception as e:
            logger.error(f'pull_all_connections [{c["db_name"]}]: {e}')
            results.append({'ok': False, 'db_name': c['db_name'], 'error': str(e),
                             'files_pulled': 0, 'file_list': []})
    return results
