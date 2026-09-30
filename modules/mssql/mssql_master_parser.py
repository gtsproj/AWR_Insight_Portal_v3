"""
modules/mssql/mssql_master_parser.py

Master parser for one SQLWR report: runs every section parser against it, in
a fixed sequence with Database Summary first, and reports what happened.
This is a SEPARATE script from the Oracle side's master_parser.py, per
Ganesh's stated preference to keep the two watchers/orchestrators apart
rather than generic-dispatching from one shared script.

Unlike master_parser.py's 3-interface fallback (main / parse+insert /
exec-as-__main__) -- built to cope with decades of inconsistently-shaped
Oracle parser scripts -- every MSSQL SQLWR parser was written to one
consistent convention from the start: a module-level parse_X(filepath,
pg_conn=None) -> list and insert_X(records) -> int, nothing else. This
master parser leans on that consistency and calls the two functions
directly (found by name, not exec'd), rather than reproducing all three
Oracle-side interfaces for parsers that only ever need the one.

One parser's failure does NOT stop the run: matches this project's
explicit design decision, documented repeatedly in the parsers
themselves, that a section parser must never sys.exit(0) or otherwise
kill the whole process -- a bad report section should cost that one
table's data for this report, not every other table's. Every exception
is caught, logged, and recorded in the returned failures dict.

One connection is opened once and passed to every parse_X() call (each
parser accepts pg_conn as an optional argument for exactly this reason
-- see sqlwr_parser_utils.py); this must not be confused with the
insert side: insert_records() (in sqlwr_parser_utils.py, shared by every
parser) opens its OWN connection on every call regardless, so a report
with 27 sections still makes up to 27 short-lived insert connections.
Left as is -- changing that is a shared-helper change touching all 26
already-verified parsers, out of scope for adding an orchestrator.

Does NOT refresh the mssql_wait_summary_mv / mssql_sql_summary_mv /
mssql_segment_summary_mv materialized views. They currently source from
the raw collector tables, not from the parsed tables this script fills
(see Documentation/MSSQL_SQLWR_Parsed_Tables_Conventions.md and the
project roadmap -- "re-point to parsed section tables" is a separate,
later step), and mssql_collector_scheduler.py already refreshes them
once per collection cycle; refreshing them again here would duplicate
that work without changing what they show. Revisit this once the MVs
are re-pointed at the parsed tables.

Also owns archiving: --archive moves a report to SQLWR_ARCHIVE_DIR/<db_name>/
once every parser has run for it (db_name read from the report's own
metadata, not the containing folder -- so this works the same whether the
report came from sqlwr_reports/<db>/ or anywhere else), and
--cleanup-archive deletes archived reports older than
portal.sqlwr_archive_retain_days (settings.yaml) days. Both settings.yaml
keys (paths.sqlwr_archive_directory, portal.sqlwr_archive_retain_days)
follow the same convention as the Oracle/SAR/NMON archive settings already
there.

Usage:
    py modules\\mssql\\mssql_master_parser.py "C:\\...\\sqlwr_reports\\MYDB\\sqlwr_1_75_76.html" --archive
    py modules\\mssql\\mssql_master_parser.py --dir "C:\\...\\sqlwr_reports" --archive
    py modules\\mssql\\mssql_master_parser.py --cleanup-archive
"""

import argparse
import glob
import importlib
import os
import re
import shutil
import sys
import time
from datetime import datetime, timedelta

from bs4 import BeautifulSoup

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sqlwr_parser_utils import get_db_connection, extract_sqlwr_metadata
from logger_utils import get_logger

