# modules/oracle_live_query.py
# ============================================================
# AWR Insight Portal v3 — Live Oracle Query Engine
#
# Executes parameterised queries directly against Oracle via
# oracledb thin mode. Returns results as list of dicts for
# display in portal pages or Grafana via the portal API.
#
# Used by:
#   - PL/SQL Performance Analysis (scripts1/)
#   - Database System Study (oraclescript sections)
#   - Any future live-Oracle analysis feature
# ============================================================

import os
import sys
import logging

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))

from logger_utils import get_logger
logger = get_logger('oracle_live_query')


def _oracle_connect(cfg: dict):
    """Open oracledb thin connection from a connection config dict."""
    try:
        import oracledb
    except ImportError:
        raise ImportError('oracledb not installed. Run: pip install oracledb>=2.0')
    from modules.oracle_awr_fetcher import _decode_password
    return oracledb.connect(
        user=cfg['username'],
        password=_decode_password(cfg['password_enc']),
        dsn=f"{cfg['host']}:{cfg['port']}/{cfg['service_name']}"
    )


def run_query(cfg: dict, sql: str, params: dict = None) -> dict:
    """
    Execute one SQL statement and return all rows as list of dicts.
    Returns {ok, columns, rows, error, row_count}.
    """
    try:
        oc = _oracle_connect(cfg)
    except Exception as e:
        return {'ok': False, 'columns': [], 'rows': [], 'error': str(e), 'row_count': 0}

    try:
        cur = oc.cursor()
        if params:
            cur.execute(sql, params)
        else:
            cur.execute(sql)

        cols = [d[0].lower() for d in cur.description]
        rows = []
        for raw in cur.fetchall():
            row = {}
            for i, val in enumerate(raw):
                # Convert Oracle types to Python-native for JSON
                if val is None:
                    row[cols[i]] = None
                elif hasattr(val, 'read'):  # CLOB/LOB
                    row[cols[i]] = val.read()
                elif hasattr(val, 'strftime'):  # datetime
                    row[cols[i]] = val.strftime('%Y-%m-%d %H:%M:%S')
                elif hasattr(val, 'quantize'):  # Decimal
                    row[cols[i]] = float(val)
                else:
                    row[cols[i]] = val
            rows.append(row)

        return {
            'ok': True,
            'columns': cols,
            'rows': rows,
            'row_count': len(rows),
            'error': None
        }
    except Exception as e:
        logger.error(f'run_query failed: {e}')
        return {'ok': False, 'columns': [], 'rows': [], 'error': str(e), 'row_count': 0}
    finally:
        try:
            oc.close()
        except Exception:
            pass


def run_queries(cfg: dict, queries: list) -> list:
    """
    Run multiple queries in one connection.
    queries: list of {name, sql, params, description}
    Returns list of {name, description, ok, columns, rows, error, row_count}
    """
    results = []
    try:
        oc = _oracle_connect(cfg)
    except Exception as e:
        return [{'name': q.get('name', ''), 'ok': False,
                 'error': str(e), 'rows': [], 'columns': []}
                for q in queries]

    try:
        for q in queries:
            try:
                cur = oc.cursor()
                sql = q['sql']
                params = q.get('params') or {}
                if params:
                    cur.execute(sql, params)
                else:
                    cur.execute(sql)

                cols = [d[0].lower() for d in cur.description]
                rows = []
                for raw in cur.fetchall():
                    row = {}
                    for i, val in enumerate(raw):
                        if val is None:
                            row[cols[i]] = None
                        elif hasattr(val, 'read'):
                            row[cols[i]] = val.read()
                        elif hasattr(val, 'strftime'):
                            row[cols[i]] = val.strftime('%Y-%m-%d %H:%M:%S')
                        elif hasattr(val, 'quantize'):
                            row[cols[i]] = float(val)
                        else:
                            row[cols[i]] = val
                    rows.append(row)

                results.append({
                    'name':        q.get('name', ''),
                    'description': q.get('description', ''),
                    'ok':          True,
                    'columns':     cols,
                    'rows':        rows,
                    'row_count':   len(rows),
                    'error':       None
                })
            except Exception as e:
                logger.error(f'run_queries [{q.get("name")}]: {e}')
                results.append({
                    'name':        q.get('name', ''),
                    'description': q.get('description', ''),
                    'ok':          False,
                    'columns':     [],
                    'rows':        [],
                    'row_count':   0,
                    'error':       str(e)
                })
    finally:
        try:
            oc.close()
        except Exception:
            pass

    return results
