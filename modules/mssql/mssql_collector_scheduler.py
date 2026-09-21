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

    ALTER DATABASE permission is NOT required for the collectors
    themselves to work -- they only need SELECT on the DMVs -- so a
    least-privilege service account (the norm, and the right setup)
    genuinely may not have it. That's expected, not a misconfiguration,
    so a permission failure here is caught and logged clearly rather
    than raised: the scheduler continues either way, just without
    being able to auto-align Query Store's own interval. Returns True/
    False rather than raising, so callers don't need their own
    try/except for this specific, anticipated failure mode.
    """
    import pyodbc
    conn_parts = [f"DRIVER={{ODBC Driver 17 for SQL Server}}", f"SERVER={host}"]
    if trusted_connection:
        conn_parts.append("Trusted_Connection=yes")
    else:
        conn_parts.append(f"UID={sql_user}")
        conn_parts.append(f"PWD={sql_password}")
    conn_str = ";".join(conn_parts)
    try:
        conn = pyodbc.connect(conn_str, autocommit=True, timeout=30)
        cur = conn.cursor()
        cur.execute(f"ALTER DATABASE [{database}] SET QUERY_STORE (INTERVAL_LENGTH_MINUTES = {interval_minutes})")
        conn.close()
        logger.info(f"QUERY_STORE INTERVAL_LENGTH_MINUTES set to {interval_minutes} for [{database}]")
        return True
    except Exception as e:
        err_text = str(e)
        if "permission" in err_text.lower() or "denied" in err_text.lower():
            logger.warning(
                f"Could not set QUERY_STORE INTERVAL_LENGTH_MINUTES for [{database}] -- "
                f"the collector account lacks ALTER DATABASE permission. This is expected "
                f"for a least-privilege service account and does NOT stop collection (only "
                f"SELECT on the DMVs is actually needed for that). Query Store's interval "
                f"will keep whatever it's currently set to. Have a DBA run this once, "
                f"manually, if you want it aligned to the collector's cadence: "
                f"ALTER DATABASE [{database}] SET QUERY_STORE (INTERVAL_LENGTH_MINUTES = {interval_minutes})"
            )
        else:
            logger.warning(f"Could not set QUERY_STORE INTERVAL_LENGTH_MINUTES for [{database}]: {e}")
        return False


def _redact_secrets(args: list) -> list:
    """
    Returns a copy of args with the value following any sensitive flag
    (--password, --sql-password) replaced with a placeholder, for
    logging only -- the real args (unredacted) are what actually get
    passed to subprocess.run. A real security gap otherwise: the
    command line, password included, would land in both the console
    and the log file in plain text on every single collection cycle.
    """
    SENSITIVE_FLAGS = ("--password", "--sql-password")
    redacted = list(args)
    for i, arg in enumerate(redacted):
        if arg in SENSITIVE_FLAGS and i + 1 < len(redacted):
            redacted[i + 1] = "***REDACTED***"
    return redacted


def run_collector(script_relpath, args):
    """Runs one collector as a subprocess, logging its outcome without
    raising -- a single failed cycle should not crash the scheduler
    loop; the next cycle gets its own fresh attempt."""
    script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), script_relpath)
    cmd = [sys.executable, script_path] + args
    logger.info(f"Running: {' '.join([sys.executable, script_path] + _redact_secrets(args))}")
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


def run_sqlwr_auto_generation(pg_conn, host_name: str, instance_name: str, output_dir: str):
    """
    Called after each collection cycle. Resolves the instance and
    generates any SQLWR reports now possible -- every new DMV snapshot
    against its immediate predecessor, skipping (and recording as
    skipped_restart) any pair spanning a detected SQL Server restart.
    A single failed generation attempt is logged and does not stop the
    scheduler loop, matching run_collector's own resilience.
    """
    try:
        from sqlwr_report_generator import auto_generate_sqlwr_reports
        with pg_conn.cursor() as cur:
            cur.execute(
                "SELECT id FROM mssql_instance_master WHERE host_name = %s AND instance_name = %s",
                (host_name, instance_name)
            )
            row = cur.fetchone()
        if not row:
            # First-ever collection for this instance -- resolve_instance_id()
            # inside the collector creates this row, but only once the
            # collector has actually run; nothing to generate yet regardless.
            return
        instance_id = row[0]
        os.makedirs(output_dir, exist_ok=True)
        result = auto_generate_sqlwr_reports(pg_conn, instance_id, output_dir)
        if result["generated"]:
            logger.info(f"SQLWR: generated {len(result['generated'])} report(s) for "
                        f"{host_name}\\{instance_name}: {result['generated']}")
        if result["skipped_restart"]:
            logger.info(f"SQLWR: skipped {len(result['skipped_restart'])} pair(s) for "
                        f"{host_name}\\{instance_name} -- SQL Server restart detected: "
                        f"{result['skipped_restart']}")
        if result["failed"]:
            logger.error(f"SQLWR: {len(result['failed'])} report(s) FAILED for "
                        f"{host_name}\\{instance_name}: {result['failed']}")
    except Exception as e:
        logger.error(f"SQLWR auto-generation failed for {host_name}\\{instance_name}: {e}")


def is_due(interval_minutes: int, now: datetime.datetime = None) -> bool:
    """
    True if `now` (checked to the minute) lands exactly on a
    midnight-based clock boundary for interval_minutes -- the same
    alignment principle as next_aligned_time, restated as a per-tick
    check rather than a single next-wakeup time, since the multi-
    instance scheduler (run_from_config) needs to evaluate several
    DIFFERENT connections' intervals against the same "now" on every
    tick, not sleep until one single next time.
    """
    if now is None:
        now = datetime.datetime.now()
    minutes_since_midnight = now.hour * 60 + now.minute
    return minutes_since_midnight % interval_minutes == 0


def run_from_config(sqlwr_output_dir: str = "sqlwr_reports"):
    """
    Multi-instance mode: reads every enabled row from mssql_connections
    and runs collection for whichever ones are due on this tick.

    Ticks every minute (the finest-grained valid QUERY_STORE interval)
    rather than sleeping until one single next-aligned-time the way the
    single-instance CLI mode does -- different instances can have
    different snap_interval_minutes running simultaneously, so there
    is no single "next wakeup" to sleep until; each connection's own
    due-ness has to be re-checked every minute instead.

    QUERY_STORE's own INTERVAL_LENGTH_MINUTES is set once per
    (connection, database) at scheduler startup, not re-set every
    tick -- same idempotent-but-startup-only reasoning as the
    single-instance mode's set_query_store_interval call, just looped
    across every enabled connection and every database on it.
    """
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'common'))
    from db import get_db_connection
    import mssql_connection_config as cc

    pg_conn = get_db_connection()
    connections = cc.fetch_enabled_connections(pg_conn)
    if not connections:
        logger.error("No enabled connections in mssql_connections -- nothing to schedule. "
                      "Add one via mssql_connection_config.upsert_connection() first.")
        return

    logger.info(f"Multi-instance scheduler starting -- {len(connections)} enabled connection(s)")

    for c in connections:
        if not c["databases"]:
            logger.info(f"{c['host_name']}\\{c['instance_name']}: databases=all -- skipping automatic "
                        f"QUERY_STORE interval alignment (the specific database list isn't known until "
                        f"collection runs). List explicit databases for this connection if automatic "
                        f"QUERY_STORE alignment is wanted, or set INTERVAL_LENGTH_MINUTES manually.")
            continue
        for db_name in c["databases"]:
            try:
                set_query_store_interval(c["host_name"], c["instance_name"], db_name,
                                          c["snap_interval_minutes"],
                                          c["auth_type"] == "trusted", c["username"], c["password"])
            except Exception as e:
                logger.error(f"Could not set QUERY_STORE interval for "
                            f"{c['host_name']}\\{c['instance_name']}/{db_name}: {e}")

    while True:
        now = datetime.datetime.now()
        next_minute = (now.replace(second=0, microsecond=0) + datetime.timedelta(minutes=1))
        time.sleep(max(0, (next_minute - datetime.datetime.now()).total_seconds()))

        now = datetime.datetime.now()
        for c in connections:
            if not is_due(c["snap_interval_minutes"], now):
                continue

            logger.info(f"=== Collection cycle: {c['host_name']}\\{c['instance_name']} "
                        f"at {now.strftime('%Y-%m-%d %H:%M:%S')} ===")
            conn_args = ["--host", c["host_name"], "--instance-name", c["instance_name"]]
            if c["auth_type"] == "trusted":
                conn_args.append("--trusted-connection")
            else:
                conn_args.extend(["--username", c["username"], "--password", c["password"]])
            if c["databases"]:
                for db_name in c["databases"]:
                    conn_args.extend(["--database", db_name])

            run_collector("query_store_collector.py", conn_args)
            run_collector("dmv_delta_collector.py",
                          conn_args + ["--min-interval-minutes", str(c["snap_interval_minutes"])])

            run_sqlwr_auto_generation(pg_conn, c["host_name"], c["instance_name"], sqlwr_output_dir)

            cc.record_run_result(pg_conn, c["id"], "success")


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--from-config", action="store_true",
                         help="Multi-instance mode: read every enabled connection from "
                              "mssql_connections instead of the single-instance CLI args below. "
                              "Each connection runs on its own snap_interval_minutes.")
    parser.add_argument("--host")
    parser.add_argument("--instance-name", default="MSSQLSERVER")
    parser.add_argument("--database")
    parser.add_argument("--interval-minutes", type=int, default=60, choices=[1, 5, 10, 15, 30, 60, 1440],
                         help="Collection cadence, and the value QUERY_STORE's own "
                              "INTERVAL_LENGTH_MINUTES gets set to match -- restricted to "
                              "SQL Server's own documented set of valid INTERVAL_LENGTH_MINUTES "
                              "values (arbitrary values are rejected by SQL Server itself: "
                              "1, 5, 10, 15, 30, 60, or 1440 minutes only)")
    parser.add_argument("--trusted-connection", action="store_true")
    parser.add_argument("--sql-user", default=None)
    parser.add_argument("--sql-password", default=None)
    parser.add_argument("--sqlwr-output-dir", default="sqlwr_reports",
                         help="Directory SQLWR HTML reports are written to (created if missing)")
    args = parser.parse_args()

    if args.from_config:
        run_from_config(sqlwr_output_dir=args.sqlwr_output_dir)
        return

    if not args.host or not args.database:
        print("--host and --database are required unless --from-config is given")
        return

    conn_args = ["--host", args.host, "--instance-name", args.instance_name, "--database", args.database]
    if args.trusted_connection:
        conn_args.append("--trusted-connection")
    else:
        conn_args.extend(["--username", args.sql_user, "--password", args.sql_password])

    set_query_store_interval(args.host, args.instance_name, args.database, args.interval_minutes,
                              args.trusted_connection, args.sql_user, args.sql_password)

    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'common'))
    from db import get_db_connection
    pg_conn = get_db_connection()

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

        run_sqlwr_auto_generation(pg_conn, args.host, args.instance_name, args.sqlwr_output_dir)


if __name__ == "__main__":
    main()