logger = get_logger("mssql_master_parser")

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _load_archive_settings():
    """
    (archive_dir, retain_days) from config/settings.yaml's paths.sqlwr_archive_directory
    and portal.sqlwr_archive_retain_days -- same try/except-load_config() pattern already
    used elsewhere in this project (e.g. query_store_collector.py's MAX_INTERVALS_PER_RUN),
    with the same defaults this module's settings.yaml entries themselves use (7 days,
    "sqlwr_archive") so a missing/unreadable settings.yaml degrades to the documented
    default rather than failing archiving outright.
    """
    try:
        sys.path.insert(0, os.path.join(_PROJECT_ROOT, "common"))
        from config_loader import load_config
        cfg = load_config() or {}
    except Exception as e:
        logger.warning(f"Could not read settings.yaml ({e}) -- using archive defaults "
                       f"(sqlwr_archive, 7-day retention)")
        cfg = {}
    archive_dir = cfg.get("paths", {}).get("sqlwr_archive_directory", "sqlwr_archive")
    if not os.path.isabs(archive_dir):
        archive_dir = os.path.join(_PROJECT_ROOT, archive_dir)
    retain_days = int(cfg.get("portal", {}).get("sqlwr_archive_retain_days", 7))
    return archive_dir, retain_days


SQLWR_ARCHIVE_DIR, SQLWR_ARCHIVE_RETAIN_DAYS = _load_archive_settings()

_INVALID_FOLDER_CHARS = re.compile(r'[<>:"/\\|?*\x00-\x1f]')


def _safe_folder_name(db_name) -> str:
    """Same rule sqlwr_report_generator.py's own _safe_folder_name() uses for the
    per-database REPORTS subfolder, duplicated here (not imported) because that
    module is heavier to import (pulls in the whole report-building pipeline) for
    what is, on this side, just a 5-line string rule -- kept in sync by hand; if
    this ever needs to change, change it in both places."""
    if db_name is None:
        return "UNKNOWN_DB"
    name = str(db_name).strip()
    if not name or name == "(not collected)":
        return "UNKNOWN_DB"
    if ", " in name:
        return "_multiple_databases"
    name = _INVALID_FOLDER_CHARS.sub("_", name).strip(" .")
    if not name:
        return "UNKNOWN_DB"
    if name.upper() in {"CON", "PRN", "AUX", "NUL",
                        *(f"COM{i}" for i in range(1, 10)), *(f"LPT{i}" for i in range(1, 10))}:
        name = f"_{name}"
    return name


def _archive_report(filepath: str) -> str:
    """
    Moves filepath into SQLWR_ARCHIVE_DIR/<db_name>/<filename>, db_name read from
    the report's OWN metadata (extract_sqlwr_metadata) -- exact, not a filename or
    HTML-title regex guess the way the Oracle side's master_parser.py's
    _db_name_from_html() has to be (this project controls the SQLWR HTML format
    completely, so there's no need for that heuristic here). A destination name
    collision (re-parsing/re-archiving a same-named file) gets a timestamp suffix
    rather than overwriting or erroring, same as the Oracle side's _archive_file().
    Returns the path the file was moved to.
    """
    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "html.parser")
    metadata = extract_sqlwr_metadata(soup)
    dest_dir = os.path.join(SQLWR_ARCHIVE_DIR, _safe_folder_name(metadata.get("dbname")))
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, os.path.basename(filepath))
    if os.path.exists(dest):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        base, ext = os.path.splitext(os.path.basename(filepath))
        dest = os.path.join(dest_dir, f"{base}_{ts}{ext}")
    shutil.move(filepath, dest)
    logger.info(f"  Archived to {dest}")
    return dest


def cleanup_sqlwr_archive(retain_days: int = None) -> int:
    """
    Deletes .html files older than retain_days (by mtime) from SQLWR_ARCHIVE_DIR,
    recursively (so every per-database subfolder is covered by one call) --
    functionally identical to the Oracle side's portal/app.py:_cleanup_archive(),
    reimplemented here rather than imported from it because that module is a
    FastAPI app entrypoint, not a library the MSSQL side should import from.
    retain_days defaults to SQLWR_ARCHIVE_RETAIN_DAYS (from settings.yaml,
    portal.sqlwr_archive_retain_days). Returns the count of files deleted.
    """
    if retain_days is None:
        retain_days = SQLWR_ARCHIVE_RETAIN_DAYS
    if not os.path.isdir(SQLWR_ARCHIVE_DIR):
        return 0
    cutoff = datetime.now() - timedelta(days=retain_days)
    deleted = 0
    for root, _dirs, files in os.walk(SQLWR_ARCHIVE_DIR):
        for fname in files:
            if not fname.lower().endswith(".html"):
                continue
            fpath = os.path.join(root, fname)
            try:
                if datetime.fromtimestamp(os.path.getmtime(fpath)) < cutoff:
                    os.unlink(fpath)
                    deleted += 1
            except OSError as e:
                logger.warning(f"Could not delete {fpath}: {e}")
    if deleted:
        logger.info(f"SQLWR archive cleanup: deleted {deleted} file(s) older than "
                    f"{retain_days} day(s) from {SQLWR_ARCHIVE_DIR}")
    return deleted

