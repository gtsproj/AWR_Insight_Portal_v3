"""
mssql_collector_scheduler.py
===============================
Long-running orchestrator: runs the Query Store and DMV collectors
back-to-back, on a fixed, clock-aligned interval (30 or 60 minutes),
after setting the target database's own QUERY_STORE
(INTERVAL_LENGTH_MINUTES = N) to match -- so both data sources are
genuinely comparable time windows, not independently-timed snapshots
that happen to be compared after the fact.

Meant to run as a long-lived process (an NSSM-managed Windows service,
matching how this project already deploys its other long-running
pieces), not a one-off script.

Deliberately shells out to the two existing collectors via subprocess
rather than importing and calling their main() functions directly --
each has its own argparse/connection/logging setup, and running two
independent CLI tools as separate processes avoids any risk of
global-state interference between them in one shared Python process.

Run:
    py modules\\mssql\\mssql_collector_scheduler.py --host <host> --trusted-connection --database TestDB --interval-minutes 30
"""

import sys
import os
import time
import datetime
import subprocess

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'common'))
from logger_utils import get_logger

logger = get_logger('mssql_collector_scheduler')


def next_aligned_time(interval_minutes: int, now: datetime.datetime = None) -> datetime.datetime:
    """
    The next wall-clock time that's a multiple of interval_minutes
    since midnight -- for interval_minutes=30, this is the next :00 or
    :30; for 60, the next top of the hour. Chosen deliberately as
    midnight-based clock alignment, not "N minutes from whenever this
    process happened to start" -- SQL Server's own Query Store interval
    boundaries are also midnight-based N-minute blocks (not tied to
    when the collector process started), so aligning to the same
    reference point is what actually makes the two comparable.
    """
    if now is None:
        now = datetime.datetime.now()
    minutes_since_midnight = now.hour * 60 + now.minute
    next_boundary_minutes = ((minutes_since_midnight // interval_minutes) + 1) * interval_minutes
    midnight = now.replace(hour=0, minute=0, second=0, microsecond=0)
    return midnight + datetime.timedelta(minutes=next_boundary_minutes)


def set_query_store_interval(host, instance_name, database, interval_minutes, trusted_connection, sql_user, sql_password):
    """
    Sets the target database's QUERY_STORE (INTERVAL_LENGTH_MINUTES)
    to match the collector's own cadence -- idempotent (ALTER DATABASE
    SET QUERY_STORE is safe to re-run with the same value), run once
    at scheduler startup, not per collection cycle.
    """
    import pyodbc
    conn_parts = [f"DRIVER={{ODBC Driver 17 for SQL Server}}", f"SERVER={host}"]
    if trusted_connection:
        conn_parts.append("Trusted_Connection=yes")
    else:
        conn_parts.append(f"UID={sql_user}")
        conn_parts.append(f"PWD={sql_password}")
    conn_str = ";".join(conn_parts)
    conn = pyodbc.connect(conn_str, autocommit=True, timeout=30)
    cur = conn.cursor()
    cur.execute(f"ALTER DATABASE [{database}] SET QUERY_STORE (INTERVAL_LENGTH_MINUTES = {interval_minutes})")
    conn.close()
    logger.info(f"QUERY_STORE INTERVAL_LENGTH_MINUTES set to {interval_minutes} for [{database}]")


def run_collector(script_relpath, args):
    """Runs one collector as a subprocess, logging its outcome without
    raising -- a single failed cycle should not crash the scheduler
    loop; the next cycle gets its own fresh attempt."""
    script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), script_relpath)
    cmd = [sys.executable, script_path] + args
    logger.info(f"Running: {' '.join(cmd)}")
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        if result.returncode == 0:
            logger.info(f"{script_relpath} completed successfully")
        else:
            logger.error(f"{script_relpath} exited with code {result.returncode}: {result.stderr[-2000:]}")
    except subprocess.TimeoutExpired:
        logger.error(f"{script_relpath} timed out after 600s")
    except Exception as e:
        logger.error(f"{script_relpath} failed to run: {e}")


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", required=True)
    parser.add_argument("--instance-name", default="MSSQLSERVER")
    parser.add_argument("--database", required=True)
    parser.add_argument("--interval-minutes", type=int, default=60, choices=[30, 60],
                         help="Collection cadence, and the value QUERY_STORE's own "
                              "INTERVAL_LENGTH_MINUTES gets set to match")
    parser.add_argument("--trusted-connection", action="store_true")
    parser.add_argument("--sql-user", default=None)
    parser.add_argument("--sql-password", default=None)
    args = parser.parse_args()

    conn_args = ["--host", args.host, "--instance-name", args.instance_name, "--database", args.database]
    if args.trusted_connection:
        conn_args.append("--trusted-connection")
    else:
        conn_args.extend(["--sql-user", args.sql_user, "--sql-password", args.sql_password])

    set_query_store_interval(args.host, args.instance_name, args.database, args.interval_minutes,
                              args.trusted_connection, args.sql_user, args.sql_password)

    logger.info(f"Scheduler starting -- {args.interval_minutes}-minute cadence, aligned to clock boundaries")

    while True:
        target = next_aligned_time(args.interval_minutes)
        sleep_seconds = (target - datetime.datetime.now()).total_seconds()
        logger.info(f"Next collection at {target.strftime('%Y-%m-%d %H:%M:%S')} "
                    f"(sleeping {sleep_seconds:.0f}s)")
        if sleep_seconds > 0:
            time.sleep(sleep_seconds)

        logger.info(f"=== Collection cycle: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===")
        run_collector(os.path.join("query_store_collector.py"), conn_args)
        # min-interval-minutes as a second, independent safeguard beyond the
        # scheduler's own clock-aligned loop -- protects against an
        # out-of-band manual run landing between two scheduled cycles and
        # creating an extra, irregularly-spaced snapshot.
        run_collector(os.path.join("dmv_delta_collector.py"),
                      conn_args + ["--min-interval-minutes", str(args.interval_minutes)])


if __name__ == "__main__":
    main()
