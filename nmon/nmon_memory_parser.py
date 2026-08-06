# modules/nmon/nmon_memory_parser.py
# Parses the NMON MEM section. Mirrors modules/sar/sar_memory_parser.py.
#
# Typical header:  MEM,Memory MB,memtotal,hightotal,lowtotal,swaptotal,
#                       memfree,highfree,lowfree,swapfree,memshared,
#                       cached,active,bigfree,buffers,swapcached,
#                       memavailable
# Field names vary by NMON version/platform — matched by substring
# rather than fixed position.

import os
import sys

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))

from db import get_db_connection
from logger_utils import get_logger

sys.path.insert(0, os.path.dirname(__file__))
from nmon_common import NmonContext, iter_section_rows, row_hash, sanitize_record, _sf

logger = get_logger('nmon_memory_parser')


def parse_nmon_memory(lines: list, ctx: NmonContext) -> list:
    records = []
    header  = ctx.headers.get('MEM', [])

    def _idx(*names):
        for i, h in enumerate(header):
            hl = h.lower()
            if any(n in hl for n in names):
                return i
        return None

    i_total  = _idx('memtotal')
    i_free   = _idx('memfree')
    i_cached = _idx('cached')
    i_buf    = _idx('buffers')
    i_swtot  = _idx('swaptotal')
    i_swfree = _idx('swapfree')

    for snap_time, fields in iter_section_rows(lines, 'MEM', ctx):
        def _get(i):
            return fields[i] if i is not None and i < len(fields) else None

        mem_total = _sf(_get(i_total))
        mem_free  = _sf(_get(i_free))
        cached    = _sf(_get(i_cached))
        buffers   = _sf(_get(i_buf))
        sw_total  = _sf(_get(i_swtot))
        sw_free   = _sf(_get(i_swfree))

        mem_used     = (mem_total - mem_free) if mem_total is not None and mem_free is not None else None
        mem_used_pct = round(100 * mem_used / mem_total, 2) if mem_used is not None and mem_total else None
        sw_used_pct  = (round(100 * (sw_total - sw_free) / sw_total, 2)
                        if sw_total is not None and sw_free is not None and sw_total else None)

        rec = {
            'hostname':      ctx.hostname,
            'snap_time':     snap_time,
            'mem_total_mb':  mem_total,
            'mem_free_mb':   mem_free,
            'mem_used_mb':   mem_used,
            'mem_used_pct':  mem_used_pct,
            'buffers_mb':    buffers,
            'cached_mb':     cached,
            'swap_total_mb': sw_total,
            'swap_free_mb':  sw_free,
            'swap_used_pct': sw_used_pct,
        }
        rec['row_hash'] = row_hash(rec)
        records.append(rec)

    logger.info(f'Parsed {len(records)} MEM rows for {ctx.hostname}')
    return records


def insert_nmon_memory(records: list):
    if not records:
        logger.warning('No NMON memory records to insert')
        return

    records = [sanitize_record(r) for r in records]
    sql = """
        INSERT INTO nmon_memory_stats
            (hostname, snap_time, mem_total_mb, mem_free_mb, mem_used_mb,
             mem_used_pct, buffers_mb, cached_mb, swap_total_mb,
             swap_free_mb, swap_used_pct, row_hash)
        VALUES
            (%(hostname)s, %(snap_time)s, %(mem_total_mb)s, %(mem_free_mb)s, %(mem_used_mb)s,
             %(mem_used_pct)s, %(buffers_mb)s, %(cached_mb)s, %(swap_total_mb)s,
             %(swap_free_mb)s, %(swap_used_pct)s, %(row_hash)s)
        ON CONFLICT (hostname, snap_time, row_hash) DO NOTHING
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.executemany(sql, records)
        conn.commit()
        logger.info(f'Inserted {len(records)} NMON memory rows')
    except Exception as e:
        if conn:
            conn.rollback()
        logger.error(f'NMON memory insert failed: {e}', exc_info=True)
    finally:
        if conn:
            conn.close()
