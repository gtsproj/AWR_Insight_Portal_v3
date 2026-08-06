# modules/nmon/nmon_common.py
# ============================================================
# Shared NMON parsing utilities.
#
# NMON files are CSV, structured as:
#   AAA,host,dbserver01              <- one-off header/config lines
#   AAA,date,04-AUG-2026
#   AAA,interval,300
#   CPU_ALL,CPU Total dbserver01,User%,Sys%,Wait%,Idle%,CPUs   <- column-name header (once)
#   DISKBUSY,Disk %Busy,sda,sdb,sdc                            <- device list is the header
#   ZZZZ,T0001,00:00:00,04-AUG-2026                            <- snapshot marker
#   CPU_ALL,T0001,4.2,1.8,0.3,93.7,4                           <- data row for that snapshot
#   DISKBUSY,T0001,2.1,0.5,0.3
#
# Each section has ONE header line (second field is a name, not a
# Txxxx token) followed by many data lines (second field is Txxxx,
# matched back to a timestamp via the ZZZZ lines).
# ============================================================

import os
import sys
import re
import hashlib
from datetime import datetime

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))

from logger_utils import get_logger
logger = get_logger('nmon_common')

_TOKEN_RE = re.compile(r'^T\d+$')


def _sf(value):
    """Safe float — mirrors sar parsers' _sf helper."""
    try:
        return float(str(value).replace(',', '').strip())
    except (ValueError, TypeError):
        return None


def row_hash(record: dict) -> str:
    concat = '|'.join(str(record.get(k, '')) for k in sorted(record.keys()))
    return hashlib.md5(concat.encode('utf-8')).hexdigest()


def sanitize_record(record: dict) -> dict:
    for k, v in record.items():
        if v is None or v in ('', 'nan', 'NaN', 'None'):
            record[k] = None
    return record


class NmonContext:
    """
    One parse pass over an NMON file's lines, producing:
      - hostname          (from AAA,host,... or filename fallback)
      - headers[section]  -> list of column names (from the section's
                               one-time header line)
      - timestamps[Txxxx] -> datetime (from ZZZZ lines)

    Incremental parsing: pass since_token_seq to skip tokens already
    processed in a previous pass. E.g. since_token_seq=288 skips
    T0001..T0288 and only parses T0289 onwards. Used for hourly pulls
    from a live NMON file that is still being written.
    """

    def __init__(self, lines: list, hostname_override: str = None,
                 since_token_seq: int = 0):
        self.headers         = {}   # section -> [col names]
        self.timestamps      = {}   # Txxxx -> datetime (new tokens only)
        self.all_timestamps  = {}   # Txxxx -> datetime (ALL tokens, for context)
        self.hostname        = (hostname_override or '').strip() or None
        self._nmon_date      = None
        self.since_token_seq = since_token_seq   # skip tokens with seq <= this
        self.max_token_seq   = 0                 # highest seq seen in file
        self._parse(lines)

    @staticmethod
    def _token_seq(token: str) -> int:
        """T0288 → 288"""
        try:
            return int(token[1:])
        except (ValueError, IndexError):
            return 0

    def _parse(self, lines: list):
        for raw in lines:
            line = raw.rstrip('\r\n')
            if not line.strip():
                continue
            parts = line.split(',')
            if len(parts) < 2:
                continue

            section = parts[0].strip()

            if section == 'AAA':
                key = parts[1].strip().lower() if len(parts) > 1 else ''
                if key == 'host' and not self.hostname and len(parts) > 2:
                    self.hostname = parts[2].strip()
                elif key == 'date' and len(parts) > 2:
                    self._nmon_date = parts[2].strip()
                continue

            if section == 'ZZZZ':
                # ZZZZ,T0001,00:00:00,04-AUG-2026
                if len(parts) >= 4:
                    token = parts[1].strip()
                    seq   = self._token_seq(token)
                    dt    = _parse_nmon_datetime(parts[3].strip(), parts[2].strip())
                    if dt:
                        self.all_timestamps[token] = dt
                        # Track the highest seq in the entire file
                        if seq > self.max_token_seq:
                            self.max_token_seq = seq
                        # Only add to active timestamps if beyond since_token_seq
                        if seq > self.since_token_seq:
                            self.timestamps[token] = dt
                continue

            # Section header line: second field is NOT a Txxxx token
            second = parts[1].strip()
            if not _TOKEN_RE.match(second):
                if section not in self.headers:
                    self.headers[section] = [p.strip() for p in parts[2:]]

        if not self.hostname:
            self.hostname = 'UNKNOWN_HOST'

    @property
    def new_snapshot_count(self) -> int:
        return len(self.timestamps)

    @property
    def is_incremental(self) -> bool:
        return self.since_token_seq > 0


def _parse_nmon_datetime(date_str: str, time_str: str):
    """DD-MON-YYYY + HH:MM:SS -> datetime. Handles 2-digit year too."""
    for fmt in ('%d-%b-%Y %H:%M:%S', '%d-%b-%y %H:%M:%S'):
        try:
            return datetime.strptime(f'{date_str} {time_str}', fmt)
        except ValueError:
            continue
    logger.warning(f'Could not parse NMON timestamp: {date_str} {time_str}')
    return None


def iter_section_rows(lines: list, section: str, ctx: NmonContext):
    """
    Yield (snap_time, [data fields]) for every data row belonging to
    `section` (skips the header line — matched by requiring the
    second field to be a resolvable Txxxx token).
    """
    for raw in lines:
        line = raw.rstrip('\r\n')
        if not line.startswith(section + ','):
            continue
        parts = line.split(',')
        if len(parts) < 2:
            continue
        token = parts[1].strip()
        if not _TOKEN_RE.match(token):
            continue  # header line
        snap_time = ctx.timestamps.get(token)
        if snap_time is None:
            continue
        yield snap_time, [p.strip() for p in parts[2:]]
