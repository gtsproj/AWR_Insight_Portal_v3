# modules/system_study.py
# ============================================================
# AWR Insight Portal v3 — Database System Study
#
# Runs live queries against Oracle to generate a comprehensive
# database system study report. Covers 15 sections and generates
# recommendations for:
#   - Controlfile multiplexing
#   - Redo log sizing and group count
#   - ASM migration from OS filesystem
#   - Table/index partitioning opportunities
# ============================================================

from logger_utils import get_logger
logger = get_logger('system_study')

# ── Query definitions — 15 sections ──────────────────────────────────────────
SECTIONS = [
    {
        'id': 'server_info',
        'name': 'Server CPU & Memory',
        'sql': """
            SELECT i.host_name,
                   d.platform_name,
                   (SELECT MAX(value) FROM v$osstat WHERE stat_name='NUM_CPUS')        cpus,
                   (SELECT MAX(value) FROM v$osstat WHERE stat_name='NUM_CPU_CORES')   cores,
                   ROUND((SELECT MAX(value) FROM v$osstat
                          WHERE stat_name='PHYSICAL_MEMORY_BYTES')/1073741824, 2)      memory_gb
            FROM   v$instance i, v$database d
        """
    },
    {
        'id': 'db_config',
        'name': 'Database Configuration',
        'sql': """
            SELECT d.name db_name, d.dbid, i.instance_name,
                   i.instance_number, i.version release,
                   TO_CHAR(i.startup_time,'DD-MON-YYYY HH24:MI:SS') startup_time,
                   d.log_mode, d.database_role, d.open_mode,
                   (SELECT DECODE(COUNT(*),0,'No','Yes')
                    FROM v$active_instances WHERE ROWNUM=1) rac
            FROM   v$database d, v$instance i
        """
    },
    {
        'id': 'db_size',
        'name': 'Database Size & Growth',
        'sql': """
            SELECT
                data_mb, temp_mb, redo_mb,
                ROUND(data_mb + NVL(temp_mb,0) + NVL(redo_mb,0), 2) total_mb,
                ROUND(data_mb - free_mb, 2) used_mb,
                ROUND((data_mb - free_mb) / NULLIF(data_mb,0) * 100, 2) used_pct
            FROM (
                SELECT
                    (SELECT ROUND(SUM(bytes)/1048576,2) FROM dba_data_files)  data_mb,
                    (SELECT ROUND(NVL(SUM(bytes),0)/1048576,2) FROM dba_temp_files) temp_mb,
                    (SELECT ROUND(SUM(bytes)/1048576*MAX(members),2) FROM v$log)   redo_mb,
                    (SELECT ROUND(SUM(bytes)/1048576,2) FROM dba_free_space)   free_mb
                FROM dual
            )
        """
    },
    {
        'id': 'controlfiles',
        'name': 'Controlfile Information',
        'sql': """
            SELECT name, status,
                   is_recovery_dest_file,
                   block_size,
                   file_size_blks,
                   SUBSTR(name, 1, INSTR(name, '/', -1, 1)) location
            FROM   v$controlfile
            ORDER  BY name
        """
    },
    {
        'id': 'redo_logs',
        'name': 'Online Redo Log Information',
        'sql': """
            SELECT l.group#, l.thread#, l.members,
                   ROUND(l.bytes/1048576, 0) size_mb,
                   l.status, l.archived,
                   f.member,
                   SUBSTR(f.member, 1, INSTR(f.member,'/',-1,1)) location
            FROM   v$log l
            JOIN   v$logfile f ON f.group# = l.group#
            ORDER  BY l.group#, f.member
        """
    },
    {
        'id': 'log_switches',
        'name': 'Hourly Log Switches (Last 7 Days)',
        'sql': """
            SELECT TO_CHAR(first_time,'DD-MON-YY') log_date,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'00',1,0)) h00,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'01',1,0)) h01,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'02',1,0)) h02,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'03',1,0)) h03,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'04',1,0)) h04,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'05',1,0)) h05,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'06',1,0)) h06,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'07',1,0)) h07,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'08',1,0)) h08,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'09',1,0)) h09,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'10',1,0)) h10,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'11',1,0)) h11,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'12',1,0)) h12,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'13',1,0)) h13,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'14',1,0)) h14,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'15',1,0)) h15,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'16',1,0)) h16,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'17',1,0)) h17,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'18',1,0)) h18,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'19',1,0)) h19,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'20',1,0)) h20,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'21',1,0)) h21,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'22',1,0)) h22,
                   SUM(DECODE(TO_CHAR(first_time,'HH24'),'23',1,0)) h23,
                   COUNT(*) total_switches
            FROM   v$log_history
            WHERE  first_time > SYSDATE - 7
            GROUP  BY TO_CHAR(first_time,'DD-MON-YY')
            ORDER  BY 1
        """
    },
    {
        'id': 'tablespaces',
        'name': 'Tablespace Information',
        'sql': """
            SELECT t.tablespace_name, t.status, t.contents, t.extent_management,
                   t.segment_space_management,
                   ROUND(NVL(d.total_mb,0),2)                            total_mb,
                   ROUND(NVL(d.total_mb,0) - NVL(f.free_mb,0), 2)       used_mb,
                   ROUND(NVL(f.free_mb,0), 2)                            free_mb,
                   ROUND((NVL(d.total_mb,0) - NVL(f.free_mb,0)) /
                         NULLIF(NVL(d.total_mb,0),0) * 100, 2)          used_pct,
                   t.bigfile, t.encrypted
            FROM   dba_tablespaces t
            LEFT JOIN (SELECT tablespace_name, SUM(bytes)/1048576 total_mb
                       FROM dba_data_files GROUP BY tablespace_name) d
                   ON d.tablespace_name = t.tablespace_name
            LEFT JOIN (SELECT tablespace_name, SUM(bytes)/1048576 free_mb
                       FROM dba_free_space GROUP BY tablespace_name) f
                   ON f.tablespace_name = t.tablespace_name
            ORDER  BY used_pct DESC NULLS LAST
        """
    },
    {
        'id': 'asm_diskgroups',
        'name': 'ASM Disk Groups',
        'sql': """
            SELECT name, state, type,
                   ROUND(total_mb/1024, 2) total_gb,
                   ROUND((total_mb - free_mb)/1024, 2) used_gb,
                   ROUND(free_mb/1024, 2) free_gb,
                   ROUND((total_mb - free_mb)/NULLIF(total_mb,0)*100, 2) used_pct
            FROM   v$asm_diskgroup
            ORDER  BY name
        """
    },
    {
        'id': 'db_files_location',
        'name': 'Database Files Location (ASM vs OS)',
        'sql': """
            SELECT CASE WHEN name LIKE '+%' THEN 'ASM' ELSE 'OS Filesystem' END file_system,
                   COUNT(*) file_count,
                   ROUND(SUM(bytes)/1073741824, 2) total_gb
            FROM   v$datafile
            GROUP  BY CASE WHEN name LIKE '+%' THEN 'ASM' ELSE 'OS Filesystem' END
            UNION ALL
            SELECT CASE WHEN name LIKE '+%' THEN 'ASM' ELSE 'OS Filesystem' END,
                   COUNT(*), ROUND(SUM(bytes)/1073741824, 2)
            FROM   v$tempfile
            GROUP  BY CASE WHEN name LIKE '+%' THEN 'ASM' ELSE 'OS Filesystem' END
            UNION ALL
            SELECT CASE WHEN member LIKE '+%' THEN 'ASM' ELSE 'OS Filesystem' END,
                   COUNT(*), ROUND(SUM(f.bytes)/1073741824, 2)
            FROM   v$logfile lf
            JOIN   v$log f ON f.group# = lf.group#
            GROUP  BY CASE WHEN member LIKE '+%' THEN 'ASM' ELSE 'OS Filesystem' END
        """
    },
    {
        'id': 'large_tables',
        'name': 'Large Tables (Top 30 by Size)',
        'sql': """
            SELECT owner, table_name,
                   TO_CHAR(num_rows,'999,999,999')          num_rows,
                   ROUND(blocks * 8192 / 1048576, 2)        size_mb,
                   partitioned,
                   TO_CHAR(last_analyzed,'DD-MON-YY HH24:MI') last_analyzed,
                   CASE WHEN last_analyzed < SYSDATE - 30
                        THEN 'STALE' ELSE 'OK' END          stats_status
            FROM   dba_tables
            WHERE  owner NOT IN (
                       'SYS','SYSTEM','DBSNMP','OUTLN','MDSYS','ORDSYS','EXFSYS',
                       'WMSYS','CTXSYS','XDB','SYSMAN','APEX_PUBLIC_USER','APPQOSSYS',
                       'AUDSYS','GSMADMIN_INTERNAL','LBACSYS','OJVMSYS','ORDDATA'
                   )
            AND    blocks > 1000
            ORDER  BY blocks DESC NULLS LAST
            FETCH  FIRST 30 ROWS ONLY
        """
    },
    {
        'id': 'large_indexes',
        'name': 'Large Indexes (Top 30 by Size)',
        'sql': """
            SELECT i.owner, i.index_name, i.table_name,
                   i.index_type, i.uniqueness,
                   i.blevel, i.leaf_blocks,
                   ROUND(i.leaf_blocks * 8192 / 1048576, 2)    size_mb,
                   i.clustering_factor,
                   TO_CHAR(t.num_rows,'999,999,999')            table_rows,
                   ROUND(i.clustering_factor /
                         NULLIF(t.num_rows,0), 4)               cf_ratio,
                   i.partitioned,
                   TO_CHAR(i.last_analyzed,'DD-MON-YY HH24:MI') last_analyzed
            FROM   dba_indexes i
            LEFT JOIN dba_tables t
                   ON t.owner = i.table_owner
                  AND t.table_name = i.table_name
            WHERE  i.owner NOT IN (
                       'SYS','SYSTEM','DBSNMP','OUTLN','MDSYS','ORDSYS','EXFSYS',
                       'WMSYS','CTXSYS','XDB','SYSMAN','APPQOSSYS','AUDSYS',
                       'GSMADMIN_INTERNAL','LBACSYS','OJVMSYS','ORDDATA'
                   )
            AND    i.leaf_blocks > 500
            ORDER  BY i.leaf_blocks DESC NULLS LAST
            FETCH  FIRST 30 ROWS ONLY
        """
    },
    {
        'id': 'invalid_objects',
        'name': 'Invalid Objects',
        'sql': """
            SELECT owner, object_type,
                   COUNT(*) invalid_count,
                   LISTAGG(object_name, ', ')
                       WITHIN GROUP (ORDER BY object_name) objects
            FROM   dba_objects
            WHERE  status = 'INVALID'
              AND  owner NOT IN ('SYS','SYSTEM','DBSNMP','OUTLN','MDSYS','ORDSYS',
                                 'EXFSYS','WMSYS','CTXSYS','XDB','SYSMAN','APPQOSSYS',
                                 'AUDSYS','GSMADMIN_INTERNAL','OJVMSYS')
            GROUP  BY owner, object_type
            ORDER  BY invalid_count DESC
        """
    },
    {
        'id': 'db_links',
        'name': 'Database Links',
        'sql': """
            SELECT owner, db_link, username, host,
                   TO_CHAR(created,'DD-MON-YYYY') created
            FROM   dba_db_links
            ORDER  BY owner, db_link
        """
    },
    {
        'id': 'redo_wait_events',
        'name': 'Redo-Related Wait Events (from AWR)',
        'sql': """
            SELECT event_name,
                   ROUND(SUM(time_waited_micro)/1e6, 2) total_wait_sec,
                   SUM(total_waits)                     total_waits,
                   ROUND(SUM(time_waited_micro)/
                         NULLIF(SUM(total_waits),0)/1000, 2) avg_wait_ms
            FROM   dba_hist_system_event
            WHERE  event_name IN (
                       'log file sync', 'log file parallel write',
                       'log buffer space', 'log file switch completion',
                       'log file switch (checkpoint incomplete)',
                       'log file switch (archiving needed)',
                       'switch logfile command'
                   )
            GROUP  BY event_name
            ORDER  BY total_wait_sec DESC
        """
    },
    {
        'id': 'patch_level',
        'name': 'Database Patch Level',
        'sql': """
            SELECT ACTION, NAMESPACE, VERSION,
                   TO_CHAR(ACTION_TIME,'DD-MON-YYYY HH24:MI:SS') action_time,
                   COMMENTS
            FROM   dba_registry_history
            ORDER  BY action_time DESC
            FETCH  FIRST 10 ROWS ONLY
        """
    },
]


