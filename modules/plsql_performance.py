# modules/plsql_performance.py
# ============================================================
# AWR Insight Portal v3 — PL/SQL Performance Analysis
#
# Runs 4 live queries against Oracle DBA_HIST_ACTIVE_SESS_HISTORY
# + DBA_HIST_SQLSTAT to identify top-consuming PL/SQL packages
# and procedures by CPU, Elapsed, Cluster Wait, and I/O.
#
# Uses oracle_live_query.py for execution.
# Generates recommendations via Rules or AI mode.
#
# Required Oracle privileges (in addition to AWR generation):
#   GRANT SELECT ON SYS.DBA_HIST_ACTIVE_SESS_HISTORY TO awrportal;
#   GRANT SELECT ON SYS.DBA_OBJECTS TO awrportal;
#   GRANT SELECT ON SYS.DBA_USERS TO awrportal;
#   (SELECT_CATALOG_ROLE already covers these)
# ============================================================

from logger_utils import get_logger
logger = get_logger('plsql_performance')

# ── Base CTE shared across all 4 queries ─────────────────────────────────────
_BASE_CTE = """
WITH snap_range AS (
    SELECT snap_id
    FROM   dba_hist_snapshot
    WHERE  begin_interval_time BETWEEN
               TO_TIMESTAMP(:begin_time, 'YYYY-MM-DD HH24:MI')
           AND TO_TIMESTAMP(:end_time,   'YYYY-MM-DD HH24:MI')
),
app_schemas AS (
    SELECT username
    FROM   dba_users
    WHERE  oracle_maintained = 'N'
),
plsql_objects AS (
    SELECT object_id, owner, object_name
    FROM   dba_objects
    WHERE  object_type IN ('PROCEDURE','FUNCTION','PACKAGE','PACKAGE BODY')
      AND  owner IN (SELECT username FROM app_schemas)
),
ash_sql AS (
    SELECT
        o.owner,
        o.object_name,
        a.sql_id,
        COUNT(*) ash_samples
    FROM   dba_hist_active_sess_history a
    JOIN   snap_range  s ON s.snap_id = a.snap_id
    JOIN   plsql_objects o
        ON o.object_id = a.plsql_entry_object_id
    WHERE  {ash_filter}
    GROUP  BY o.owner, o.object_name, a.sql_id
),
sqlstats AS (
    SELECT
        sql_id,
        SUM(executions_delta)      execs,
        SUM(elapsed_time_delta)/1e6 elapsed_sec,
        SUM(cpu_time_delta)/1e6     cpu_sec,
        SUM(clwait_delta)/1e6       cluster_sec,
        SUM(iowait_delta)/1e6       io_sec
    FROM  dba_hist_sqlstat
    WHERE snap_id IN (SELECT snap_id FROM snap_range)
    GROUP BY sql_id
)
"""

# ── 4 query definitions ───────────────────────────────────────────────────────
QUERIES = [
    {
        'id':          'top_cpu',
        'name':        'Top PL/SQL by CPU Time',
        'description': 'PL/SQL packages/procedures with highest total CPU consumption. '
                       'Focus on reducing CPU in the top packages first.',
        'metric':      'cpu_sec',
        'metric_label':'CPU Time (sec)',
        'ash_filter':  "a.session_state = 'ON CPU'",
        'order_col':   'cpu_sec',
        'threshold':   60,   # recommend if cpu_sec > 60s
    },
    {
        'id':          'top_elapsed',
        'name':        'Top PL/SQL by Elapsed Time',
        'description': 'PL/SQL packages/procedures with highest total elapsed time '
                       '(CPU + waits). Best indicator of overall response time impact.',
        'metric':      'elapsed_sec',
        'metric_label':'Elapsed Time (sec)',
        'ash_filter':  "a.session_state IN ('ON CPU','WAITING')",
        'order_col':   'elapsed_sec',
        'threshold':   120,
    },
    {
        'id':          'top_cluster',
        'name':        'Top PL/SQL by Cluster Wait',
        'description': 'PL/SQL packages/procedures with highest RAC cluster wait time. '
                       'High values indicate inter-node contention — check buffer cache '
                       'sizing, sequence caching, and hot block contention.',
        'metric':      'cluster_sec',
        'metric_label':'Cluster Wait (sec)',
        'ash_filter':  "a.wait_class = 'Cluster'",
        'order_col':   'cluster_sec',
        'threshold':   30,
    },
    {
        'id':          'top_io',
        'name':        'Top PL/SQL by I/O Wait',
        'description': 'PL/SQL packages/procedures with highest I/O wait time. '
                       'High values indicate excessive physical reads — check missing '
                       'indexes, full table scans, and buffer cache sizing.',
        'metric':      'io_sec',
        'metric_label':'I/O Wait (sec)',
        'ash_filter':  "a.wait_class = 'User I/O'",
        'order_col':   'io_sec',
        'threshold':   30,
    },
]


