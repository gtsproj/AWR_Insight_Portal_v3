"""
modules/mssql/connection.py
=============================
Shared connection, authentication, and DATETIMEOFFSET-handling logic
for every MS SQL Server collector (Query Store, cumulative-DMV, and
whatever comes after). Extracted out of query_store_collector.py once
a second collector needed the exact same ~120 lines -- duplicating
proven, hard-won connection logic across multiple files would mean
fixing the same bug twice if it ever needs another fix, which is
worse than the small cost of one shared import.

Every function here was proven working against a real SQL Server
instance as part of query_store_collector.py's own debugging pass
(see that file's git history for the specific errors each fix
resolved) -- this is a pure extraction, not new/re-tested logic.
"""

import struct
from datetime import datetime, timezone, timedelta

try:
    from config_loader import load_config
    _cfg = load_config() or {}
except Exception:
    _cfg = {}

# Same config pattern as ai_narrative/oracle_live_query -- configurable,
# defaults preserve current behaviour if the key is missing. Shared
# across every mssql collector, not per-collector, since it's a
# connection-level setting.
QUERY_TIMEOUT_SECONDS = int(_cfg.get("mssql", {}).get("query_timeout_seconds", 30))


def handle_datetimeoffset(dto_value):
    """
    pyodbc output converter for SQL Server's DATETIMEOFFSET type (ODBC
    type -155, SQL_SS_TIMESTAMPOFFSET) -- pyodbc has no native support
    for this type and raises "ODBC SQL type -155 is not yet supported"
    without this registered. Confirmed against a real connection
    attempt against sys.query_store_runtime_stats_interval.start_time/
    end_time, which are DATETIMEOFFSET columns -- and DATETIMEOFFSET
    shows up widely across other DMVs too (e.g. sys.dm_exec_sessions'
    login_time, sys.dm_os_wait_stats has none, but several session/
    request DMVs do), which is exactly why this lives here now rather
    than staying private to the Query Store collector alone.

    This exact struct format ("<6hI2h") is the canonical, widely-used
    fix for this pyodbc limitation -- verified against pyodbc's own
    official wiki (Using an Output Converter function), a real pyodbc
    GitHub issue thread, and an independent production integration
    (Django + MS SQL), all using this identical byte layout. Not
    something reconstructed from memory -- cross-checked across
    multiple independent, working examples before use here, since a
    subtly wrong byte-unpacking here wouldn't crash, it would silently
    produce a wrong timestamp.

    Ref: https://github.com/mkleehammer/pyodbc/issues/134#issuecomment-281739794
    """
    tup = struct.unpack("<6hI2h", dto_value)
    return datetime(tup[0], tup[1], tup[2], tup[3], tup[4], tup[5], tup[6] // 1000,
                     timezone(timedelta(hours=tup[7], minutes=tup[8])))


def to_naive_utc(dt):
    """
    handle_datetimeoffset above returns a timezone-AWARE datetime
    (DATETIMEOFFSET carries its own UTC offset). Every TIMESTAMP
    WITHOUT TIME ZONE column this data eventually lands in (across
    every mssql_* table, not just Query Store's) needs this applied
    first -- inserting a tz-aware value without an explicit,
    deliberate conversion risks psycopg2 silently dropping the offset
    information rather than normalizing it, which would store the
    correct WALL-CLOCK numbers but the WRONG absolute moment in time
    for any source server not running in UTC. Explicitly converting to
    UTC and stripping tzinfo here means the stored value is always an
    unambiguous UTC timestamp, not dependent on implicit driver
    behaviour.
    """
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


def mssql_connect(cfg: dict):
    """
    Open a pyodbc connection to a SQL Server instance.

    cfg: {"host": ..., "port": ..., "instance_name": ... (optional,
    named-instance form), "database": ...} plus EITHER:
      - "trusted_connection": True -- Windows Authentication, uses the
        credentials of whatever Windows account is running this script.
        No username/password needed or used.
      - "username" / "password" -- SQL Server (mixed-mode) Authentication.

    Two real connection-string bugs were found and fixed here against
    a live instance (both explained in full in query_store_collector.py's
    git history, kept brief here since this is a proven extraction,
    not new code):
      1. "MSSQLSERVER" (the CLI's own default for --instance-name,
         meaning "the default instance") was being appended as if it
         were a genuine named instance, which SQL Server Browser then
         correctly failed to resolve.
      2. The instance-name branch was silently overwriting the server
         string, discarding any port set by the branch above it.
    """
    try:
        import pyodbc
    except ImportError:
        raise ImportError('pyodbc not installed. Run: pip install pyodbc')

    server = cfg["host"]
    is_named_instance = cfg.get("instance_name") and cfg["instance_name"] != "MSSQLSERVER"
    if is_named_instance:
        # SQL Server Browser resolves the port for a named instance --
        # a port is not normally also specified alongside one.
        server = f"{cfg['host']}\\{cfg['instance_name']}"
    elif cfg.get("port"):
        server = f"{server},{cfg['port']}"

    if cfg.get("trusted_connection"):
        conn_str = (
            f"DRIVER={{ODBC Driver 18 for SQL Server}};"
            f"SERVER={server};"
            f"DATABASE={cfg.get('database', 'master')};"
            f"Trusted_Connection=yes;"
            f"TrustServerCertificate=yes;"  # test/dev default -- revisit for
                                             # production once cert handling
                                             # is actually decided
        )
    else:
        conn_str = (
            f"DRIVER={{ODBC Driver 18 for SQL Server}};"
            f"SERVER={server};"
            f"DATABASE={cfg.get('database', 'master')};"
            f"UID={cfg['username']};"
            f"PWD={cfg['password']};"
            f"TrustServerCertificate=yes;"
        )
    conn = pyodbc.connect(conn_str, timeout=QUERY_TIMEOUT_SECONDS)
    conn.add_output_converter(-155, handle_datetimeoffset)  # DATETIMEOFFSET support -- see docstring above
    conn.timeout = QUERY_TIMEOUT_SECONDS  # per-query timeout after connect
    return conn


def resolve_instance_id(host_name: str, instance_name: str) -> int:
    """
    Resolve this connection's row in mssql_instance_master, matching
    is_db_licensed's existing pattern of treating this table as the
    licensed-instance gate (Analysis Model doc Section 5.1 /
    mssql_core_tables.sql's own comment: "Only instances in this table
    will be collected by the MS SQL collector"). Does NOT auto-create
    a row for an unregistered instance -- an unlicensed/unregistered
    instance should fail loudly here, not silently start being
    collected.
    """
    from db import get_db_connection
    pg_conn = get_db_connection()
    try:
        with pg_conn.cursor() as cur:
            cur.execute(
                "SELECT id FROM mssql_instance_master "
                "WHERE host_name = %s AND instance_name = %s AND active = true",
                (host_name, instance_name)
            )
            row = cur.fetchone()
            if not row:
                raise ValueError(
                    f"No active mssql_instance_master row for "
                    f"{host_name}\\{instance_name} -- register it first, "
                    f"the collector will not auto-create one."
                )
            return row[0]
    finally:
        pg_conn.close()
