# modules/plsql_performance.py
# ============================================================
# AWR Insight Portal v3 — PL/SQL Performance Analysis
#
# 8 live queries against Oracle DBA_HIST_ACTIVE_SESS_HISTORY
# + DBA_HIST_SQLSTAT to identify top-consuming PL/SQL packages
# by CPU, Elapsed, Cluster Wait, I/O, loop detection, and
# consolidated procedure dashboards.
#
# Required Oracle privileges (SELECT_CATALOG_ROLE covers all):
#   SELECT on DBA_HIST_ACTIVE_SESS_HISTORY
#   SELECT on DBA_HIST_SQLSTAT
#   SELECT on DBA_HIST_SQLTEXT
#   SELECT on DBA_OBJECTS
#   SELECT on DBA_USERS
# ============================================================

from logger_utils import get_logger
logger = get_logger('plsql_performance')

# ── Shared snap_range + app_schemas + plsql_objects CTE ──────────────────────
_SNAP_CTE = """
WITH snap_range AS (
    SELECT snap_id
    FROM   dba_hist_snapshot
    WHERE  snap_id BETWEEN :begin_snap AND :end_snap
),
app_schemas AS (
    SELECT username FROM dba_users WHERE oracle_maintained = 'N'
),
plsql_objects AS (
    SELECT object_id, owner, object_name
    FROM   dba_objects
    WHERE  object_type IN ('PROCEDURE','FUNCTION','PACKAGE','PACKAGE BODY')
      AND  owner IN (SELECT username FROM app_schemas)
)
"""

_ASH_SQL_CTE = """
,ash_sql AS (
    SELECT o.owner, o.object_name, a.sql_id, COUNT(*) ash_samples
    FROM   dba_hist_active_sess_history a
    JOIN   snap_range s ON s.snap_id = a.snap_id
    JOIN   plsql_objects o ON o.object_id = a.plsql_entry_object_id
    WHERE  {ash_filter}
    GROUP  BY o.owner, o.object_name, a.sql_id
),
sqlstats AS (
    SELECT sql_id,
           SUM(executions_delta)      execs,
           SUM(elapsed_time_delta)/1e6 elapsed_sec,
           SUM(cpu_time_delta)/1e6     cpu_sec,
           SUM(clwait_delta)/1e6       cluster_sec,
           SUM(iowait_delta)/1e6       io_sec,
           SUM(buffer_gets_delta)      buffer_gets,
           SUM(disk_reads_delta)       disk_reads
    FROM  dba_hist_sqlstat
    WHERE snap_id IN (SELECT snap_id FROM snap_range)
    GROUP BY sql_id
)
"""

def _top_sql(order_col):
    return f"""
SELECT *
FROM (
    SELECT a.owner, a.object_name, a.sql_id,
           s.execs,
           ROUND(s.elapsed_sec,2)                       elapsed_sec,
           ROUND(s.cpu_sec,2)                           cpu_sec,
           ROUND(s.cluster_sec,2)                       cluster_sec,
           ROUND(s.io_sec,2)                            io_sec,
           ROUND(s.elapsed_sec/NULLIF(s.execs,0),4)     avg_elapsed,
           ROUND(s.cpu_sec/NULLIF(s.execs,0),4)         avg_cpu,
           a.ash_samples,
           SUBSTR(t.sql_text,1,200)                     sql_text,
           ROW_NUMBER() OVER (
               PARTITION BY a.owner,a.object_name
               ORDER BY s.{order_col} DESC
           ) rn
    FROM ash_sql a
    JOIN sqlstats s ON s.sql_id = a.sql_id
    LEFT JOIN dba_hist_sqltext t ON t.sql_id = a.sql_id
)
WHERE rn <= 20
ORDER BY {order_col} DESC
"""

