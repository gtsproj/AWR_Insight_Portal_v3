# modules/nmon/nmon_paging_parser.py
# ============================================================
# Parses the NMON PAGE section. Mirrors sar_paging_parser.py.
#
# NMON PAGE section is Linux-only. Field names and availability vary
# more than other sections — AIX NMON may not have PAGE at all, or
# may have different field names. Parser matches by keyword and
# leaves unavailable fields NULL rather than guessing.
#
# Typical PAGE header (Linux NMON):
#   PAGE,Paging,,faults,pgin,pgout,pgsin,pgsout,reclaims,scans,cycles
# Typical PAGE data:
#   PAGE,T0001,,142,10,8,0,0,130,0,0
#
# Oracle relevance:
#   pgsin/pgsout > 0 = active swap I/O = memory pressure on the host
#   faults spike + pgsin spike = Oracle PGA under memory pressure
#   Correlates directly with SAR sar_paging_stats.majflt_per_sec
# ============================================================

import os
import sys

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))

from db import get_db_connection
from logger_utils import get_logger

sys.path.insert(0, os.path.dirname(__file__))
from nmon_common import NmonContext, iter_section_rows, row_hash, sanitize_record, _sf

logger = get_logger('nmon_paging_parser')


def _col_idx(header, *names):
    for i, h in enumerate(header):
        hl = h.lower().replace('-', '').replace('_', '').replace(' ', '').replace('/', '')
        if any(n.lower().replace('-', '').replace('_', '').replace('/', '') in hl
               for n in names):
            return i
    return None


def parse_nmon_paging(lines: list, ctx: NmonContext) -> list:
    """
    Extract paging stats from NMON's PAGE section.
    Columns matched by keyword — available fields are captured,
    missing fields stored as NULL (not a parse error).
    """
    records = []
    header  = ctx.headers.get('PAGE', [])

    if not header:
        logger.info(f'PAGE section not found in NMON file for {ctx.hostname} — skipping')
        return records

    i_fault  = _col_idx(header, 'fault', 'faults')
    i_pgin   = _col_idx(header, 'pgin')
    i_pgout  = _col_idx(header, 'pgout')
    i_pgsin  = _col_idx(header, 'pgsin')
    i_pgsout = _col_idx(header, 'pgsout')
    i_scan   = _col_idx(header, 'scan', 'scans')

    for snap_time, fields in iter_section_rows(lines, 'PAGE', ctx):
        def _get(i):
            return fields[i] if i is not None and i < len(fields) else None

        rec = {
            'hostname':     ctx.hostname,
            'snap_time':    snap_time,
            'pgin_persec':   _sf(_get(i_pgin)),
            'pgout_persec':  _sf(_get(i_pgout)),
            'pgsin_persec':  _sf(_get(i_pgsin)),
            'pgsout_persec': _sf(_get(i_pgsout)),
            'fault_persec':  _sf(_get(i_fault)),
        }
        rec['row_hash'] = row_hash(rec)
        records.append(rec)

    logger.info(f'Parsed {len(records)} paging rows for {ctx.hostname}')
    return records


def insert_nmon_paging(records: list):
    if not records:
        logger.warning('No NMON paging records to insert')
        return

    records = [sanitize_record(r) for r in records]
    sql = """
        INSERT INTO nmon_paging_stats
            (hostname, snap_time, pgin_persec, pgout_persec,
             pgsin_persec, pgsout_persec, fault_persec, row_hash)
        VALUES
            (%(hostname)s, %(snap_time)s, %(pgin_persec)s, %(pgout_persec)s,
             %(pgsin_persec)s, %(pgsout_persec)s, %(fault_persec)s, %(row_hash)s)
        ON CONFLICT (hostname, snap_time, row_hash) DO NOTHING
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.executemany(sql, records)
        conn.commit()
        logger.info(f'Inserted {len(records)} NMON paging rows')
    except Exception as e:
        if conn:
            conn.rollback()
        logger.error(f'NMON paging insert failed: {e}', exc_info=True)
    finally:
        if conn:
            conn.close()
