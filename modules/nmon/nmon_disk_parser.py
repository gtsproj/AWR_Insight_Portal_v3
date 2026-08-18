# modules/nmon/nmon_disk_parser.py
# Parses NMON disk I/O — DISKBUSY, DISKREAD, DISKWRITE sections.
# Mirrors modules/sar/sar_disk_parser.py.
#
# Unlike SAR (one line per disk per snapshot), NMON spreads disk
# metrics across three separate sections, each with the disk names
# as its header row:
#   DISKBUSY,Disk %Busy,sda,sdb,sdc
#   DISKREAD,Disk Read KB/s,sda,sdb,sdc
#   DISKWRITE,Disk Write KB/s,sda,sdb,sdc
#   DISKBUSY,T0001,2.1,0.5,0.3
#   DISKREAD,T0001,120.5,15.2,8.0
#   DISKWRITE,T0001,45.3,8.1,2.0
# These are merged here into one row per (snap_time, disk_name).

import os
import sys

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))

from db import get_db_connection
from logger_utils import get_logger

sys.path.insert(0, os.path.dirname(__file__))
from nmon_common import NmonContext, iter_section_rows, row_hash, sanitize_record, _sf

logger = get_logger('nmon_disk_parser')


def parse_nmon_disk(lines: list, ctx: NmonContext) -> list:
    merged = {}  # (snap_time, disk_name) -> dict

    def _merge_section(section_name, field_key):
        disk_names = ctx.headers.get(section_name, [])
        for snap_time, fields in iter_section_rows(lines, section_name, ctx):
            for i, disk_name in enumerate(disk_names):
                if i >= len(fields):
                    continue
                key = (snap_time, disk_name)
                if key not in merged:
                    merged[key] = {
                        'hostname': ctx.hostname, 'snap_time': snap_time,
                        'disk_name': disk_name, 'busy_pct': None,
                        'read_kbs': None, 'write_kbs': None, 'xfers_per_sec': None,
                    }
                merged[key][field_key] = _sf(fields[i])

    _merge_section('DISKBUSY',  'busy_pct')
    _merge_section('DISKREAD',  'read_kbs')
    _merge_section('DISKWRITE', 'write_kbs')
    _merge_section('DISKXFER',  'xfers_per_sec')  # not all nmon versions have this

    records = list(merged.values())
    for rec in records:
        rec['row_hash'] = row_hash(rec)

    logger.info(f'Parsed {len(records)} disk rows for {ctx.hostname}')
    return records


def insert_nmon_disk(records: list):
    if not records:
        logger.warning('No NMON disk records to insert')
        return

    records = [sanitize_record(r) for r in records]
    sql = """
        INSERT INTO nmon_disk_stats
            (hostname, snap_time, disk_name, busy_pct, read_kbs,
             write_kbs, xfers_per_sec, row_hash)
        VALUES
            (%(hostname)s, %(snap_time)s, %(disk_name)s, %(busy_pct)s, %(read_kbs)s,
             %(write_kbs)s, %(xfers_per_sec)s, %(row_hash)s)
        ON CONFLICT (hostname, snap_time, disk_name, row_hash) DO NOTHING
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.executemany(sql, records)
        conn.commit()
        logger.info(f'Inserted {len(records)} NMON disk rows')
    except Exception as e:
        if conn:
            conn.rollback()
        logger.error(f'NMON disk insert failed: {e}', exc_info=True)
    finally:
        if conn:
            conn.close()