# ── 8 query definitions ───────────────────────────────────────────────────────
QUERIES = [
    # ── 01-04: Top by metric ──────────────────────────────────────────────────
    {
        'id':          'top_cpu',
        'name':        'Top PL/SQL — CPU Time',
        'description': 'Packages/procedures with highest total CPU consumption.',
        'metric':      'cpu_sec',
        'metric_label':'CPU (sec)',
        'threshold':   60,
        'sql': lambda: _SNAP_CTE
               + _ASH_SQL_CTE.format(ash_filter="a.session_state = 'ON CPU'")
               + _top_sql('cpu_sec'),
    },
    {
        'id':          'top_elapsed',
        'name':        'Top PL/SQL — Elapsed Time',
        'description': 'Packages/procedures with highest total elapsed time (CPU + all waits).',
        'metric':      'elapsed_sec',
        'metric_label':'Elapsed (sec)',
        'threshold':   120,
        'sql': lambda: _SNAP_CTE
               + _ASH_SQL_CTE.format(ash_filter="a.session_state IN ('ON CPU','WAITING')")
               + _top_sql('elapsed_sec'),
    },
    {
        'id':          'top_cluster',
        'name':        'Top PL/SQL — Cluster Wait',
        'description': 'Packages/procedures with highest RAC cluster wait time.',
        'metric':      'cluster_sec',
        'metric_label':'Cluster Wait (sec)',
        'threshold':   30,
        'sql': lambda: _SNAP_CTE
               + _ASH_SQL_CTE.format(ash_filter="a.wait_class = 'Cluster'")
               + _top_sql('cluster_sec'),
    },
    {
        'id':          'top_io',
        'name':        'Top PL/SQL — I/O Wait',
        'description': 'Packages/procedures with highest I/O wait time.',
        'metric':      'io_sec',
        'metric_label':'I/O Wait (sec)',
        'threshold':   30,
        'sql': lambda: _SNAP_CTE
               + _ASH_SQL_CTE.format(ash_filter="a.wait_class = 'User I/O'")
               + _top_sql('io_sec'),
    },
    # ── 05: Loop detector ─────────────────────────────────────────────────────
    {
        'id':          'loop_detector',
        'name':        'PL/SQL Loop Detector',
        'description': (
            'Detects SQL statements called 1000+ times with very low avg elapsed '
            '(< 10ms) but high ASH activity — classic row-by-row loop anti-pattern inside PL/SQL.'
        ),
        'metric':      'execs',
        'metric_label':'Executions',
        'threshold':   0,
        'sql': lambda: _SNAP_CTE + """
,ash_sql AS (
    SELECT o.owner, o.object_name, a.sql_id, COUNT(*) ash_samples
    FROM   dba_hist_active_sess_history a
    JOIN   snap_range s ON s.snap_id = a.snap_id
    JOIN   plsql_objects o ON o.object_id = a.plsql_entry_object_id
    WHERE  a.sql_id IS NOT NULL
    GROUP  BY o.owner, o.object_name, a.sql_id
),
sqlstats AS (
    SELECT sql_id,
           SUM(executions_delta)      execs,
           SUM(elapsed_time_delta)/1e6 elapsed_sec,
           SUM(cpu_time_delta)/1e6     cpu_sec,
           SUM(buffer_gets_delta)      buffer_gets,
           SUM(disk_reads_delta)       disk_reads
    FROM  dba_hist_sqlstat
    WHERE snap_id IN (SELECT snap_id FROM snap_range)
    GROUP BY sql_id
)
SELECT a.owner, a.object_name, a.sql_id,
       s.execs,
       ROUND(s.elapsed_sec,2)                        elapsed_sec,
       ROUND(s.cpu_sec,2)                             cpu_sec,
       ROUND(s.elapsed_sec/NULLIF(s.execs,0),6)      avg_elapsed_sec,
       ROUND(s.cpu_sec/NULLIF(s.execs,0),6)           avg_cpu_sec,
       ROUND(s.buffer_gets/NULLIF(s.execs,0),2)       avg_buffer_gets,
       ROUND(s.disk_reads/NULLIF(s.execs,0),2)        avg_disk_reads,
       a.ash_samples,
       SUBSTR(t.sql_text,1,200) sql_text
FROM ash_sql a
JOIN sqlstats s ON s.sql_id = a.sql_id
LEFT JOIN dba_hist_sqltext t ON t.sql_id = a.sql_id
WHERE s.execs > 1000
  AND (s.elapsed_sec/NULLIF(s.execs,0)) < 0.01
  AND a.ash_samples > 50
ORDER BY s.execs DESC
FETCH FIRST 30 ROWS ONLY
""",
    },
    # ── 09a: Procedure dashboard (best version) ───────────────────────────────
    {
        'id':          'proc_dashboard',
        'name':        'Procedure Dashboard',
        'description': (
            'Consolidated procedure-level summary: elapsed, CPU, cluster, I/O totals '
            'and averages per execution, % breakdown, RAC GC detail, and top SQL ID. '
            'Best single view for overall PL/SQL performance.'
        ),
        'metric':      'elapsed_sec',
        'metric_label':'Elapsed (sec)',
        'threshold':   0,
        'sql': lambda: _SNAP_CTE + """
,ash_proc_sql AS (
    SELECT o.owner, o.object_name, a.sql_id,
           COUNT(*) ash_samples,
           SUM(CASE WHEN a.event LIKE 'gc current%' THEN 1 END) gc_current,
           SUM(CASE WHEN a.event LIKE 'gc cr%'      THEN 1 END) gc_cr
    FROM   dba_hist_active_sess_history a
    JOIN   snap_range s ON a.snap_id = s.snap_id
    JOIN   dba_objects o ON o.object_id = a.plsql_entry_object_id
    WHERE  o.owner IN (SELECT username FROM app_schemas)
      AND  a.sql_id IS NOT NULL
    GROUP  BY o.owner, o.object_name, a.sql_id
),
sql_metrics AS (
    SELECT sql_id,
           SUM(executions_delta)       execs,
           SUM(elapsed_time_delta)/1e6 elapsed_sec,
           SUM(cpu_time_delta)/1e6     cpu_sec,
           SUM(clwait_delta)/1e6       cluster_sec,
           SUM(iowait_delta)/1e6       io_sec
    FROM   dba_hist_sqlstat
    WHERE  snap_id IN (SELECT snap_id FROM snap_range)
    GROUP  BY sql_id
),
proc_summary AS (
    SELECT a.owner, a.object_name,
           SUM(m.elapsed_sec)  elapsed_sec,
           SUM(m.cpu_sec)      cpu_sec,
           SUM(m.cluster_sec)  cluster_sec,
           SUM(m.io_sec)       io_sec,
           SUM(m.execs)        executions,
           SUM(a.gc_current)   gc_current,
           SUM(a.gc_cr)        gc_cr
    FROM   ash_proc_sql a
    JOIN   sql_metrics m ON m.sql_id = a.sql_id
    GROUP  BY a.owner, a.object_name
),
top_sql AS (
    SELECT * FROM (
        SELECT a.owner, a.object_name, a.sql_id,
               SUBSTR(t.sql_text,1,120) sql_text,
               ROW_NUMBER() OVER (
                   PARTITION BY a.owner, a.object_name
                   ORDER BY m.elapsed_sec DESC
               ) rn
        FROM ash_proc_sql a
        JOIN sql_metrics m ON m.sql_id = a.sql_id
        LEFT JOIN dba_hist_sqltext t ON t.sql_id = a.sql_id
    ) WHERE rn = 1
)
SELECT p.owner, p.object_name,
       ROUND(p.elapsed_sec,2)                            elapsed_sec,
       ROUND(p.cpu_sec,2)                                cpu_sec,
       ROUND(p.cluster_sec,2)                            cluster_sec,
       ROUND(p.io_sec,2)                                 io_sec,
       p.executions,
       ROUND(p.elapsed_sec/NULLIF(p.executions,0),6)     avg_elapsed,
       ROUND(p.cpu_sec/NULLIF(p.executions,0),6)         avg_cpu,
       ROUND(p.cluster_sec/NULLIF(p.executions,0),6)     avg_cluster,
       ROUND(p.io_sec/NULLIF(p.executions,0),6)          avg_io,
       ROUND(p.cpu_sec/NULLIF(p.elapsed_sec,0)*100,2)    cpu_pct,
       ROUND(p.cluster_sec/NULLIF(p.elapsed_sec,0)*100,2) cluster_pct,
       ROUND(p.io_sec/NULLIF(p.elapsed_sec,0)*100,2)      io_pct,
       p.gc_current, p.gc_cr,
       t.sql_id top_sql_id,
       t.sql_text top_sql_text
FROM   proc_summary p
LEFT JOIN top_sql t ON p.owner = t.owner AND p.object_name = t.object_name
ORDER  BY p.elapsed_sec DESC
FETCH  FIRST 30 ROWS ONLY
""",
    },
    # ── Multiple plan hash values ─────────────────────────────────────────────
    {
        'id':          'multi_plan',
        'name':        'SQL with Multiple Execution Plans',
        'description': (
            'SQL statements with more than one plan hash value in the selected time range. '
            'Shows plan regression % — how much slower the non-optimal plan is vs the best.'
        ),
        'metric':      'regression_pct',
        'metric_label':'Regression %',
        'threshold':   0,
        'sql': lambda: _SNAP_CTE + """
,plan_perf AS (
    SELECT sql_id, plan_hash_value,
           SUM(elapsed_time_delta)/1e6 elapsed_sec,
           SUM(executions_delta)       execs
    FROM   dba_hist_sqlstat
    WHERE  snap_id IN (SELECT snap_id FROM snap_range)
    GROUP  BY sql_id, plan_hash_value
),
ranked AS (
    SELECT sql_id, plan_hash_value,
           ROUND(elapsed_sec,2) elapsed_sec, execs,
           ROUND(elapsed_sec/NULLIF(execs,0),4) avg_sec,
           MIN(elapsed_sec/NULLIF(execs,0)) OVER (PARTITION BY sql_id) best_avg,
           COUNT(*) OVER (PARTITION BY sql_id) plan_count
    FROM plan_perf
)
SELECT sql_id, plan_hash_value,
       plan_count,
       elapsed_sec, execs,
       avg_sec,
       ROUND((avg_sec - best_avg)/NULLIF(best_avg,0)*100,2) regression_pct,
       CASE WHEN avg_sec > best_avg THEN 'REGRESSED' ELSE 'BEST' END plan_status
FROM ranked
WHERE plan_count > 1
ORDER BY regression_pct DESC NULLS LAST, sql_id
FETCH FIRST 50 ROWS ONLY
""",
    },
    # ── Missing FK indexes ────────────────────────────────────────────────────
    {
        'id':          'missing_fk_index',
        'name':        'Missing Foreign Key Indexes',
        'description': (
            'FK constraints with no supporting index on the child table. '
            'Causes full table scans on the child during parent DELETE/UPDATE '
            'and lock escalation issues. High value — commonly missed.'
        ),
        'metric':      None,
        'metric_label': None,
        'threshold':   0,
        'sql': lambda: """
SELECT c.owner, c.table_name, c.constraint_name,
       cc.column_name fk_column,
       rc.table_name  referenced_table,
       'CREATE INDEX idx_' || LOWER(c.table_name) || '_'
           || LOWER(cc.column_name)
           || ' ON ' || c.owner || '.' || c.table_name
           || '(' || cc.column_name || ');'  suggested_index
FROM   dba_constraints  c
JOIN   dba_cons_columns cc ON c.owner = cc.owner
                           AND c.constraint_name = cc.constraint_name
JOIN   dba_constraints  rc ON c.r_owner = rc.owner
                           AND c.r_constraint_name = rc.constraint_name
WHERE  c.constraint_type = 'R'
  AND  c.owner NOT IN (
       'SYS','SYSTEM','DBSNMP','OUTLN','MDSYS','ORDSYS','WMSYS',
       'CTXSYS','XDB','SYSMAN','APPQOSSYS','AUDSYS','OJVMSYS')
  AND  NOT EXISTS (
       SELECT 1 FROM dba_ind_columns i
       WHERE  i.table_owner  = c.owner
         AND  i.table_name   = c.table_name
         AND  i.column_name  = cc.column_name
         AND  i.column_position = 1
  )
ORDER  BY c.owner, c.table_name
""",
    },
]