def run_system_study(conn_id: int, sections: list = None,
                     begin_snap: int = None, end_snap: int = None) -> dict:
    """
    Run system study queries and generate recommendations.
    sections: list of section IDs to run (None = all).
    begin_snap / end_snap: integer snap IDs for snap-range sections.
    """
    from modules.oracle_awr_fetcher import get_connection_by_id
    from modules.oracle_live_query import run_queries

    cfg = get_connection_by_id(conn_id)
    if not cfg:
        return {'ok': False, 'error': f'Connection {conn_id} not found'}

    active = SECTIONS if not sections else         [s for s in SECTIONS if s['id'] in sections]

    query_defs = []
    for s in active:
        needs_snap = s.get('snap_range', False)
        params = {}
        if needs_snap:
            if not begin_snap or not end_snap:
                # No time range — add placeholder so section appears in output
                query_defs.append({
                    'name': s['id'], 'description': s['name'],
                    'sql': "SELECT 'Select Begin/End Snap above to run this section' AS note FROM DUAL",
                    'params': {}
                })
                continue
            params = {'begin_snap': begin_snap, 'end_snap': end_snap}
        query_defs.append({'name': s['id'], 'description': s['name'],
                           'sql': s['sql'], 'params': params})

    raw = run_queries(cfg, query_defs)

    by_id = {r['name']: r for r in raw}
    result_sections = []
    for s in active:
        r = by_id.get(s['id'], {'ok': False, 'error': 'not run', 'rows': [], 'columns': []})
        result_sections.append({'id': s['id'], 'name': s['name'],
                                'snap_range': s.get('snap_range', False), **r})

    recommendations = _generate_system_recommendations(by_id)

    return {
        'ok':              True,
        'db_name':         cfg['db_name'],
        'sections':        result_sections,
        'recommendations': recommendations,
        'error':           None
    }


