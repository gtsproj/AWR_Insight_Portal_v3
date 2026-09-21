"""
modules/mssql/mssql_connection_config.py
===========================================
Reads/writes mssql_connections -- the credential/config store
supporting multiple SQL Server instances, each with multiple
databases, so mssql_collector_scheduler.py doesn't need hardcoded
per-instance CLI invocations for every server in the environment.

Password handling deliberately mirrors modules/oracle_awr_fetcher.py's
_encode_password/_decode_password exactly, including the same honest
framing: base64 obfuscation, NOT encryption. It prevents plain-text
storage; it is not a real secret store. Kept as a separate copy here
rather than importing the Oracle module, so this module has no
Oracle-side dependency at all.
"""

import base64
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'common'))


def encode_password(plain: str) -> str:
    """Base64 obfuscation -- not encryption, just prevents plain-text storage."""
    return base64.b64encode(plain.encode('utf-8')).decode('utf-8')


def decode_password(encoded: str) -> str:
    try:
        return base64.b64decode(encoded.encode('utf-8')).decode('utf-8')
    except Exception:
        return encoded  # already plain text


def fetch_enabled_connections(pg_conn) -> list:
    """
    Returns every enabled row from mssql_connections as a list of
    dicts, password already decoded (callers should not see
    password_enc directly -- this is the one place that boundary is
    crossed). Each dict: id, host_name, instance_name, display_name,
    port, auth_type, username, password (decoded, empty string for
    trusted auth), databases (list or None), snap_interval_minutes,
    last_run_at.
    """
    with pg_conn.cursor() as cur:
        cur.execute("""
            SELECT id, host_name, instance_name, display_name, port, auth_type,
                   username, password_enc, databases, snap_interval_minutes, last_run_at
            FROM mssql_connections
            WHERE enabled = true
            ORDER BY host_name, instance_name
        """)
        rows = cur.fetchall()

    connections = []
    for (conn_id, host_name, instance_name, display_name, port, auth_type,
         username, password_enc, databases, interval_minutes, last_run_at) in rows:
        connections.append({
            "id": conn_id,
            "host_name": host_name,
            "instance_name": instance_name,
            "display_name": display_name,
            "port": port,
            "auth_type": auth_type,
            "username": username,
            "password": decode_password(password_enc) if password_enc else "",
            "databases": list(databases) if databases else None,
            "snap_interval_minutes": interval_minutes,
            "last_run_at": last_run_at,
        })
    return connections


def upsert_connection(pg_conn, host_name: str, instance_name: str, auth_type: str,
                        snap_interval_minutes: int, display_name: str = None,
                        port: int = None, username: str = None, password: str = None,
                        databases: list = None, enabled: bool = True,
                        added_by: str = "admin") -> int:
    """
    Creates or updates one instance's connection config (matched on
    host_name + instance_name, the same natural key
    mssql_instance_master itself uses). password, if given, is
    obfuscated before storage; passing None for password on an update
    keeps whatever password is already stored, the same "keep existing
    password if not resupplied" behavior the Oracle side's own
    connection-save endpoint uses. Returns the connection's id.

    Deliberately an explicit SELECT-then-branch, not
    INSERT ... ON CONFLICT DO UPDATE -- a real bug found through
    testing: Postgres validates CHECK constraints against the
    CANDIDATE insert row even when it's destined to redirect to the
    update path on conflict. Omitting password_enc from the insert
    column list when not resupplying it still leaves a NULL candidate
    value, which fails chk_mssql_conn_auth's "sql auth requires a
    password" check before conflict resolution ever runs -- even
    though the row would never actually be inserted. An explicit
    UPDATE only validates constraints against the final, post-update
    row, which correctly still has the existing password_enc untouched.
    """
    password_enc = encode_password(password) if password else None

    with pg_conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM mssql_connections WHERE host_name = %s AND instance_name = %s",
            (host_name, instance_name)
        )
        existing = cur.fetchone()

        if existing:
            conn_id = existing[0]
            if password_enc is not None:
                cur.execute("""
                    UPDATE mssql_connections SET
                        display_name = %s, port = %s, auth_type = %s, username = %s,
                        password_enc = %s, databases = %s,
                        snap_interval_minutes = %s, enabled = %s
                    WHERE id = %s
                """, (display_name, port, auth_type, username, password_enc, databases,
                      snap_interval_minutes, enabled, conn_id))
            else:
                cur.execute("""
                    UPDATE mssql_connections SET
                        display_name = %s, port = %s, auth_type = %s, username = %s,
                        databases = %s, snap_interval_minutes = %s, enabled = %s
                    WHERE id = %s
                """, (display_name, port, auth_type, username, databases,
                      snap_interval_minutes, enabled, conn_id))
        else:
            cur.execute("""
                INSERT INTO mssql_connections
                    (host_name, instance_name, display_name, port, auth_type, username,
                     password_enc, databases, snap_interval_minutes, enabled, added_by)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                RETURNING id
            """, (host_name, instance_name, display_name, port, auth_type, username,
                  password_enc, databases, snap_interval_minutes, enabled, added_by))
            conn_id = cur.fetchone()[0]

    pg_conn.commit()
    return conn_id