def run_plsql_analysis(conn_id: int,
                       begin_snap: int, end_snap: int,
                       query_ids: list = None) -> dict:
    """
    Run PL/SQL performance queries for the given time range.
    begin_snap / end_snap: integer snap IDs.
    query_ids: subset to run (None = all).
    """
    from modules.oracle_awr_fetcher import get_connection_by_id
    from modules.oracle_live_query import run_queries

    cfg = get_connection_by_id(conn_id)
    if not cfg:
        return {'ok': False, 'error': f'Connection {conn_id} not found'}

    active = QUERIES if not query_ids else \
        [q for q in QUERIES if q['id'] in query_ids]

    # missing_fk_index has no snap params
    NO_SNAP_PARAMS = {'missing_fk_index'}

    query_defs = []
    for q in active:
        sql = q['sql']()
        params = {} if q['id'] in NO_SNAP_PARAMS else \
                 {'begin_snap': begin_snap, 'end_snap': end_snap}
        query_defs.append({
            'name':        q['id'],
            'description': q['description'],
            'sql':         sql,
            'params':      params,
        })

    raw = run_queries(cfg, query_defs)

    results = []
    for i, r in enumerate(raw):
        q_meta = active[i]
        results.append({**r,
                        'id':           q_meta['id'],
                        'name':         q_meta['name'],
                        'metric':       q_meta.get('metric'),
                        'metric_label': q_meta.get('metric_label'),
                        'threshold':    q_meta.get('threshold', 0)})

    recommendations = _generate_recommendations(results)

    return {
        'ok':              True,
        'db_name':         cfg['db_name'],
        'begin_snap':      begin_snap,
        'end_snap':        end_snap,
        'results':         results,
        'recommendations': recommendations,
        'error':           None
    }