def _build_sql(q: dict) -> str:
    """Build the full SQL for one PL/SQL performance query."""
    cte = _BASE_CTE.format(ash_filter=q['ash_filter'])
    order_col = q['order_col']
    return cte + f"""
SELECT *
FROM (
    SELECT
        a.owner,
        a.object_name,
        a.sql_id,
        s.execs,
        ROUND(s.elapsed_sec, 2)                        elapsed_sec,
        ROUND(s.cpu_sec, 2)                            cpu_sec,
        ROUND(s.cluster_sec, 2)                        cluster_sec,
        ROUND(s.io_sec, 2)                             io_sec,
        ROUND(s.elapsed_sec / NULLIF(s.execs, 0), 4)  avg_elapsed,
        ROUND(s.cpu_sec     / NULLIF(s.execs, 0), 4)  avg_cpu,
        a.ash_samples,
        SUBSTR(t.sql_text, 1, 200)                     sql_text,
        ROW_NUMBER() OVER (
            PARTITION BY a.owner, a.object_name
            ORDER BY s.{order_col} DESC
        ) rn
    FROM   ash_sql  a
    JOIN   sqlstats s ON s.sql_id = a.sql_id
    LEFT JOIN dba_hist_sqltext t ON t.sql_id = a.sql_id
)
WHERE  rn <= 20
ORDER  BY {order_col} DESC
"""


def run_plsql_analysis(conn_id: int,
                       begin_time: str, end_time: str,
                       query_ids: list = None) -> dict:
    """
    Run PL/SQL performance queries for the given time range.

    begin_time / end_time: 'YYYY-MM-DD HH24:MI' format
    query_ids: list of query IDs to run (None = all 4)
    Returns {ok, results: [{id, name, description, ok, columns, rows, error}],
             recommendations: [...]}
    """
    from modules.oracle_awr_fetcher import get_connection_by_id
    from modules.oracle_live_query import run_queries

    cfg = get_connection_by_id(conn_id)
    if not cfg:
        return {'ok': False, 'error': f'Connection {conn_id} not found'}

    active_queries = QUERIES if not query_ids else \
        [q for q in QUERIES if q['id'] in query_ids]

    query_defs = []
    for q in active_queries:
        query_defs.append({
            'name':        q['id'],
            'description': q['description'],
            'sql':         _build_sql(q),
            'params':      {'begin_time': begin_time, 'end_time': end_time},
        })

    raw_results = run_queries(cfg, query_defs)

    # Attach metadata from QUERIES definition
    results = []
    for i, r in enumerate(raw_results):
        q_meta = active_queries[i]
        results.append({**r,
                        'id':           q_meta['id'],
                        'name':         q_meta['name'],
                        'metric':       q_meta['metric'],
                        'metric_label': q_meta['metric_label'],
                        'threshold':    q_meta['threshold']})

    # Generate rules-based recommendations
    recommendations = _generate_recommendations(results)

    return {
        'ok':              True,
        'db_name':         cfg['db_name'],
        'begin_time':      begin_time,
        'end_time':        end_time,
        'results':         results,
        'recommendations': recommendations,
        'error':           None
    }