def save_connection(data: dict, added_by: str = "admin") -> dict:
    """
    Validates a dict payload (the shape the portal UI actually posts)
    and delegates to upsert_connection(). Returns {ok, id, error} --
    same shape as oracle_awr_fetcher.save_connection(), so the app.py
    endpoint calling this can mirror the Oracle one almost exactly.
    """
    host_name = (data.get("host_name") or "").strip()
    instance_name = (data.get("instance_name") or "MSSQLSERVER").strip()
    display_name = (data.get("display_name") or "").strip() or None
    auth_type = (data.get("auth_type") or "trusted").strip()
    username = (data.get("username") or "").strip() or None
    password = (data.get("password") or "").strip() or None
    port = int(data["port"]) if data.get("port") else None
    databases = data.get("databases") or None
    if databases and isinstance(databases, str):
        databases = [d.strip() for d in databases.split(",") if d.strip()]
    snap_interval_minutes = int(data.get("snap_interval_minutes") or 60)
    enabled = bool(data.get("enabled", True))

    if not host_name:
        return {"ok": False, "error": "host_name is required"}
    if auth_type not in ("trusted", "sql"):
        return {"ok": False, "error": "auth_type must be 'trusted' or 'sql'"}
    if auth_type == "sql" and not username:
        return {"ok": False, "error": "username is required for SQL authentication"}
    if snap_interval_minutes not in (1, 5, 10, 15, 30, 60, 1440):
        return {"ok": False, "error": "snap_interval_minutes must be one of "
                                        "SQL Server's own valid QUERY_STORE values: "
                                        "1, 5, 10, 15, 30, or 60 minutes, or 1440 (daily)"}

    # For a genuinely new sql-auth connection, a password must be
    # supplied -- there's nothing existing to "keep" the way an update
    # can. upsert_connection can't tell new-vs-existing from the
    # outside, so that check belongs here.
    if auth_type == "sql" and not password:
        # Only an error if this is a NEW connection -- an update
        # legitimately omits the password to keep the existing one.
        try:
            from db import get_db_connection
            pg_conn = get_db_connection()
            with pg_conn.cursor() as cur:
                cur.execute(
                    "SELECT 1 FROM mssql_connections WHERE host_name = %s AND instance_name = %s",
                    (host_name, instance_name)
                )
                exists = cur.fetchone() is not None
            pg_conn.close()
        except Exception:
            exists = False
        if not exists:
            return {"ok": False, "error": "password is required for a new SQL authentication connection"}

    try:
        from db import get_db_connection
        pg_conn = get_db_connection()
        conn_id = upsert_connection(
            pg_conn, host_name, instance_name, auth_type, snap_interval_minutes,
            display_name=display_name, port=port, username=username, password=password,
            databases=databases, enabled=enabled, added_by=added_by
        )
        pg_conn.close()
        return {"ok": True, "id": conn_id}
    except Exception as e:
        return {"ok": False, "error": str(e)}


def record_run_result(pg_conn, connection_id: int, status: str, snapshot_id: int = None,
                        error: str = None):
    """Updates last_run_at/last_run_status/last_dmv_snapshot_id/last_run_error
    after a collection cycle -- so the connections table itself shows
    each instance's most recent outcome, not just its config."""
    with pg_conn.cursor() as cur:
        cur.execute("""
            UPDATE mssql_connections
            SET last_run_at = now(), last_run_status = %s,
                last_dmv_snapshot_id = COALESCE(%s, last_dmv_snapshot_id),
                last_run_error = %s
            WHERE id = %s
        """, (status, snapshot_id, error, connection_id))
    pg_conn.commit()


