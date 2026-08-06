# modules/nmon/nmon_proc_parser.py
# ============================================================
# Parses the NMON PROC section for two things:
#   1. Run queue (Runnable) — stored in nmon_runqueue_stats
#      Analogue to SAR's runq-sz. Key DBA signal:
#      Runnable > cpu_count = CPU saturation confirmed.
#   2. Context switches (pswitch) and fork rate — stored in
#      nmon_ctxswitch_stats. Analogue to SAR's sar -w output.
#
# Note: NMON has no exponential-decay load average (ldavg-1/5/15).
#       Run queue length is the only CPU saturation signal available.
#       Hugepages and socket state counts are also not in NMON —
#       those SAR parsers have no NMON equivalent.
#
# Typical PROC header (field names vary slightly across platforms):
#   PROC,Processes,,Runnable,Blocked,pswitch,syscall,read,write,fork,exec,sem,msg
# Typical PROC data:
#   PROC,T0001,,3,0,1254,8432,102,85,12,12,0,0
# ============================================================

import os
import sys

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))

from db import get_db_connection
from logger_utils import get_logger

sys.path.insert(0, os.path.dirname(__file__))
from nmon_common import NmonContext, iter_section_rows, row_hash, sanitize_record, _sf

logger = get_logger('nmon_proc_parser')


def _col_idx(header, *names):
    """Case-insensitive keyword search across header list."""
    for i, h in enumerate(header):
        hl = h.lower().replace('-', '').replace('_', '').replace(' ', '')
        if any(n.lower().replace('-', '').replace('_', '') in hl for n in names):
            return i
    return None


# ── Run Queue ─────────────────────────────────────────────────────────────────

def parse_nmon_runqueue(lines: list, ctx: NmonContext) -> list:
    """
    Extract run queue (Runnable) and swap-in processes from the
    PROC section. One row per snapshot.
    """
    records = []
    header  = ctx.headers.get('PROC', [])

    i_runq   = _col_idx(header, 'runnable', 'runq')
    i_swapin = _col_idx(header, 'swapin', 'swap-in', 'swpin')

    if i_runq is None:
        logger.warning(f'PROC section: Runnable column not found in header {header}. '
                        f'Run queue stats will be empty.')

    for snap_time, fields in iter_section_rows(lines, 'PROC', ctx):
        def _get(i):
            return fields[i] if i is not None and i < len(fields) else None

        rec = {
            'hostname':     ctx.hostname,
            'snap_time':    snap_time,
            'runq_sz':      _sf(_get(i_runq)),
            'swapin_procs': _sf(_get(i_swapin)),
        }
        rec['row_hash'] = row_hash(rec)
        records.append(rec)

    logger.info(f'Parsed {len(records)} run-queue rows for {ctx.hostname}')
    return records


def insert_nmon_runqueue(records: list):
    if not records:
        logger.warning('No NMON run-queue records to insert')
        return

    records = [sanitize_record(r) for r in records]
    sql = """
        INSERT INTO nmon_runqueue_stats
            (hostname, snap_time, runq_sz, swapin_procs, row_hash)
        VALUES
            (%(hostname)s, %(snap_time)s, %(runq_sz)s, %(swapin_procs)s, %(row_hash)s)
        ON CONFLICT (hostname, snap_time, row_hash) DO NOTHING
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.executemany(sql, records)
        conn.commit()
        logger.info(f'Inserted {len(records)} NMON run-queue rows')
    except Exception as e:
        if conn:
            conn.rollback()
        logger.error(f'NMON run-queue insert failed: {e}', exc_info=True)
    finally:
        if conn:
            conn.close()


# ── Context Switches ──────────────────────────────────────────────────────────

def parse_nmon_ctxswitch(lines: list, ctx: NmonContext) -> list:
    """
    Extract context switches/sec (pswitch) and fork rate from the
    PROC section. One row per snapshot.

    High pswitch/s correlated with Oracle latch/mutex contention —
    same interpretation as SAR's cswch/s.
    """
    records = []
    header  = ctx.headers.get('PROC', [])

    i_pswitch = _col_idx(header, 'pswitch', 'cswch', 'ctxswitch')
    i_fork    = _col_idx(header, 'fork')
    i_exec    = _col_idx(header, 'exec')

    if i_pswitch is None:
        logger.warning(f'PROC section: pswitch column not found in header {header}. '
                        f'Context switch stats will be empty.')

    for snap_time, fields in iter_section_rows(lines, 'PROC', ctx):
        def _get(i):
            return fields[i] if i is not None and i < len(fields) else None

        rec = {
            'hostname':    ctx.hostname,
            'snap_time':   snap_time,
            'cswch_persec': _sf(_get(i_pswitch)),
            'fork_persec':  _sf(_get(i_fork)),
        }
        rec['row_hash'] = row_hash(rec)
        records.append(rec)

    logger.info(f'Parsed {len(records)} context-switch rows for {ctx.hostname}')
    return records


def insert_nmon_ctxswitch(records: list):
    if not records:
        logger.warning('No NMON context-switch records to insert')
        return

    records = [sanitize_record(r) for r in records]
    sql = """
        INSERT INTO nmon_ctxswitch_stats
            (hostname, snap_time, cswch_persec, fork_persec, row_hash)
        VALUES
            (%(hostname)s, %(snap_time)s, %(cswch_persec)s, %(fork_persec)s, %(row_hash)s)
        ON CONFLICT (hostname, snap_time, row_hash) DO NOTHING
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.executemany(sql, records)
        conn.commit()
        logger.info(f'Inserted {len(records)} NMON context-switch rows')
    except Exception as e:
        if conn:
            conn.rollback()
        logger.error(f'NMON context-switch insert failed: {e}', exc_info=True)
    finally:
        if conn:
            conn.close()
