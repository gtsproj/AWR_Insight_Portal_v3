# modules/nmon/nmon_master_parser.py
# Mirrors modules/sar/sar_master_parser.py's dispatch pattern, adapted
# for NMON's CSV format (always text — no binary conversion needed,
# unlike SAR).

import os
import sys
import glob

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, 'common'))

from logger_utils import get_logger
logger = get_logger('nmon_master_parser')

NMON_DIR    = os.path.join(_PROJECT_ROOT, 'nmon_reports')
ARCHIVE_DIR = os.path.join(_PROJECT_ROOT, 'nmon_archive')

sys.path.insert(0, os.path.dirname(__file__))

from nmon_common        import NmonContext
from nmon_cpu_parser    import parse_nmon_cpu,       insert_nmon_cpu
from nmon_memory_parser import parse_nmon_memory,    insert_nmon_memory
from nmon_disk_parser   import parse_nmon_disk,      insert_nmon_disk
from nmon_network_parser import parse_nmon_network,  insert_nmon_network
from nmon_proc_parser   import (parse_nmon_runqueue, insert_nmon_runqueue,
                                 parse_nmon_ctxswitch, insert_nmon_ctxswitch)
from nmon_paging_parser import parse_nmon_paging,    insert_nmon_paging

_PARSERS = [
    ('CPU',          parse_nmon_cpu,       insert_nmon_cpu),
    ('Memory',       parse_nmon_memory,    insert_nmon_memory),
    ('Disk I/O',     parse_nmon_disk,      insert_nmon_disk),
    ('Network',      parse_nmon_network,   insert_nmon_network),
    ('Run Queue',    parse_nmon_runqueue,  insert_nmon_runqueue),
    ('Ctx Switches', parse_nmon_ctxswitch, insert_nmon_ctxswitch),
    ('Paging',       parse_nmon_paging,    insert_nmon_paging),
]


# ── Parse log helpers ─────────────────────────────────────────────────────────
def _get_parse_state(hostname: str, filename: str) -> dict:
    """
    Return the last incremental parse state for this hostname+file.
    last_token_seq=0 means never parsed (process all tokens).
    """
    try:
        from db import get_db_connection
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("""
                SELECT last_token_seq, rows_parsed, last_snap_time
                FROM nmon_parse_log
                WHERE hostname=%s AND filename=%s
            """, (hostname, filename))
            row = cur.fetchone()
        conn.close()
        if row:
            return {
                'last_token_seq': int(row[0] or 0),
                'rows_parsed':    int(row[1] or 0),
                'last_snap_time': row[2],
            }
    except Exception as e:
        logger.warning(f'_get_parse_state: {e}')
    return {'last_token_seq': 0, 'rows_parsed': 0, 'last_snap_time': None}


def _save_parse_state(hostname: str, filename: str, snap_date,
                      rows_parsed: int, last_token_seq: int,
                      last_snap_time, status: str = 'ok', error_msg: str = None):
    """Upsert parse state into nmon_parse_log. rows_parsed is cumulative."""
    try:
        from db import get_db_connection
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("""
                INSERT INTO nmon_parse_log
                    (hostname, filename, snap_date, rows_parsed,
                     last_token_seq, last_snap_time, status, error_msg, parsed_at)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,NOW())
                ON CONFLICT (hostname, filename) DO UPDATE SET
                    snap_date      = EXCLUDED.snap_date,
                    rows_parsed    = nmon_parse_log.rows_parsed + EXCLUDED.rows_parsed,
                    last_token_seq = GREATEST(nmon_parse_log.last_token_seq, EXCLUDED.last_token_seq),
                    last_snap_time = EXCLUDED.last_snap_time,
                    status         = EXCLUDED.status,
                    error_msg      = EXCLUDED.error_msg,
                    parsed_at      = NOW()
            """, (hostname, filename, snap_date, rows_parsed,
                  last_token_seq, last_snap_time, status, error_msg))
        conn.commit()
        conn.close()
    except Exception as e:
        logger.warning(f'_save_parse_state: {e}')

