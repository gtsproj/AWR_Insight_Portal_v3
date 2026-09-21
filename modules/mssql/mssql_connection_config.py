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