# Database Summary MUST run first (Ganesh's specification). Everything after
# it follows the report's own top-to-bottom section order -- not a functional
# requirement, just easier to read in the log output.
MODULE_ORDER = [
    "sqlwr_database_summary_parser",
    "sqlwr_load_profile_parser",
    "sqlwr_cpu_utilization_parser",
    "sqlwr_instance_efficiency_parser",
    "sqlwr_wait_classes_parser",
    "sqlwr_wait_events_parser",
    "sqlwr_wait_by_procedure_parser",
    "sqlwr_memory_stats_parser",
    "sqlwr_io_profile_parser",
    "sqlwr_io_stalls_parser",
    "sqlwr_seg_logical_reads_parser",
    "sqlwr_seg_physical_reads_parser",
    "sqlwr_seg_physical_writes_parser",
    "sqlwr_seg_table_scans_parser",
    "sqlwr_seg_row_lock_waits_parser",
    "sqlwr_seg_buffer_busy_waits_parser",
    "sqlwr_sql_elapsed_time_parser",
    "sqlwr_sql_cpu_time_parser",
    "sqlwr_sql_gets_parser",
    "sqlwr_sql_executions_parser",
    "sqlwr_blocking_summary_parser",
    "sqlwr_deadlock_summary_parser",
    "sqlwr_plan_cache_summary_parser",
    "sqlwr_plan_cache_detail_parser",
    "sqlwr_tempdb_sessions_parser",
    "sqlwr_tempdb_tasks_parser",
    "sqlwr_sql_text_parser",      # last: the other 4 SQL sections' previews point here
]


def _find_functions(module):
    """
    The one parse_X / insert_X pair a module DEFINES itself -- filtered by
    __module__ so this does not also match names a module merely IMPORTED
    under a matching prefix. Concretely: every parser does
    `from sqlwr_parser_utils import insert_records` (among others), which
    binds the name "insert_records" in that module's own namespace --
    without the __module__ filter, dir(module) would find BOTH that
    imported insert_records AND the module's own insert_X, tripping the
    "exactly one insert_* function" check below. Caught by testing before
    this ever ran against a report, not discovered after.
    """
    def own(prefix):
        return [getattr(module, n) for n in dir(module)
                if n.startswith(prefix) and getattr(getattr(module, n), "__module__", None) == module.__name__]
    parse_fns, insert_fns = own("parse_"), own("insert_")
    if len(parse_fns) != 1 or len(insert_fns) != 1:
        raise RuntimeError(f"{module.__name__}: expected exactly one parse_* and one insert_* "
                            f"function defined in the module itself, found {len(parse_fns)} "
                            f"parse_* and {len(insert_fns)} insert_*")
    return parse_fns[0], insert_fns[0]


