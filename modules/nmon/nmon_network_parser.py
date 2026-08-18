# modules/nmon/nmon_network_parser.py
# Parses the NMON NET section. Mirrors modules/sar/sar_network_parser.py.
#
# Typical header:
#   NET,Network I/O,eth0-read-KB/s,eth0-write-KB/s,lo-read-KB/s,lo-write-KB/s
# Typical data:
#   NET,T0001,12.4,8.9,0.1,0.1
#
# Column names carry both the interface and the metric
# (<iface>-read-KB/s / <iface>-write-KB/s), so they're parsed apart
# here rather than needing a separate header per metric like disk does.

import os
import sys
import re

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))

from db import get_db_connection
from logger_utils import get_logger

sys.path.insert(0, os.path.dirname(__file__))
from nmon_common import NmonContext, iter_section_rows, row_hash, sanitize_record, _sf

logger = get_logger('nmon_network_parser')

_COL_RE = re.compile(r'^(.*)-(read|write)-(KB/s|Packets)$', re.IGNORECASE)


def parse_nmon_network(lines: list, ctx: NmonContext) -> list:
    header = ctx.headers.get('NET', [])

    # Map column index -> (interface, metric_key)
    col_map = {}
    for i, col in enumerate(header):
        m = _COL_RE.match(col.strip())
        if not m:
            continue
        iface, direction, unit = m.group(1), m.group(2).lower(), m.group(3).lower()
        if 'kb' in unit:
            metric_key = 'read_kbs' if direction == 'read' else 'write_kbs'
        else:
            metric_key = 'read_packets' if direction == 'read' else 'write_packets'
        col_map[i] = (iface, metric_key)

    merged = {}  # (snap_time, interface) -> dict
    for snap_time, fields in iter_section_rows(lines, 'NET', ctx):
        for i, (iface, metric_key) in col_map.items():
            if i >= len(fields):
                continue
            key = (snap_time, iface)
            if key not in merged:
                merged[key] = {
                    'hostname': ctx.hostname, 'snap_time': snap_time,
                    'interface': iface, 'read_kbs': None, 'write_kbs': None,
                    'read_packets': None, 'write_packets': None,
                }
            merged[key][metric_key] = _sf(fields[i])

    records = list(merged.values())
    for rec in records:
        rec['row_hash'] = row_hash(rec)

    logger.info(f'Parsed {len(records)} network rows for {ctx.hostname}')
    return records


def insert_nmon_network(records: list):
    if not records:
        logger.warning('No NMON network records to insert')
        return

    records = [sanitize_record(r) for r in records]
    sql = """
        INSERT INTO nmon_network_stats
            (hostname, snap_time, interface, read_kbs, write_kbs,
             read_packets, write_packets, row_hash)
        VALUES
            (%(hostname)s, %(snap_time)s, %(interface)s, %(read_kbs)s, %(write_kbs)s,
             %(read_packets)s, %(write_packets)s, %(row_hash)s)
        ON CONFLICT (hostname, snap_time, interface, row_hash) DO NOTHING
    """
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.executemany(sql, records)
        conn.commit()
        logger.info(f'Inserted {len(records)} NMON network rows')
    except Exception as e:
        if conn:
            conn.rollback()
        logger.error(f'NMON network insert failed: {e}', exc_info=True)
    finally:
        if conn:
            conn.close()