def _generate_system_recommendations(by_id: dict) -> list:
    """
    Generate recommendations from system study data.
    Covers: controlfile multiplexing, redo log sizing/groups,
    ASM migration, table/index partitioning.
    """
    recs = []

    # ── 1. Controlfile multiplexing ───────────────────────────────────────────
    cf = by_id.get('controlfiles', {})
    if cf.get('ok') and cf.get('rows'):
        cf_count = len(cf['rows'])
        # Get unique locations (directory paths)
        locations = set()
        for row in cf['rows']:
            loc = row.get('location') or row.get('name','')
            # Get directory
            import os
            locations.add(os.path.dirname(str(loc)))

        if cf_count < 2:
            recs.append({
                'severity':       'Critical',
                'category':       'Controlfile',
                'section':        'Controlfile Information',
                'finding':        f'Only {cf_count} controlfile found. Oracle requires at least 2 copies.',
                'recommendation': (
                    'Add a second controlfile copy immediately. '
                    'Steps: '
                    '1. SHUTDOWN IMMEDIATE; '
                    '2. Copy the controlfile to a second location; '
                    '3. Add the new path to CONTROL_FILES parameter; '
                    '4. STARTUP.'
                ),
                'command': "ALTER SYSTEM SET CONTROL_FILES='<path1>','<path2>' SCOPE=SPFILE;"
            })
        elif cf_count < 3:
            recs.append({
                'severity':       'Warning',
                'category':       'Controlfile',
                'section':        'Controlfile Information',
                'finding':        f'{cf_count} controlfiles found. Oracle best practice recommends 3 copies on separate disks/ASM diskgroups.',
                'recommendation': (
                    'Add a third controlfile copy on a separate disk or ASM diskgroup '
                    'to protect against disk failure.'
                ),
                'command': "ALTER SYSTEM SET CONTROL_FILES='<path1>','<path2>','<path3>' SCOPE=SPFILE;"
            })

        if len(locations) < 2 and cf_count >= 2:
            recs.append({
                'severity':       'Alert',
                'category':       'Controlfile',
                'section':        'Controlfile Information',
                'finding':        'Multiple controlfiles exist but all are on the same filesystem/location.',
                'recommendation': (
                    'Controlfile copies must be on separate disks or ASM diskgroups. '
                    'If one disk fails, Oracle cannot open the database without all controlfiles. '
                    'Move one copy to a different physical location.'
                ),
                'command': None
            })

    # ── 2. Redo log sizing and group count ────────────────────────────────────
    rl = by_id.get('redo_logs', {})
    ls = by_id.get('log_switches', {})
    rw = by_id.get('redo_wait_events', {})

    if rl.get('ok') and rl.get('rows'):
        # Count unique groups and members per group
        groups = {}
        for row in rl['rows']:
            g = row.get('group#')
            if g not in groups:
                groups[g] = {'size_mb': row.get('size_mb', 0), 'members': 0}
            groups[g]['members'] += 1

        group_count  = len(groups)
        min_size_mb  = min(g['size_mb'] for g in groups.values()) if groups else 0
        min_members  = min(g['members'] for g in groups.values()) if groups else 0

        # Redo log size recommendation
        if min_size_mb < 200:
            recs.append({
                'severity':       'Alert',
                'category':       'Redo Log',
                'section':        'Online Redo Log Information',
                'finding':        f'Redo log size is {min_size_mb:.0f} MB — too small for a busy OLTP database. '
                                  f'Small redo logs cause frequent log switches.',
                'recommendation': (
                    'Increase redo log size to at least 500 MB per group (1 GB recommended for busy systems). '
                    'Steps: '
                    '1. Add new larger log groups; '
                    '2. Switch logs until old groups become INACTIVE; '
                    '3. Drop old groups; '
                    '4. Repeat until all groups are the new size.'
                ),
                'command': (
                    "ALTER DATABASE ADD LOGFILE GROUP 10 "
                    "('/u01/oradata/redo10a.log','/u02/oradata/redo10b.log') SIZE 1024M;\n"
                    "-- After all old groups are INACTIVE:\n"
                    "ALTER DATABASE DROP LOGFILE GROUP <old_group#>;"
                )
            })
        elif min_size_mb < 500:
            recs.append({
                'severity':       'Warning',
                'category':       'Redo Log',
                'section':        'Online Redo Log Information',
                'finding':        f'Redo log size is {min_size_mb:.0f} MB. Consider increasing to 500 MB–1 GB for high-throughput systems.',
                'recommendation': 'Monitor log switch frequency. If switches exceed 4–6 per hour during peak, increase log size.',
                'command': None
            })

        # Group count recommendation
        if group_count < 4:
            recs.append({
                'severity':       'Warning',
                'category':       'Redo Log',
                'section':        'Online Redo Log Information',
                'finding':        f'Only {group_count} redo log groups. Oracle recommends at least 4–6 groups to prevent log switch waits.',
                'recommendation': (
                    f'Add {max(0, 4 - group_count)} more redo log groups. '
                    'Having too few groups means Oracle may wait for LGWR to finish archiving '
                    'before switching — causing "log file switch" waits.'
                ),
                'command': (
                    "ALTER DATABASE ADD LOGFILE GROUP <n> "
                    "('/<path>/redo_na.log','/<path>/redo_nb.log') SIZE 1024M;"
                )
            })

        # Members per group (multiplexing)
        if min_members < 2:
            recs.append({
                'severity':       'Alert',
                'category':       'Redo Log',
                'section':        'Online Redo Log Information',
                'finding':        'Some redo log groups have only 1 member (not multiplexed).',
                'recommendation': (
                    'Add a second member to each redo log group on a separate disk. '
                    'Loss of the only member of an active log group requires RESETLOGS recovery.'
                ),
                'command': "ALTER DATABASE ADD LOGFILE MEMBER '/<path>/redo_<n>b.log' TO GROUP <n>;"
            })

    # ── 3. Log switch frequency analysis ─────────────────────────────────────
    if ls.get('ok') and ls.get('rows'):
        max_hourly = 0
        busy_hour = None
        for row in ls['rows']:
            for h in [f'h{str(i).zfill(2)}' for i in range(24)]:
                v = int(row.get(h) or 0)
                if v > max_hourly:
                    max_hourly = v
                    busy_hour  = h

        if max_hourly > 25:
            recs.append({
                'severity':       'Critical',
                'category':       'Redo Log Switches',
                'section':        'Hourly Log Switches (Last 7 Days)',
                'finding':        f'Peak log switches: {max_hourly} switches in one hour (hour {busy_hour}). '
                                  f'More than 25 switches/hour indicates redo logs are critically undersized.',
                'recommendation': (
                    f'Redo logs are switching {max_hourly} times per hour at peak. '
                    'This causes "log file switch completion" and "log file switch (checkpoint incomplete)" waits. '
                    'Increase redo log size significantly — target less than 10 switches per hour. '
                    'Calculate: if peak redo generation is X MB/hour, each log should be at least X/10 MB.'
                ),
                'command': None
            })
        elif max_hourly > 10:
            recs.append({
                'severity':       'Warning',
                'category':       'Redo Log Switches',
                'section':        'Hourly Log Switches (Last 7 Days)',
                'finding':        f'Peak log switches: {max_hourly} switches/hour. '
                                  f'Consider increasing redo log size if this is causing performance impact.',
                'recommendation': (
                    'More than 10 switches/hour may indicate redo logs are undersized for peak workload. '
                    'Monitor for "log file switch" wait events. '
                    'Balance redo log size against recovery time — larger logs mean longer instance recovery. '
                    'A practical target is 10–25 switches/hour for OLTP systems.'
                ),
                'command': None
            })

    # ── 4. Redo wait events ───────────────────────────────────────────────────
    if rw.get('ok') and rw.get('rows'):
        for row in rw['rows']:
            event   = row.get('event_name','')
            wait_s  = float(row.get('total_wait_sec') or 0)
            avg_ms  = float(row.get('avg_wait_ms') or 0)

            if event == 'log file sync' and avg_ms > 20:
                recs.append({
                    'severity':       'Critical' if avg_ms > 50 else 'Alert',
                    'category':       'Redo Wait',
                    'section':        'Redo-Related Wait Events (from AWR)',
                    'finding':        f'"log file sync" average wait: {avg_ms:.1f} ms (total: {wait_s:.0f}s). '
                                      f'This directly impacts COMMIT response time.',
                    'recommendation': (
                        f'Average commit wait of {avg_ms:.1f} ms is {"critically" if avg_ms > 50 else ""} high. '
                        'Check: 1. Disk I/O performance for redo log location '
                        '(redo logs should be on the fastest available storage). '
                        '2. Consider ASM Normal Redundancy for redo logs. '
                        '3. Check for excessive COMMIT frequency — batch commits where possible. '
                        '4. Verify redo log is not on the same disk as datafiles.'
                    ),
                    'command': None
                })

            if event in ('log file switch (checkpoint incomplete)',
                         'log file switch (archiving needed)') and wait_s > 10:
                recs.append({
                    'severity':       'Critical',
                    'category':       'Redo Wait',
                    'section':        'Redo-Related Wait Events (from AWR)',
                    'finding':        f'"{event}" detected ({wait_s:.0f}s total wait). '
                                      f'Oracle is waiting before it can reuse a redo log group.',
                    'recommendation': (
                        'This event means Oracle cannot switch to the next log group because: '
                        '(a) checkpoint has not completed — increase log_checkpoint_interval or '
                        'add more redo groups, or '
                        '(b) archiving is behind — check ARCn processes and archive destination I/O.'
                    ),
                    'command': None
                })

    # ── 5. ASM migration recommendation ──────────────────────────────────────
    loc = by_id.get('db_files_location', {})
    asm = by_id.get('asm_diskgroups', {})
    if loc.get('ok') and loc.get('rows'):
        os_files = [r for r in loc['rows'] if r.get('file_system') == 'OS Filesystem']
        asm_files = [r for r in loc['rows'] if r.get('file_system') == 'ASM']
        has_asm   = bool(asm.get('ok') and asm.get('rows'))
        os_gb     = sum(float(r.get('total_gb') or 0) for r in os_files)

        if os_files and not asm_files:
            severity = 'Alert' if os_gb > 100 else 'Warning'
            recs.append({
                'severity':       severity,
                'category':       'Storage',
                'section':        'Database Files Location (ASM vs OS)',
                'finding':        f'All database files ({os_gb:.1f} GB) are on OS filesystem. '
                                  f'No ASM diskgroups in use.',
                'recommendation': (
                    'Oracle ASM provides significant advantages over OS filesystem storage: '
                    '1. Automatic striping and mirroring without OS LVM configuration; '
                    '2. Online disk rebalancing without downtime; '
                    '3. Better I/O performance through ASM intelligent data placement; '
                    '4. Simplified storage management — no filesystem maintenance. '
                    'Consider migrating to ASM using RMAN BACKUP AS COPY + SWITCH DATAFILE TO COPY. '
                    'Note: ASM requires Oracle Grid Infrastructure installation.'
                ),
                'command': (
                    "-- RMAN migration to ASM:\n"
                    "BACKUP AS COPY DATABASE FORMAT '+DATA';\n"
                    "SWITCH DATABASE TO COPY;\n"
                    "RECOVER DATABASE;"
                )
            })
        elif os_files and asm_files:
            recs.append({
                'severity':       'Warning',
                'category':       'Storage',
                'section':        'Database Files Location (ASM vs OS)',
                'finding':        'Mixed storage: some files on OS filesystem, some on ASM.',
                'recommendation': (
                    'Migrate remaining OS filesystem files to ASM for consistent storage management. '
                    'Mixed storage makes backup and recovery procedures more complex.'
                ),
                'command': None
            })

    # ── 6. Table/Index partitioning recommendations ───────────────────────────
    lt = by_id.get('large_tables', {})
    li = by_id.get('large_indexes', {})

    if lt.get('ok') and lt.get('rows'):
        for row in lt['rows']:
            size_mb = float(row.get('size_mb') or 0)
            partitioned = str(row.get('partitioned','')).upper()
            num_rows_str = str(row.get('num_rows','')).replace(',','')
            try:
                num_rows = int(num_rows_str)
            except ValueError:
                num_rows = 0

            if size_mb > 10240 and partitioned == 'NO':
                obj = f"{row.get('owner','')}.{row.get('table_name','')}"
                recs.append({
                    'severity':       'Critical' if size_mb > 51200 else 'Alert',
                    'category':       'Partitioning',
                    'section':        'Large Tables (Top 30 by Size)',
                    'finding':        f'Table {obj}: {size_mb/1024:.1f} GB, '
                                      f'{row.get("num_rows","?")} rows — not partitioned. '
                                      f'Tables over 10 GB are strong candidates for partitioning.',
                    'recommendation': (
                        f'Table {obj} ({size_mb/1024:.1f} GB) is a strong candidate for partitioning. '
                        'Benefits: partition pruning eliminates I/O for date-range queries, '
                        'partition-level statistics and maintenance, parallel query improvement. '
                        'Recommended strategy: '
                        '1. RANGE partitioning on a date column if data has a natural date range; '
                        '2. LIST partitioning on a status/region column for categorical data; '
                        '3. RANGE-HASH composite for very large tables with mixed access patterns. '
                        'Note: Partitioning requires the Oracle Partitioning option license.'
                    ),
                    'command': (
                        f"-- Example Range partitioning on {obj}:\n"
                        f"ALTER TABLE {obj} MODIFY\n"
                        f"  PARTITION BY RANGE (date_column) INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))\n"
                        f"  (PARTITION p_initial VALUES LESS THAN "
                        f"(TO_DATE('2020-01-01','YYYY-MM-DD')));"
                    )
                })

    if li.get('ok') and li.get('rows'):
        for row in li['rows']:
            size_mb     = float(row.get('size_mb') or 0)
            blevel      = int(row.get('blevel') or 0)
            cf_ratio    = float(row.get('cf_ratio') or 0)
            partitioned = str(row.get('partitioned','')).upper()
            obj         = f"{row.get('owner','')}.{row.get('index_name','')}"

            if blevel > 4:
                recs.append({
                    'severity':       'Alert',
                    'category':       'Index',
                    'section':        'Large Indexes (Top 30 by Size)',
                    'finding':        f'Index {obj}: BLEVEL={blevel} — deep B-tree (> 4 levels) causing excess block reads per lookup.',
                    'recommendation': (
                        f'Rebuild index {obj} (BLEVEL={blevel}). '
                        'ALTER INDEX ... REBUILD ONLINE reduces height and can improve query performance. '
                        'Schedule during low-activity period. '
                        'If table is partitioned, consider making this a local partitioned index.'
                    ),
                    'command': f"ALTER INDEX {obj} REBUILD ONLINE;"
                })

            if cf_ratio > 0.5 and size_mb > 100:
                recs.append({
                    'severity':       'Warning',
                    'category':       'Index',
                    'section':        'Large Indexes (Top 30 by Size)',
                    'finding':        f'Index {obj}: clustering factor ratio={cf_ratio:.2f} (> 0.5 indicates poor data ordering relative to index).',
                    'recommendation': (
                        f'Poor clustering factor on {obj} means range scans cause near-random I/O. '
                        'Options: '
                        '1. Reorganize the table in index key order (table reorg); '
                        '2. If range scans are rare, accept the cost; '
                        '3. For very large tables, consider a partitioning strategy that aligns with the index key.'
                    ),
                    'command': None
                })

            if size_mb > 2048 and partitioned == 'NO':
                obj_full = f"{row.get('owner','')}.{row.get('index_name','')} on {row.get('table_name','')}"
                recs.append({
                    'severity':       'Warning',
                    'category':       'Partitioning',
                    'section':        'Large Indexes (Top 30 by Size)',
                    'finding':        f'Index {obj_full}: {size_mb:.0f} MB — not partitioned.',
                    'recommendation': (
                        f'Consider converting {obj} to a local partitioned index '
                        'if the underlying table is or will be partitioned. '
                        'Local indexes are partition-maintained and allow partition-level operations.'
                    ),
                    'command': (
                        f"-- Convert to local index (table must be partitioned first):\n"
                        f"ALTER INDEX {obj} REBUILD PARTITION p_initial;"
                    )
                })

    # ── 7. Invalid objects ────────────────────────────────────────────────────
    inv = by_id.get('invalid_objects', {})
    if inv.get('ok') and inv.get('rows'):
        total_invalid = sum(int(r.get('invalid_count', 0)) for r in inv['rows'])
        if total_invalid > 0:
            recs.append({
                'severity':       'Alert',
                'category':       'Object Validity',
                'section':        'Invalid Objects',
                'finding':        f'{total_invalid} invalid objects found across application schemas.',
                'recommendation': (
                    'Invalid objects cause runtime errors and may indicate missed dependency recompilation '
                    'after DDL changes. Run: '
                    'EXEC UTL_RECOMP.RECOMP_SERIAL(); to recompile all invalid objects. '
                    'Investigate any that remain invalid after recompilation.'
                ),
                'command': 'EXEC UTL_RECOMP.RECOMP_SERIAL();'
            })

    return recs