def _generate_recommendations(results: list) -> list:
    """
    Rules-based recommendations from PL/SQL performance data.
    One recommendation per finding, severity Critical/Alert/Warning.
    """
    recs = []

    for r in results:
        if not r.get('ok') or not r.get('rows'):
            continue

        q_id     = r['id']
        rows     = r['rows']
        metric   = r['metric']
        label    = r['metric_label']
        threshold = r.get('threshold', 60)

        # Group rows by owner.object_name and sum the metric
        from collections import defaultdict
        pkg_totals = defaultdict(float)
        pkg_sqls   = defaultdict(list)
        for row in rows:
            key = f"{row.get('owner','?')}.{row.get('object_name','?')}"
            val = float(row.get(metric) or 0)
            pkg_totals[key] += val
            if row.get('sql_id'):
                pkg_sqls[key].append(row['sql_id'])

        # Sort by total metric descending
        sorted_pkgs = sorted(pkg_totals.items(), key=lambda x: x[1], reverse=True)

        for pkg_name, total_val in sorted_pkgs[:5]:
            if total_val < threshold:
                continue

            sql_list = ', '.join(pkg_sqls[pkg_name][:3])
            severity = ('Critical' if total_val > threshold * 5
                        else 'Alert' if total_val > threshold * 2
                        else 'Warning')

            if q_id == 'top_cpu':
                rec = {
                    'severity':       severity,
                    'category':       'PL/SQL CPU',
                    'object':         pkg_name,
                    'finding':        f'{pkg_name} consumed {total_val:.1f}s CPU time in this period.',
                    'recommendation': (
                        f'Profile the top SQL statements within {pkg_name} '
                        f'(SQL IDs: {sql_list}). '
                        'Focus on: eliminating row-by-row processing (FORALL instead of loop), '
                        'reducing redundant function calls in SQL WHERE clauses, '
                        'and caching frequently-used lookup values in package variables.'
                    ),
                    'sql_ids': pkg_sqls[pkg_name][:5]
                }
            elif q_id == 'top_elapsed':
                rec = {
                    'severity':       severity,
                    'category':       'PL/SQL Elapsed Time',
                    'object':         pkg_name,
                    'finding':        f'{pkg_name} had {total_val:.1f}s total elapsed time — includes CPU and all wait classes.',
                    'recommendation': (
                        f'Review SQL IDs {sql_list} for wait event breakdown. '
                        'If elapsed >> CPU: investigate I/O waits (missing indexes, full scans) '
                        'or concurrency waits (locks, buffer busy). '
                        'If elapsed ≈ CPU: this is a pure compute problem — review algorithm efficiency.'
                    ),
                    'sql_ids': pkg_sqls[pkg_name][:5]
                }
            elif q_id == 'top_cluster':
                rec = {
                    'severity':       severity,
                    'category':       'PL/SQL RAC Cluster Waits',
                    'object':         pkg_name,
                    'finding':        f'{pkg_name} accumulated {total_val:.1f}s cluster wait time — indicates RAC inter-node contention.',
                    'recommendation': (
                        f'For SQL IDs {sql_list}: '
                        '1. Check for hot blocks — enable CACHE on small lookup tables. '
                        '2. Review sequence cache size (should be >= 1000 for RAC). '
                        '3. Check if DML-heavy tables have adequate INITRANS/PCTFREE. '
                        '4. Consider partitioning if contention is on specific data ranges.'
                    ),
                    'sql_ids': pkg_sqls[pkg_name][:5]
                }
            elif q_id == 'top_io':
                rec = {
                    'severity':       severity,
                    'category':       'PL/SQL I/O Waits',
                    'object':         pkg_name,
                    'finding':        f'{pkg_name} had {total_val:.1f}s I/O wait time — physical reads are the bottleneck.',
                    'recommendation': (
                        f'For SQL IDs {sql_list}: '
                        '1. Check execution plans for full table scans on large tables. '
                        '2. Review index usage — missing indexes, high BLEVEL, or poor clustering factor. '
                        '3. Verify buffer cache hit ratio (target > 98%). '
                        '4. Consider result caching (RESULT_CACHE hint) for frequently-called read-only queries.'
                    ),
                    'sql_ids': pkg_sqls[pkg_name][:5]
                }
            else:
                continue

            recs.append(rec)

    return recs
