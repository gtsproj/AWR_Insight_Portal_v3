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

Usage:
    py modules\\mssql\\mssql_master_parser.py "C:\\...\\sqlwr_1_75_76.html"
    py modules\\mssql\\mssql_master_parser.py --dir "C:\\...\\sqlwr_reports"
"""

import argparse
import glob
import importlib
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sqlwr_parser_utils import get_db_connection
from logger_utils import get_logger

logger = get_logger("mssql_master_parser")

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


def process_file(filepath: str) -> dict:
    """
    Runs every parser in MODULE_ORDER against filepath, in order.
    Returns {"parsed": {module_name: row_count}, "failures": {module_name: str(exception)}}.
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
    return {"parsed": parsed, "failures": failures}


def process_all_in_dir(reports_dir: str) -> list:
    """Every sqlwr_*.html under reports_dir (recursive), processed in filename order."""
    files = sorted(glob.glob(os.path.join(reports_dir, "**", "sqlwr_*.html"), recursive=True))
    if not files:
        logger.warning(f"No sqlwr_*.html reports found under {reports_dir}")
        return []
    logger.info(f"Batch mode: {len(files)} report(s) found under {reports_dir}")
    return [process_file(f) for f in files]


def main():
    p = argparse.ArgumentParser(
        description="MSSQL SQLWR master parser -- runs all 27 section parsers "
                     "against one report, or every sqlwr_*.html report in a directory.")
    p.add_argument("filepath", nargs="?", default=None,
                   help="Path to a single SQLWR HTML report.")
    p.add_argument("--dir", default=None,
                   help="Directory to scan (recursively) for sqlwr_*.html reports -- batch mode.")
    args = p.parse_args()

    if args.filepath:
        result = process_file(args.filepath)
        sys.exit(1 if result["failures"] else 0)
    elif args.dir:
        results = process_all_in_dir(args.dir)
        sys.exit(1 if any(r["failures"] for r in results) else 0)
    else:
        p.error("provide a report filepath, or --dir for batch mode")


if __name__ == "__main__":
    main()