def _generate_recommendations(results: list) -> list:
    recs = []
    from collections import defaultdict

    for r in results:
        if not r.get('ok') or not r.get('rows'):
            continue

        q_id      = r['id']
        rows      = r['rows']
        metric    = r.get('metric')
        threshold = r.get('threshold', 0)

        # ── Loop detector ─────────────────────────────────────────────────
        if q_id == 'loop_detector':
            for row in rows[:5]:
                obj  = f"{row.get('owner','?')}.{row.get('object_name','?')}"
                execs = int(row.get('execs') or 0)
                avg_e = float(row.get('avg_elapsed_sec') or 0)
                recs.append({
                    'severity': 'Critical' if execs > 10000 else 'Alert',
                    'category': 'PL/SQL Loop Anti-Pattern',
                    'object':   obj,
                    'finding':  (
                        f'{obj} called SQL {row.get("sql_id","?")} '
                        f'{execs:,} times with avg {avg_e*1000:.2f}ms per call. '
                        f'Classic row-by-row loop inside PL/SQL.'
                    ),
                    'recommendation': (
                        f'Replace row-by-row loop in {obj} with set-based SQL using BULK COLLECT + FORALL. '
                        'Each individual call is fast but the cumulative cost of calling it '
                        f'{execs:,} times dominates DB time. '
                        'Target: reduce executions by 90%+ through bulk processing.'
                    ),
                    'sql_ids': [row.get('sql_id')]
                })

        # ── Procedure dashboard ────────────────────────────────────────────
        elif q_id == 'proc_dashboard':
            for row in rows[:5]:
                obj      = f"{row.get('owner','?')}.{row.get('object_name','?')}"
                elapsed  = float(row.get('elapsed_sec') or 0)
                cpu_pct  = float(row.get('cpu_pct') or 0)
                cl_pct   = float(row.get('cluster_pct') or 0)
                io_pct   = float(row.get('io_pct') or 0)
                gc_cur   = int(row.get('gc_current') or 0)
                gc_cr    = int(row.get('gc_cr') or 0)
                if elapsed < 30:
                    continue
                dominant = ('CPU-bound' if cpu_pct > 60
                            else 'Cluster wait-bound' if cl_pct > 30
                            else 'I/O-bound' if io_pct > 30
                            else 'Mixed waits')
                recs.append({
                    'severity': 'Critical' if elapsed > 3600 else 'Alert' if elapsed > 600 else 'Warning',
                    'category': f'PL/SQL {dominant}',
                    'object':   obj,
                    'finding':  (
                        f'{obj}: {elapsed:.0f}s total elapsed — {dominant}. '
                        f'CPU {cpu_pct:.0f}% / Cluster {cl_pct:.0f}% / I/O {io_pct:.0f}%.'
                        + (f' RAC GC: {gc_cur} gc_current + {gc_cr} gc_cr samples.' if gc_cur + gc_cr > 0 else '')
                    ),
                    'recommendation': (
                        'CPU-bound: optimise SQL execution plans, reduce parse overhead, use result cache. '
                        if cpu_pct > 60 else
                        'Cluster-bound: review sequence cache (>= 1000 for RAC), check INITRANS, '
                        'consider reverse key index for hot sequence PK indexes. '
                        if cl_pct > 30 else
                        'I/O-bound: review index usage, check clustering factor, '
                        'verify buffer cache hit ratio. '
                    ) + f'Top SQL: {row.get("top_sql_id","?")}',
                    'sql_ids': [row.get('top_sql_id')]
                })

        # ── Multiple plans ─────────────────────────────────────────────────
        elif q_id == 'multi_plan':
            regressed = [r for r in rows if r.get('plan_status') == 'REGRESSED'
                         and float(r.get('regression_pct') or 0) > 50]
            for row in regressed[:5]:
                reg_pct = float(row.get('regression_pct') or 0)
                recs.append({
                    'severity': 'Critical' if reg_pct > 500 else 'Alert' if reg_pct > 100 else 'Warning',
                    'category': 'Plan Regression',
                    'object':   row.get('sql_id','?'),
                    'finding':  (
                        f'SQL {row.get("sql_id","?")} plan {row.get("plan_hash_value","?")} '
                        f'is {reg_pct:.0f}% slower than best known plan.'
                    ),
                    'recommendation': (
                        f'Pin the best plan using SQL Plan Baseline: '
                        f'EXEC DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE(sql_id => \'{row.get("sql_id","")}\'); '
                        'Or use SQL Profile to stabilise execution plan.'
                    ),
                    'sql_ids': [row.get('sql_id')]
                })

        # ── Missing FK ─────────────────────────────────────────────────────
        elif q_id == 'missing_fk_index':
            if rows:
                owners = list({r.get('owner','?') for r in rows})
                recs.append({
                    'severity':       'Alert',
                    'category':       'Missing FK Index',
                    'object':         f'{len(rows)} FK constraints',
                    'finding':        (
                        f'{len(rows)} foreign key constraint(s) have no supporting index '
                        f'on the child table across schemas: {", ".join(owners[:5])}. '
                        'These cause full table scans during parent row DELETE/UPDATE.'
                    ),
                    'recommendation': (
                        'Create indexes on all FK columns. '
                        'The suggested_index column in the results contains ready-to-run CREATE INDEX statements. '
                        'Priority: tables involved in frequent DELETE/UPDATE on the parent table.'
                    ),
                    'sql_ids': []
                })

        # ── Top by metric ──────────────────────────────────────────────────
        elif metric and threshold:
            pkg_totals = defaultdict(float)
            pkg_sqls   = defaultdict(list)
            for row in rows:
                key = f"{row.get('owner','?')}.{row.get('object_name','?')}"
                pkg_totals[key] += float(row.get(metric) or 0)
                if row.get('sql_id'):
                    pkg_sqls[key].append(row['sql_id'])

            for pkg_name, total in sorted(pkg_totals.items(),
                                          key=lambda x: x[1], reverse=True)[:5]:
                if total < threshold:
                    continue
                severity = ('Critical' if total > threshold * 5
                            else 'Alert' if total > threshold * 2
                            else 'Warning')
                sql_list = ', '.join(pkg_sqls[pkg_name][:3])
                label    = r.get('metric_label', metric)
                recs.append({
                    'severity':       severity,
                    'category':       f'PL/SQL {r["name"]}',
                    'object':         pkg_name,
                    'finding':        f'{pkg_name}: {total:.1f}s {label} in this period.',
                    'recommendation': (
                        f'Review SQL IDs {sql_list} within {pkg_name}. '
                        'Check execution plans, index usage, and wait event breakdown.'
                    ),
                    'sql_ids': pkg_sqls[pkg_name][:5]
                })

    return recs