def process_file(filepath: str, archive: bool = False) -> dict:
    """
    Runs every parser in MODULE_ORDER against filepath, in order.

    archive: if True, the file is moved to SQLWR_ARCHIVE_DIR/<db_name>/ once
    every parser has run -- REGARDLESS of whether any of them failed, matching
    the Oracle side's master_parser.py's own --archive behavior (a partially
    parsed report still needs to move out of the active reports folder; retrying
    a failed section is a separate concern this flag doesn't try to solve).

    Returns {"parsed": {module_name: row_count}, "failures": {module_name: str(exception)},
    "archived_to": str | None}.
    """
    filepath = os.path.abspath(filepath)
    if not os.path.exists(filepath):
        raise FileNotFoundError(filepath)

    logger.info("=" * 60)
    logger.info(f"Processing: {os.path.basename(filepath)}")

    pg_conn = get_db_connection()
    parsed, failures = {}, {}
    t_file_start = time.perf_counter()
    try:
        for module_name in MODULE_ORDER:
            t_start = time.perf_counter()
            try:
                module = importlib.import_module(module_name)
                parse_fn, insert_fn = _find_functions(module)
                records = parse_fn(filepath, pg_conn)
                inserted = insert_fn(records)
                parsed[module_name] = inserted
                elapsed = time.perf_counter() - t_start
                logger.info(f"  {module_name:<38} {inserted:>4} row(s)  {elapsed:.2f}s")
            except Exception as e:
                elapsed = time.perf_counter() - t_start
                logger.error(f"  {module_name:<38} FAILED       {elapsed:.2f}s -- {e}", exc_info=True)
                failures[module_name] = str(e)
    finally:
        pg_conn.close()

    total_elapsed = time.perf_counter() - t_file_start
    if failures:
        logger.warning(f"{os.path.basename(filepath)}: {len(parsed)} parser(s) ok, "
                        f"{len(failures)} FAILED ({total_elapsed:.1f}s total) -- {sorted(failures)}")
    else:
        logger.info(f"{os.path.basename(filepath)}: all {len(parsed)} parsers ok "
                    f"({total_elapsed:.1f}s total)")

    archived_to = None
    if archive:
        try:
            archived_to = _archive_report(filepath)
        except Exception as e:
            logger.error(f"  Archiving FAILED for {os.path.basename(filepath)}: {e}", exc_info=True)

    return {"parsed": parsed, "failures": failures, "archived_to": archived_to}


def process_all_in_dir(reports_dir: str, archive: bool = False) -> list:
    """Every sqlwr_*.html under reports_dir (recursive -- finds reports nested in the
    per-database subfolders sqlwr_report_generator.py's auto_generate_sqlwr_reports()
    now writes), processed in filename order."""
    files = sorted(glob.glob(os.path.join(reports_dir, "**", "sqlwr_*.html"), recursive=True))
    if not files:
        logger.warning(f"No sqlwr_*.html reports found under {reports_dir}")
        return []
    logger.info(f"Batch mode: {len(files)} report(s) found under {reports_dir}")
    return [process_file(f, archive=archive) for f in files]


def main():
    p = argparse.ArgumentParser(
        description="MSSQL SQLWR master parser -- runs all 27 section parsers "
                     "against one report, or every sqlwr_*.html report in a directory.")
    p.add_argument("filepath", nargs="?", default=None,
                   help="Path to a single SQLWR HTML report.")
    p.add_argument("--dir", default=None,
                   help="Directory to scan (recursively) for sqlwr_*.html reports -- batch mode.")
    p.add_argument("--archive", action="store_true",
                   help=f"After parsing, move each report to {SQLWR_ARCHIVE_DIR}\\<db_name>\\ "
                        f"(regardless of whether any section failed to parse).")
    p.add_argument("--cleanup-archive", action="store_true",
                   help=f"Delete archived reports older than "
                        f"{SQLWR_ARCHIVE_RETAIN_DAYS} day(s) (portal.sqlwr_archive_retain_days "
                        f"in settings.yaml) from {SQLWR_ARCHIVE_DIR}, then exit -- ignores "
                        f"filepath/--dir if also given.")
    args = p.parse_args()

    if args.cleanup_archive:
        deleted = cleanup_sqlwr_archive()
        logger.info(f"Archive cleanup complete -- {deleted} file(s) deleted")
        sys.exit(0)
    elif args.filepath:
        result = process_file(args.filepath, archive=args.archive)
        sys.exit(1 if result["failures"] else 0)
    elif args.dir:
        results = process_all_in_dir(args.dir, archive=args.archive)
        sys.exit(1 if any(r["failures"] for r in results) else 0)
    else:
        p.error("provide a report filepath, or --dir for batch mode, or --cleanup-archive")


if __name__ == "__main__":
    main()
