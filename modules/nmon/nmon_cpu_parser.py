# modules/nmon/nmon_cpu_parser.py
# Parses the NMON CPU_ALL section. Mirrors modules/sar/sar_cpu_parser.py.
#
# Typical header:  CPU_ALL,CPU Total dbserver01,User%,Sys%,Wait%,Idle%,CPUs
# Typical data:    CPU_ALL,T0001,4.2,1.8,0.3,93.7,4

import os
import sys

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))

from db import get_db_connection
from logger_utils import get_logger

sys.path.insert(0, os.path.dirname(__file__))
from nmon_common import NmonContext, iter_section_rows, row_hash, sanitize_record, _sf

logger = get_logger('nmon_cpu_parser')


def parse_nmon_cpu(lines: list, ctx: NmonContext) -> list:
    records = []
    header  = ctx.headers.get('CPU_ALL', [])
    # header looks like: ['CPU Total <host>', 'User%', 'Sys%', 'Wait%', 'Idle%', 'CPUs']
    # Find column positions by name rather than assuming a fixed order —
    # different nmon versions/platforms vary slightly.
    def _idx(*names):
        for i, h in enumerate(header):
            hl = h.lower()
            if any(n in hl for n in names):
                return i
        return None

    i_user = _idx('user%', 'usr%')
    i_sys  = _idx('sys%')
    i_wait = _idx('wait%')
    i_idle = _idx('idle%')
    i_cpus = _idx('cpus')

    for snap_time, fields in iter_section_rows(lines, 'CPU_ALL', ctx):
        def _get(i):
            return fields[i] if i is not None and i < len(fields) else None

        user_pct = _sf(_get(i_user))
        sys_pct  = _sf(_get(i_sys))
        wait_pct = _sf(_get(i_wait))
        idle_pct = _sf(_get(i_idle))
        busy_pct = None
        if user_pct is not None and sys_pct is not None and wait_pct is not None:
            busy_pct = round(user_pct + sys_pct + wait_pct, 2)

        rec = {
            'hostname':  ctx.hostname,
            'snap_time': snap_time,
            'cpu':       'ALL',
            'user_pct':  user_pct,
            'sys_pct':   sys_pct,
            'wait_pct':  wait_pct,
            'idle_pct':  idle_pct,
            'busy_pct':  busy_pct,
            'cpu_count': int(_sf(_get(i_cpus))) if _sf(_get(i_cpus)) is not None else None,
        }
        rec['row_hash'] = row_hash(rec)
        records.append(rec)

    logger.info(f'Parsed {len(records)} CPU_ALL rows for {ctx.hostname}')
    return records


def insert_nmon_cpu(records: list):
    if not records:
        logger.warning('No NMON CPU records to insert')
        return

    records = [sanitize_record(r) for r in records]
    sql = """
        INSERT INTO nmon_cpu_stats
            (hostname, snap_time, cpu, user_pct, sys_pct,
             wait_pct, idle_pct, busy_pct, cpu_count, row_hash)
        VALUES
            (%(hostname)s, %(snap_time)s, %(cpu)s, %(user_pct)s, %(sys_pct)s,
             %(wait_pct)s, %(idle_pct)s, %(busy_pct)s, %(cpu_count)s, %(row_hash)s)
        ON CONFLICT (hostname, snap_time, cpu, row_hash) DO NOTHING
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.executemany(sql, records)
        conn.commit()
        logger.info(f'Inserted {len(records)} NMON CPU rows')
    except Exception as e:
        if conn:
            conn.rollback()
        logger.error(f'NMON CPU insert failed: {e}', exc_info=True)
    finally:
        if conn:
            conn.close()