# ── Additional sections from scripts1.zip ────────────────────────────────────
# Appended to SECTIONS list at module load
_EXTRA_SECTIONS = [
    # ── Snap-range based (Group B) ────────────────────────────────────────────
    {
        'id': 'hot_blocks',
        'name': 'Hot Block Detection (Cluster Waits by Object)',
        'snap_range': True,
        'sql': """
            WITH snap_range AS (
                SELECT snap_id FROM dba_hist_snapshot
                WHERE snap_id BETWEEN :begin_snap AND :end_snap
            )
            SELECT o.owner, o.object_name, o.object_type,
                   COUNT(*) cluster_samples
            FROM dba_hist_active_sess_history a
            JOIN snap_range s ON s.snap_id = a.snap_id
            JOIN dba_objects o ON o.object_id = a.current_obj#
            WHERE a.wait_class = 'Cluster'
            GROUP BY o.owner, o.object_name, o.object_type
            ORDER BY cluster_samples DESC
            FETCH FIRST 20 ROWS ONLY
        """
    },
    {
        'id': 'hot_indexes',
        'name': 'Hot Indexes (Cluster Waits)',
        'snap_range': True,
        'sql': """
            WITH snap_range AS (
                SELECT snap_id FROM dba_hist_snapshot
                WHERE snap_id BETWEEN :begin_snap AND :end_snap
            )
            SELECT o.owner, o.object_name index_name,
                   COUNT(*) cluster_samples
            FROM dba_hist_active_sess_history a
            JOIN snap_range s ON s.snap_id = a.snap_id
            JOIN dba_objects o ON o.object_id = a.current_obj#
            WHERE a.wait_class = 'Cluster'
              AND o.object_type = 'INDEX'
            GROUP BY o.owner, o.object_name
            ORDER BY cluster_samples DESC
            FETCH FIRST 20 ROWS ONLY
        """
    },
    {
        'id': 'reverse_key_candidates',
        'name': 'Hot Index — Reverse Key Candidates',
        'snap_range': True,
        'sql': """
            WITH snap_range AS (
                SELECT snap_id FROM dba_hist_snapshot
                WHERE snap_id BETWEEN :begin_snap AND :end_snap
            ),
            hot_indexes AS (
                SELECT o.object_id, o.owner, o.object_name,
                       COUNT(*) cluster_samples
                FROM dba_hist_active_sess_history a
                JOIN snap_range s ON s.snap_id = a.snap_id
                JOIN dba_objects o ON o.object_id = a.current_obj#
                WHERE a.wait_class = 'Cluster'
                  AND o.object_type = 'INDEX'
                GROUP BY o.object_id, o.owner, o.object_name
                HAVING COUNT(*) > 100
            )
            SELECT h.owner, h.object_name index_name,
                   h.cluster_samples,
                   ic.table_name,
                   ic.column_name leading_column,
                   i.index_type,
                   NVL(i.reverse,'N') is_reverse,
                   CASE
                       WHEN i.index_type = 'NORMAL'
                        AND ic.column_position = 1
                        AND ic.column_name LIKE '%ID%'
                       THEN '*** REVERSE KEY CANDIDATE ***'
                       ELSE 'Review'
                   END recommendation
            FROM hot_indexes h
            JOIN dba_indexes i ON i.owner = h.owner AND i.index_name = h.object_name
            JOIN dba_ind_columns ic ON ic.index_owner = h.owner
              AND ic.index_name = h.object_name AND ic.column_position = 1
            ORDER BY h.cluster_samples DESC
        """
    },
    {
        'id': 'hot_tables_cluster',
        'name': 'Hot Tables — Cluster Waits',
        'snap_range': True,
        'sql': """
            WITH snap_range AS (
                SELECT snap_id FROM dba_hist_snapshot
                WHERE snap_id BETWEEN :begin_snap AND :end_snap
            )
            SELECT o.owner, o.object_name, o.object_type,
                   COUNT(*) cluster_samples
            FROM dba_hist_active_sess_history a
            JOIN snap_range s ON s.snap_id = a.snap_id
            JOIN dba_objects o ON o.object_id = a.current_obj#
            WHERE a.wait_class = 'Cluster'
              AND o.object_type = 'TABLE'
            GROUP BY o.owner, o.object_name, o.object_type
            ORDER BY cluster_samples DESC
            FETCH FIRST 20 ROWS ONLY
        """
    },
    {
        'id': 'gc_event_breakdown',
        'name': 'GC Event Breakdown (Top SQL per GC Event)',
        'snap_range': True,
        'sql': """
            WITH snap_range AS (
                SELECT snap_id FROM dba_hist_snapshot
                WHERE snap_id BETWEEN :begin_snap AND :end_snap
            )
            SELECT * FROM (
                SELECT a.sql_id, a.event,
                       COUNT(*) samples,
                       ROW_NUMBER() OVER (
                           PARTITION BY a.event ORDER BY COUNT(*) DESC
                       ) rn
                FROM dba_hist_active_sess_history a
                JOIN snap_range s ON s.snap_id = a.snap_id
                WHERE a.wait_class = 'Cluster'
                  AND a.event IN (
                      'gc current block busy','gc current block 2-way',
                      'gc current block 3-way','gc cr block busy',
                      'gc cr block 2-way','gc cr block 3-way'
                  )
                GROUP BY a.sql_id, a.event
            ) WHERE rn <= 10
            ORDER BY event, samples DESC
        """
    },
    {
        'id': 'gc_severity',
        'name': 'GC Event Severity Summary',
        'snap_range': True,
        'sql': """
            WITH snap_range AS (
                SELECT snap_id FROM dba_hist_snapshot
                WHERE snap_id BETWEEN :begin_snap AND :end_snap
            )
            SELECT event,
                   COUNT(*) samples,
                   ROUND(COUNT(*)/SUM(COUNT(*)) OVER()*100,2) pct
            FROM dba_hist_active_sess_history a
            JOIN snap_range s ON s.snap_id = a.snap_id
            WHERE a.wait_class = 'Cluster'
            GROUP BY event
            ORDER BY samples DESC
        """
    },
    {
        'id': 'rac_skew',
        'name': 'RAC Load Skew by SQL and Instance',
        'snap_range': True,
        'sql': """
            WITH snap_range AS (
                SELECT snap_id FROM dba_hist_snapshot
                WHERE snap_id BETWEEN :begin_snap AND :end_snap
            )
            SELECT a.sql_id, a.instance_number, COUNT(*) samples
            FROM dba_hist_active_sess_history a
            JOIN snap_range s ON s.snap_id = a.snap_id
            WHERE a.sql_id IS NOT NULL
            GROUP BY a.sql_id, a.instance_number
            ORDER BY a.sql_id, samples DESC
            FETCH FIRST 50 ROWS ONLY
        """
    },
    {
        'id': 'instance_wise_objects',
        'name': 'Cluster Waits by Object and Instance',
        'snap_range': True,
        'sql': """
            WITH snap_range AS (
                SELECT snap_id FROM dba_hist_snapshot
                WHERE snap_id BETWEEN :begin_snap AND :end_snap
            )
            SELECT o.owner, o.object_name, a.instance_number,
                   COUNT(*) samples
            FROM dba_hist_active_sess_history a
            JOIN snap_range s ON s.snap_id = a.snap_id
            JOIN dba_objects o ON o.object_id = a.current_obj#
            WHERE a.wait_class = 'Cluster'
            GROUP BY o.owner, o.object_name, a.instance_number
            ORDER BY o.owner, o.object_name, samples DESC
            FETCH FIRST 50 ROWS ONLY
        """
    },
    {
        'id': 'pk_hot_sequence',
        'name': 'Hot PK Indexes Driven by Sequence',
        'snap_range': True,
        'sql': """
            WITH snap_range AS (
                SELECT snap_id FROM dba_hist_snapshot
                WHERE snap_id BETWEEN :begin_snap AND :end_snap
            ),
            hot_indexes AS (
                SELECT o.owner, o.object_name, COUNT(*) cluster_samples
                FROM dba_hist_active_sess_history a
                JOIN snap_range s ON s.snap_id = a.snap_id
                JOIN dba_objects o ON o.object_id = a.current_obj#
                WHERE a.wait_class = 'Cluster' AND o.object_type = 'INDEX'
                GROUP BY o.owner, o.object_name
                HAVING COUNT(*) > 100
            ),
            pk_indexes AS (
                SELECT c.owner, c.table_name, c.constraint_name,
                       i.index_name, ic.column_name
                FROM dba_constraints c
                JOIN dba_indexes i ON c.owner = i.owner
                  AND c.constraint_name = i.index_name
                JOIN dba_ind_columns ic ON i.owner = ic.index_owner
                  AND i.index_name = ic.index_name AND ic.column_position = 1
                WHERE c.constraint_type = 'P'
            )
            SELECT h.owner, h.object_name index_name,
                   h.cluster_samples, p.table_name, p.column_name leading_column,
                   'LIKELY SEQUENCE-BASED HOT PK — consider REVERSE KEY or HASH partitioning'
                       recommendation
            FROM hot_indexes h
            JOIN pk_indexes p ON p.owner = h.owner AND p.index_name = h.object_name
            ORDER BY h.cluster_samples DESC
        """
    },
    {
        'id': 'hot_objects_recommendation',
        'name': 'Hot Objects — Reverse/Hash Partition Candidates',
        'snap_range': True,
        'sql': """
            WITH snap_range AS (
                SELECT snap_id FROM dba_hist_snapshot
                WHERE snap_id BETWEEN :begin_snap AND :end_snap
            ),
            hot_objects AS (
                SELECT o.owner, o.object_name, o.object_type,
                       COUNT(*) cluster_samples
                FROM dba_hist_active_sess_history a
                JOIN snap_range s ON s.snap_id = a.snap_id
                JOIN dba_objects o ON o.object_id = a.current_obj#
                WHERE a.wait_class = 'Cluster'
                GROUP BY o.owner, o.object_name, o.object_type
                HAVING COUNT(*) > 200
            )
            SELECT h.owner, h.object_name, h.object_type,
                   h.cluster_samples,
                   CASE
                       WHEN h.object_type = 'INDEX' THEN 'CHECK REVERSE INDEX'
                       WHEN h.object_type = 'TABLE' THEN 'CHECK HASH PARTITIONING'
                       ELSE 'REVIEW'
                   END recommendation
            FROM hot_objects h
            ORDER BY h.cluster_samples DESC
        """
    },
    # ── No snap range (Group C) ────────────────────────────────────────────────
    {
        'id': 'service_imbalance',
        'name': 'Service Load Imbalance (RAC)',
        'snap_range': False,
        'sql': """
            SELECT s.name service_name, a.instance_number,
                   COUNT(*) samples
            FROM dba_hist_active_sess_history a
            JOIN dba_services s ON a.service_hash = s.name_hash
            GROUP BY s.name, a.instance_number
            ORDER BY s.name, samples DESC
            FETCH FIRST 50 ROWS ONLY
        """
    },
    {
        'id': 'block_ping_by_sql',
        'name': 'Block Ping by SQL (Top Cluster Wait SQLs)',
        'snap_range': False,
        'sql': """
            SELECT sql_id,
                   ROUND(SUM(clwait_delta)/1e6,2) cluster_sec
            FROM dba_hist_sqlstat
            GROUP BY sql_id
            ORDER BY cluster_sec DESC
            FETCH FIRST 20 ROWS ONLY
        """
    },
    {
        'id': 'object_level_ping',
        'name': 'Object Level Block Ping (Full History)',
        'snap_range': False,
        'sql': """
            SELECT o.owner, o.object_name, COUNT(*) cluster_samples
            FROM dba_hist_active_sess_history a
            JOIN dba_objects o ON o.object_id = a.current_obj#
            WHERE a.wait_class = 'Cluster'
            GROUP BY o.owner, o.object_name
            ORDER BY cluster_samples DESC
            FETCH FIRST 20 ROWS ONLY
        """
    },
    {
        'id': 'instance_level_ping',
        'name': 'Instance Level Cluster Wait Distribution',
        'snap_range': False,
        'sql': """
            SELECT instance_number, COUNT(*) samples
            FROM dba_hist_active_sess_history
            WHERE wait_class = 'Cluster'
            GROUP BY instance_number
            ORDER BY samples DESC
        """
    },
    {
        'id': 'grd_remaster_stats',
        'name': 'GRD Remaster Statistics (RAC only)',
        'snap_range': False,
        'sql': """
            SELECT name, SUM(value) total_value
            FROM gv$sysstat
            WHERE name LIKE 'gc%master%'
            GROUP BY name
            ORDER BY total_value DESC
        """
    },
    {
        'id': 'ges_tm_remaster',
        'name': 'GES TM Resource Remastering (RAC only)',
        'snap_range': False,
        'sql': """
            SELECT inst_id, resource_name, master_node
            FROM gv$ges_resource
            WHERE resource_name LIKE 'TM-%'
            FETCH FIRST 20 ROWS ONLY
        """
    },
    {
        'id': 'ges_tx_remaster',
        'name': 'GES TX Block Mastering (RAC only)',
        'snap_range': False,
        'sql': """
            SELECT inst_id, resource_name, master_node
            FROM gv$ges_resource
            WHERE resource_name LIKE 'TX-%'
            FETCH FIRST 20 ROWS ONLY
        """
    },
]

# Append to main SECTIONS list
SECTIONS.extend(_EXTRA_SECTIONS)
