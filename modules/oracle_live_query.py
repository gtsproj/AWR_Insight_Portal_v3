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

# ── Query timeout ────────────────────────────────────────────────────
# Every live query through this module gets a hard timeout: if it
# doesn't return within QUERY_TIMEOUT_MS, oracledb's call_timeout
# mechanism actively interrupts the in-progress server-side call (an
# OCI-level break/cancel -- this genuinely stops the database from
# continuing to do the work, not just a client-side "give up waiting"
# that would leave an expensive query still running server-side and
# consuming resources in the background). Configurable via
# config/settings.yaml -> oracle_live_query.query_timeout_ms, default
# 5000ms per Ganesh's requirement.
#
# Once call_timeout fires, oracledb documents the connection may be
# left in an unusable state -- so run_queries() below does not keep
# using the same connection for the rest of a batch after a timeout;
# it stops that batch there rather than risk unpredictable behavior
# from further calls on a connection that may already be broken.
try:
    from config_loader import load_config
    _cfg = load_config() or {}
except Exception:
    _cfg = {}
QUERY_TIMEOUT_MS = int(_cfg.get("oracle_live_query", {}).get("query_timeout_ms", 5000))


def _oracle_connect(cfg: dict, timeout_ms: int = None):
    """Open oracledb thin connection from a connection config dict,
    with call_timeout applied so no query on this connection can run
    unbounded against the customer's database."""
    try:
        import oracledb
    except ImportError:
        raise ImportError('oracledb not installed. Run: pip install oracledb>=2.0')
    from modules.oracle_awr_fetcher import _decode_password
    oc = oracledb.connect(
        user=cfg['username'],
        password=_decode_password(cfg['password_enc']),
        dsn=f"{cfg['host']}:{cfg['port']}/{cfg['service_name']}"
    )
    oc.call_timeout = timeout_ms if timeout_ms is not None else QUERY_TIMEOUT_MS
    return oc


def _is_timeout_error(e: Exception) -> bool:
    """oracledb raises a DPY-4011/DPY-4024-style error (exact code can
    vary slightly by oracledb version) when call_timeout fires, or the
    underlying ORA-03156 'OCI call timeout expired' surfaces from the
    server side. Matched on message text rather than a specific
    exception class, since this hasn't been verified against a live
    oracledb version in this environment -- worth confirming this
    still matches once tested against your actual oracledb version,
    and tightening to the exact exception class if so."""
    msg = str(e).upper()
    return ('DPY-4011' in msg or 'DPY-4024' in msg or 'ORA-03156' in msg
            or 'TIMEOUT' in msg)


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
        if _is_timeout_error(e):
            logger.error(f'run_query TIMEOUT after {QUERY_TIMEOUT_MS}ms: {e}')
            return {'ok': False, 'columns': [], 'rows': [],
                    'error': f'Query exceeded the {QUERY_TIMEOUT_MS}ms timeout and was terminated.',
                    'row_count': 0}
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
                if _is_timeout_error(e):
                    # call_timeout firing can leave the connection itself
                    # unusable (per oracledb's own documentation) --
                    # continuing to loop the remaining queries on it would
                    # risk unpredictable behavior on an already-broken
                    # connection, not a clean per-query failure. Stop the
                    # whole batch here rather than pretend the rest could
                    # still run normally.
                    logger.error(f'run_queries [{q.get("name")}]: TIMEOUT after {QUERY_TIMEOUT_MS}ms -- stopping remaining queries in this batch')
                    results.append({
                        'name':        q.get('name', ''),
                        'description': q.get('description', ''),
                        'ok':          False,
                        'columns':     [],
                        'rows':        [],
                        'row_count':   0,
                        'error':       f'Query exceeded the {QUERY_TIMEOUT_MS}ms timeout and was terminated.'
                    })
                    remaining = queries[queries.index(q) + 1:]
                    for skipped in remaining:
                        results.append({
                            'name':        skipped.get('name', ''),
                            'description': skipped.get('description', ''),
                            'ok':          False,
                            'columns':     [],
                            'rows':        [],
                            'row_count':   0,
                            'error':       'Skipped: a prior query in this batch timed out and the connection was terminated.'
                        })
                    break
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
