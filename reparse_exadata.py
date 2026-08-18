#!/usr/bin/env python3
"""
reparse_exadata.py
============================================================
Re-runs ONLY the 12 Exadata parsers against AWR HTML files
that have already been parsed (status=DONE) in the queue.

Use this when Exadata license was disabled during the initial
AWR upload — the Exadata tables will be empty for those snaps.

Usage:
  python reparse_exadata.py                   # all DONE files
  python reparse_exadata.py --db EXADB        # specific database
  python reparse_exadata.py --db EXADB --dry  # dry-run (list only)

Run from the project root with AWRPortal service STOPPED or
during a maintenance window to avoid DB contention.
============================================================
"""
import os, sys, glob, argparse, importlib, logging

_ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_ROOT, "common"))

logging.basicConfig(level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("reparse_exadata")

# ── Exadata parser modules (all 12 across Wave 1+2+3) ────────────────────────
_EXADATA_PARSERS = [
    # Wave 1
    "modules.awr.exadata_perf_summary_parser",
    "modules.awr.exadata_fc_config_parser",
    "modules.awr.exadata_smart_io_parser",
    "modules.awr.exadata_fc_reads_parser",
    # Wave 2
    "modules.awr.exadata_top_db_parser",
    "modules.awr.exadata_cell_iostat_parser",
    "modules.awr.exadata_io_reasons_parser",
    "modules.awr.exadata_fc_space_parser",
    "modules.awr.exadata_cell_server_parser",
    # Wave 3
    "modules.awr.exadata_fc_writes_parser",
    "modules.awr.exadata_config_parser",
    "modules.awr.exadata_disk_iostat_parser",
]


def _get_done_files(dbname_filter: str | None) -> list[tuple[str, str, str]]:
    """Return list of (filepath, dbname, status) for DONE queue entries."""
    from db import get_db_connection
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            if dbname_filter:
                cur.execute("""
                    SELECT filepath, db_name, status FROM awr_queue
                    WHERE status = 'DONE' AND db_name = %s
                    ORDER BY created_at
                """, (dbname_filter,))
            else:
                cur.execute("""
                    SELECT filepath, db_name, status FROM awr_queue
                    WHERE status = 'DONE'
                    ORDER BY db_name, created_at
                """)
            return cur.fetchall()
    finally:
        conn.close()


def _file_needs_exadata(filepath: str) -> bool:
    """Return True if the file hasn't been parsed by Exadata parsers yet."""
    from db import get_db_connection
    from common.utils import extract_workload_repo_metadata
    from bs4 import BeautifulSoup
    # Quick check: read dbname+begin_snap from file and query perf_summary
    try:
        with open(filepath, encoding="utf-8", errors="replace") as f:
            soup = BeautifulSoup(f, "html.parser")
        meta = extract_workload_repo_metadata(soup)
        if not meta:
            return False
        conn = get_db_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT COUNT(*) FROM awr_exadata_perf_summary
                    WHERE dbname=%s AND begin_snap=%s
                """, (meta["dbname"], meta["begin_snap"]))
                cnt = (cur.fetchone() or [0])[0]
            return cnt == 0     # True = needs parsing
        finally:
            conn.close()
    except Exception as e:
        logger.warning(f"  Could not check {os.path.basename(filepath)}: {e}")
        return True  # parse it anyway


def run_exadata_parsers(filepath: str) -> dict:
    """Run all 12 Exadata parsers against one AWR file."""
    results = {}
    for mod_path in _EXADATA_PARSERS:
        mod_name = mod_path.split(".")[-1]
        try:
            mod = importlib.import_module(mod_path)
            if hasattr(mod, "main"):
                mod.main(filepath)
                results[mod_name] = "ok"
            else:
                results[mod_name] = "no main()"
        except Exception as e:
            results[mod_name] = f"ERROR: {e}"
    return results


def main():
    parser = argparse.ArgumentParser(description="Re-run Exadata parsers on DONE AWR files")
    parser.add_argument("--db",  default=None, help="Filter by database name (e.g. EXADB)")
    parser.add_argument("--dry", action="store_true", help="List files without parsing")
    args = parser.parse_args()

    logger.info("Fetching DONE queue entries%s …",
                f" for db={args.db}" if args.db else "")
    rows = _get_done_files(args.db)
    logger.info(f"  {len(rows)} DONE entries found")

    files_to_parse = []
    for filepath, dbname, status in rows:
        if not os.path.isabs(filepath):
            filepath = os.path.join(_ROOT, filepath)
        if not os.path.exists(filepath):
            logger.debug(f"  File not found (archived?): {filepath}")
            continue
        if _file_needs_exadata(filepath):
            files_to_parse.append((filepath, dbname))
        else:
            logger.debug(f"  Already has Exadata data: {os.path.basename(filepath)}")

    logger.info(f"  {len(files_to_parse)} files need Exadata parsing")

    if args.dry:
        for fp, db in files_to_parse:
            print(f"  WOULD PARSE: [{db}] {os.path.basename(fp)}")
        return

    ok_count = err_count = 0
    for idx, (filepath, dbname) in enumerate(files_to_parse, 1):
        logger.info(f"  [{idx}/{len(files_to_parse)}] Parsing [{dbname}] {os.path.basename(filepath)}")
        results = run_exadata_parsers(filepath)
        errs = {k: v for k, v in results.items() if v != "ok"}
        if errs:
            logger.warning(f"    Errors: {errs}")
            err_count += 1
        else:
            logger.info(f"    All 12 parsers OK")
            ok_count += 1

    logger.info(f"\nDone. OK={ok_count}  Errors={err_count}")
    if err_count > 0:
        logger.info("Check errors above — common causes: missing table (run schema migrations),")
        logger.info("or file is not an Exadata AWR (parsers return 0 rows, not an error).")


if __name__ == "__main__":
    main()