def get_all_connections(pg_conn) -> list:
    """
    Every row (enabled or not), password never included -- the portal
    settings UI's connection table, mirroring
    oracle_awr_fetcher.get_all_connections()'s shape and its
    "never return the password" rule exactly.
    """
    with pg_conn.cursor() as cur:
        cur.execute("""
            SELECT id, host_name, instance_name, display_name, port, auth_type,
                   username, databases, snap_interval_minutes, enabled,
                   last_run_at, last_dmv_snapshot_id, last_run_status, last_run_error,
                   added_at, added_by
            FROM mssql_connections
            ORDER BY host_name, instance_name
        """)
        cols = [d[0] for d in cur.description]
        rows = []
        for row in cur.fetchall():
            d = dict(zip(cols, row))
            for k, v in d.items():
                if hasattr(v, 'strftime'):
                    d[k] = v.strftime('%Y-%m-%d %H:%M:%S')
                elif hasattr(v, 'quantize'):
                    d[k] = float(v)
            rows.append(d)
        return rows


def get_connection_by_id(pg_conn, connection_id: int) -> dict:
    """Returns one connection WITH its password decoded -- for internal
    use only (e.g. test_connection), never returned directly to the
    portal UI the way get_all_connections() is."""
    with pg_conn.cursor() as cur:
        cur.execute("""
            SELECT id, host_name, instance_name, display_name, port, auth_type,
                   username, password_enc, databases, snap_interval_minutes, enabled
            FROM mssql_connections
            WHERE id = %s
        """, (connection_id,))
        row = cur.fetchone()
    if not row:
        return None
    cols = ["id", "host_name", "instance_name", "display_name", "port", "auth_type",
            "username", "password_enc", "databases", "snap_interval_minutes", "enabled"]
    d = dict(zip(cols, row))
    d["password"] = decode_password(d.pop("password_enc")) if d.get("password_enc") else ""
    return d


def delete_connection(pg_conn, connection_id: int) -> dict:
    try:
        with pg_conn.cursor() as cur:
            cur.execute("DELETE FROM mssql_connections WHERE id = %s", (connection_id,))
        pg_conn.commit()
        return {"ok": True}
    except Exception as e:
        pg_conn.rollback()
        return {"ok": False, "error": str(e)}


def test_connection(cfg: dict) -> dict:
    """
    Verifies actual SQL Server connectivity with the given credentials
    -- a real pyodbc connection attempt, not just a config validity
    check. Returns {ok, message, sql_version, databases_visible}.
    Mirrors oracle_awr_fetcher.test_connection()'s role and return
    shape for the portal UI's "test" button.
    """
    try:
        import pyodbc
    except ImportError:
        return {"ok": False, "message": "pyodbc not installed. Run: pip install pyodbc"}

    conn_parts = [f"DRIVER={{ODBC Driver 17 for SQL Server}}", f"SERVER={cfg['host_name']}"]
    if cfg.get("port"):
        conn_parts[-1] += f",{cfg['port']}"
    if cfg.get("auth_type") == "trusted":
        conn_parts.append("Trusted_Connection=yes")
    else:
        conn_parts.append(f"UID={cfg.get('username', '')}")
        conn_parts.append(f"PWD={cfg.get('password', '')}")

    try:
        conn = pyodbc.connect(";".join(conn_parts), timeout=10)
        cur = conn.cursor()
        cur.execute("SELECT @@VERSION")
        version = cur.fetchone()[0]
        cur.execute("SELECT name FROM sys.databases WHERE state = 0 ORDER BY name")
        db_names = [r[0] for r in cur.fetchall()]
        conn.close()
        return {
            "ok": True,
            "message": f"Connected successfully -- {len(db_names)} online database(s) visible",
            "sql_version": version.split("\n")[0] if version else None,
            "databases_visible": db_names,
        }
    except Exception as e:
        return {"ok": False, "message": f"Connection failed: {e}"}