def _run_nmon_anomaly_detection(hostname: str, ctx: NmonContext) -> None:
    """
    Auto-trigger NMON anomaly detection after a file is fully parsed.

    KEY DIFFERENCE FROM SAR:
    SAR processes one file per day, so detect_sar() naturally has
    previous days in the DB as baseline when it runs.

    NMON files can span many days (e.g. one 30-day .nmon file). All days
    are parsed into the DB BEFORE this function runs. If we called
    detect_nmon() with snap_time_from = first day of the file, the baseline
    window (before that first day) would be empty — giving 0 findings.

    Fix: iterate day by day through the file date range. Each daily
    detection window uses all earlier days in the same file as baseline
    (they are already in the DB because parsing ran first).

    NMON_MIN_SAMPLES (default 3) days of baseline are required before
    detection starts, so detection begins from day 4 of the file onwards.
    """
    import importlib.util
    from datetime import datetime as _dt, time as _time

    det_path = os.path.join(_PROJECT_ROOT, 'anomaly_detector.py')
    if not os.path.exists(det_path):
        logger.warning('anomaly_detector.py not found — skipping NMON anomaly detection')
        return
    if not ctx.timestamps:
        logger.warning('No timestamps parsed — skipping NMON anomaly detection')
        return

    try:
        spec   = importlib.util.spec_from_file_location('anomaly_detector', det_path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    except Exception as e:
        logger.error(f'Failed to load anomaly_detector.py: {e}', exc_info=True)
        return

    if not hasattr(module, 'detect_nmon'):
        logger.warning('anomaly_detector has no detect_nmon() — skipping.')
        return

    # Minimum baseline days required (from anomaly_detector config)
    min_baseline_days = getattr(module, 'NMON_MIN_SAMPLES', 3)

    # Every unique calendar date with NMON snapshots in this file
    unique_dates = sorted({ts.date() for ts in ctx.timestamps.values()})

    if len(unique_dates) <= min_baseline_days:
        logger.info(
            f'NMON anomaly detection skipped for {hostname}: '
            f'file has {len(unique_dates)} day(s), need > {min_baseline_days} '
            f'(first {min_baseline_days} days used as baseline)'
        )
        return

    total_findings = 0
    days_detected  = 0

    for i, det_date in enumerate(unique_dates):
        if i < min_baseline_days:      # first N days = baseline only, skip
            continue
        day_start = _dt.combine(det_date, _time.min)     # 00:00:00
        day_end   = _dt.combine(det_date, _time.max)     # 23:59:59.999999
        try:
            findings = module.detect_nmon(
                hostname       = hostname,
                snap_time_from = day_start,
                snap_time_to   = day_end,
                store          = True,
            )
            n = len(findings) if isinstance(findings, list) else 0
            total_findings += n
            days_detected  += 1
            if n:
                logger.info(f'  [{det_date}] {n} NMON anomaly(ies) — {hostname}')
        except Exception as e:
            logger.error(
                f'NMON anomaly detection failed for {hostname} on {det_date}: {e}',
                exc_info=True
            )

    logger.info(
        f'NMON anomaly detection complete for {hostname}: '
        f'{total_findings} finding(s) across {days_detected} day(s) '
        f'({len(unique_dates)} total days in file, '
        f'first {min_baseline_days} used as baseline)'
    )


def process_nmon_file(filepath, archive=False, hostname_override=None,
                      incremental=True):
    """
    Parse a NMON file — supports both full and incremental parsing.

    Incremental (default, incremental=True):
      Checks nmon_parse_log for last_token_seq processed for this file.
      Only parses new snapshots (Txxxx > last_token_seq).
      Enables 1-hour lag: re-fetch the same growing NMON file every hour
      and only process new tokens each time.

    Full (incremental=False):
      Processes all tokens regardless of parse history.
      Used for initial load or re-processing.

    For NMON files that grow continuously (one file from NMON start):
      Call this function every hour on the same file. Each call processes
      only the new 12 snapshots (5-min interval × 12 = 1 hour).

    For daily NMON files (nmon -f -s 300 -c 288):
      First call: processes all 288 snapshots.
      Subsequent calls: no-op (all tokens already logged).
    """
    import shutil
    filepath = os.path.abspath(filepath)
    if not os.path.exists(filepath):
        basename = os.path.basename(filepath)
        hostname = (hostname_override or '').upper() or 'UNKNOWN'
        candidates = [os.path.join(ARCHIVE_DIR, hostname, basename)]
        if os.path.isdir(ARCHIVE_DIR):
            for hdir in os.listdir(ARCHIVE_DIR):
                candidate = os.path.join(ARCHIVE_DIR, hdir, basename)
                if candidate not in candidates:
                    candidates.append(candidate)
        found = next((c for c in candidates if os.path.exists(c)), None)
        if found:
            logger.info(f'File found in archive: {found}')
            filepath = found
        else:
            logger.error(f'NMON file not found: {filepath}')
            return False

    fname = os.path.basename(filepath)

    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()

    # ── Incremental state ─────────────────────────────────────────────────────
    # Determine hostname first (scan AAA lines only — fast)
    host_hint = hostname_override
    if not host_hint:
        for line in lines[:50]:
            if line.startswith('AAA,host,'):
                host_hint = line.split(',')[2].strip()
                break
    host_hint = host_hint or 'UNKNOWN_HOST'

    since_token_seq = 0
    if incremental:
        state = _get_parse_state(host_hint, fname)
        since_token_seq = state['last_token_seq']
        if since_token_seq > 0:
            logger.info(f'Incremental parse: {fname} — resuming from T{since_token_seq:04d}')

    # ── Parse ─────────────────────────────────────────────────────────────────
    ctx = NmonContext(lines, hostname_override=hostname_override,
                     since_token_seq=since_token_seq)

    if ctx.new_snapshot_count == 0:
        logger.info(f'No new snapshots in {fname} (max_token={ctx.max_token_seq}, '
                    f'since={since_token_seq}) — nothing to do')
        return True   # not an error — just fully up to date

    logger.info('=' * 60)
    logger.info(f'Processing NMON: {fname}')
    logger.info(f'   Host      : {ctx.hostname}')
    logger.info(f'   New snaps : {ctx.new_snapshot_count} '
                f'(T{since_token_seq+1:04d}..T{ctx.max_token_seq:04d})')

    total_rows = 0
    failures   = []
    for label, parse_fn, insert_fn in _PARSERS:
        try:
            records = parse_fn(lines, ctx)
            insert_fn(records)
            total_rows += len(records)
            logger.info('  OK {:<12} - {} rows'.format(label, len(records)))
        except Exception as e:
            logger.error('  FAIL {:<10} - {}'.format(label, e), exc_info=True)
            failures.append(label)

    success = len(failures) == 0
    logger.info('NMON {} — {}'.format(
        'complete' if success else 'partial',
        'OK' if success else f'Failures: {failures}'
    ))

    # ── Save incremental state ────────────────────────────────────────────────
    snap_date      = None
    last_snap_time = None
    if ctx.timestamps:
        snap_times     = sorted(ctx.timestamps.values())
        snap_date      = snap_times[0].date()
        last_snap_time = snap_times[-1]

    _save_parse_state(
        hostname       = ctx.hostname,
        filename       = fname,
        snap_date      = snap_date,
        rows_parsed    = total_rows,
        last_token_seq = ctx.max_token_seq,
        last_snap_time = last_snap_time,
        status         = 'ok' if success else 'partial',
        error_msg      = '; '.join(failures) if failures else None,
    )

    # ── Archive after full parse (only when not incremental, or file complete) ─
    # For incremental mode we do NOT archive — the file may still be growing.
    # Archive happens only when the file is fully consumed (max_token_seq
    # matches the file's announced snapshot count from AAA,snapshots).
    if archive and not incremental and success:
        host_dir = os.path.join(ARCHIVE_DIR, ctx.hostname)
        os.makedirs(host_dir, exist_ok=True)
        dest = os.path.join(host_dir, fname)
        if not os.path.exists(dest):
            try:
                shutil.move(filepath, dest)
                logger.info(f'Archived: nmon_archive/{ctx.hostname}/{fname}')
            except Exception as e:
                logger.warning(f'Archive move failed: {e}')

    # ── Anomaly detection ──────────────────────────────────────────────────────
    logger.info(f'Running NMON anomaly detection for {ctx.hostname}')
    _run_nmon_anomaly_detection(ctx.hostname, ctx)

    return True


def process_nmon_file_incremental(filepath, hostname_override=None):
    """
    Convenience wrapper for the hourly SSH-pull use case.
    Always incremental — only parses new snapshots since last call.
    Does NOT archive (file may still be actively written by NMON).
    """
    return process_nmon_file(
        filepath,
        archive=False,
        hostname_override=hostname_override,
        incremental=True,
    )


def scan_and_process(scan_dir=None):
    scan_dir = scan_dir or NMON_DIR
    if not os.path.isdir(scan_dir):
        logger.warning(f'NMON directory not found: {scan_dir}')
        return
    nmon_files = (glob.glob(os.path.join(scan_dir, '**', '*.nmon'), recursive=True) +
                  glob.glob(os.path.join(scan_dir, '**', '*.csv'),  recursive=True))
    if not nmon_files:
        logger.warning(f'No NMON files found in {scan_dir}')
        return
    for f in nmon_files:
        # Use subfolder name as hostname_override so nmon_reports/TCLFSLPRDDB1/file.nmon
        # is always attributed to TCLFSLPRDDB1 regardless of what AAA,host says.
        host_hint = _hostname_from_path(f, scan_dir)
        process_nmon_file(f, archive=True, hostname_override=host_hint)


if __name__ == '__main__':
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('--file', default=None)
    p.add_argument('--scan', default=None)
    p.add_argument('--host', default=None)
    args = p.parse_args()

    if args.file:
        process_nmon_file(args.file, hostname_override=args.host)
    else:
        scan_and_process(args.scan)
