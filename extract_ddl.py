#!/usr/bin/env python3
"""
extract_ddl.py
==============
Extract DDL for all DAR Portal database objects.

Fixes vs previous version:
  1. CONSTRAINT CARTESIAN BUG — the original query joined
     key_column_usage AND constraint_column_usage on constraint_name
     only, producing N*N rows for any N-column PK or UNIQUE constraint.
     Fix: run SEPARATE queries per constraint type so each returns
     exactly the rows it owns.

  2. PORTAL-ONLY OBJECTS — the portal database also contains tables
     from external tools (powa / pg_activity: sample_*, baselines,
     servers etc). These are now excluded via an explicit whitelist
     of portal-owned table prefixes and exact names.

Usage:
  py extract_ddl.py
  py extract_ddl.py --output schema/awr_portal_full_schema_extracted_from_database.sql
  py extract_ddl.py --schema public --no-functions

Output: ready-to-run SQL for fresh installation on a new server.
"""

import sys
import os
import argparse
from datetime import datetime

_PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, "common"))

try:
    from config_loader import load_config
    import psycopg2
    def get_db_connection():
        cfg = load_config().get('database', {})
        return psycopg2.connect(
            host=cfg.get('host', 'localhost'), port=cfg.get('port', 5432),
            user=cfg.get('user'), password=cfg.get('password'),
            database=cfg.get('dbname', 'postgres')
        )
except ImportError:
    import psycopg2
    def get_db_connection():
        return psycopg2.connect(
            host='localhost', port=5432,
            user='postgres', password='postgres', database='postgres'
        )


# ── Portal-owned table/view whitelist ─────────────────────────────────────────
# Tables whose names START WITH any of these prefixes belong to the DAR Portal.
PORTAL_PREFIXES = (
    'awr_',
    'sar_',
    'exec_plan_',
    'portal_',
    'wait_event_',
    'remote_fetch_',
)

# Exact names that don't match a prefix but are portal tables
PORTAL_EXACT = {
    'sar_anomalies',
}

# Tables to explicitly EXCLUDE even if they match a prefix above.
# These are from external tools (powa, pg_activity, pg_stat_statements view etc).
EXCLUDE_EXACT = {
    # powa / pg_activity tables that share no prefix with portal tables
    'baselines', 'bl_samples', 'department', 'funcs_list',
    'import_queries', 'import_queries_version_order', 'indexes_list',
    'last_stat_archiver', 'last_stat_cluster', 'last_stat_database',
    'last_stat_indexes', 'last_stat_tables', 'last_stat_tablespaces',
    'last_stat_user_functions', 'last_stat_wal',
    'sample_kcache', 'sample_kcache_total', 'sample_settings',
    'sample_stat_archiver', 'sample_stat_cluster', 'sample_stat_database',
    'sample_stat_indexes', 'sample_stat_indexes_failures',
    'sample_stat_indexes_total', 'sample_stat_tables',
    'sample_stat_tables_failures', 'sample_stat_tables_total',
    'sample_stat_tablespaces', 'sample_stat_user_func_total',
    'sample_stat_user_functions', 'sample_stat_wal',
    'sample_statements', 'sample_statements_total', 'sample_timings',
    'samples', 'sample_kcache', 'servers', 'stmt_list',
    'tables_list', 'tablespaces_list',
    # built-in view exposed via pg_stat_statements extension
    'pg_stat_statements',
    # powa views
    'v_sample_settings', 'v_sample_stat_indexes', 'v_sample_stat_tables',
    'v_sample_stat_tablespaces', 'v_sample_stat_user_functions', 'v_sample_timings',
}


def is_portal_table(name: str) -> bool:
    """Return True if the table/view belongs to the DAR Portal."""
    if name in EXCLUDE_EXACT:
        return False
    if name in PORTAL_EXACT:
        return True
    return any(name.startswith(pfx) for pfx in PORTAL_PREFIXES)


HEADER = """\
-- ============================================================
-- DAR Portal v3 — Database Analysis and Recommendations
-- Complete Schema DDL
-- Generated: {timestamp}
-- Tool: extract_ddl.py
-- ============================================================
-- Run as:
--   psql -U postgres -d postgres -f {output}
-- ============================================================

SET client_min_messages = WARNING;
SET search_path = public;

"""

SECTION = """\

-- ============================================================
-- {title}
-- ============================================================
"""


# ── Connection helpers ─────────────────────────────────────────────────────────

def get_types(cur, schema):
    cur.execute("""
        SELECT t.typname, t.typtype
        FROM pg_type t
        JOIN pg_namespace n ON n.oid = t.typnamespace
        WHERE n.nspname = %s AND t.typtype IN ('e','c')
          AND t.typname NOT LIKE '\\_%%'
        ORDER BY t.typname
    """, (schema,))
    result = []
    for tname, ttype in cur.fetchall():
        if ttype == 'e':
            cur.execute("""
                SELECT e.enumlabel
                FROM pg_enum e
                JOIN pg_type t ON t.oid = e.enumtypid
                JOIN pg_namespace n ON n.oid = t.typnamespace
                WHERE n.nspname = %s AND t.typname = %s
                ORDER BY e.enumsortorder
            """, (schema, tname))
            result.append((tname, ttype, [r[0] for r in cur.fetchall()]))
        else:
            result.append((tname, ttype, []))
    return result


def get_tables(cur, schema):
    cur.execute("""
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = %s AND table_type = 'BASE TABLE'
        ORDER BY table_name
    """, (schema,))
    return [r[0] for r in cur.fetchall() if is_portal_table(r[0])]


def get_table_ddl(cur, schema, table_name):
    """
    Generate CREATE TABLE statement.

    Bug fix: The original script joined key_column_usage (kcu) with
    constraint_column_usage (ccu) on constraint_name alone.  For a
    PRIMARY KEY or UNIQUE with N columns, kcu returns N rows and ccu
    also returns N rows — the join produces N*N rows (Cartesian product).
    For FK constraints the situation is different but also broken: kcu
    holds child columns and ccu holds referenced columns; joining them
    without position matching scrambles multi-column FKs.

    Fix: run four separate, focused queries — one per constraint type.
    Each query returns exactly the rows it should.
    """
    # ── Columns ────────────────────────────────────────────────────────────────
    cur.execute("""
        SELECT
            c.column_name,
            c.data_type,
            c.character_maximum_length,
            c.numeric_precision,
            c.numeric_scale,
            c.is_nullable,
            c.column_default,
            c.udt_name
        FROM information_schema.columns c
        WHERE c.table_schema = %s AND c.table_name = %s
        ORDER BY c.ordinal_position
    """, (schema, table_name))
    columns = cur.fetchall()

    # ── Primary keys — kcu only (ordered by position) ─────────────────────────
    cur.execute("""
        SELECT tc.constraint_name, kcu.column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
            ON  kcu.constraint_name = tc.constraint_name
            AND kcu.table_schema    = tc.table_schema
            AND kcu.table_name      = tc.table_name
        WHERE tc.table_schema   = %s
          AND tc.table_name     = %s
          AND tc.constraint_type = 'PRIMARY KEY'
        ORDER BY tc.constraint_name, kcu.ordinal_position
    """, (schema, table_name))
    pk_rows = cur.fetchall()
    pk_cols = {}
    for cname, col in pk_rows:
        pk_cols.setdefault(cname, []).append(col)

    # ── Unique constraints — kcu only ─────────────────────────────────────────
    cur.execute("""
        SELECT tc.constraint_name, kcu.column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
            ON  kcu.constraint_name = tc.constraint_name
            AND kcu.table_schema    = tc.table_schema
            AND kcu.table_name      = tc.table_name
        WHERE tc.table_schema    = %s
          AND tc.table_name      = %s
          AND tc.constraint_type = 'UNIQUE'
        ORDER BY tc.constraint_name, kcu.ordinal_position
    """, (schema, table_name))
    uq_rows = cur.fetchall()
    uq_cols = {}
    for cname, col in uq_rows:
        uq_cols.setdefault(cname, []).append(col)

    # ── Foreign keys — kcu for child cols, separate ccu for parent ────────────
    # Join kcu and ccu on BOTH constraint_name AND ordinal_position so
    # multi-column FKs map child col[i] -> parent col[i] correctly.
    cur.execute("""
        SELECT
            tc.constraint_name,
            kcu.column_name            AS child_col,
            ccu.table_name             AS ref_table,
            ccu.column_name            AS ref_col,
            rc.update_rule,
            rc.delete_rule
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
            ON  kcu.constraint_name = tc.constraint_name
            AND kcu.table_schema    = tc.table_schema
            AND kcu.table_name      = tc.table_name
        JOIN information_schema.referential_constraints rc
            ON  rc.constraint_name   = tc.constraint_name
            AND rc.constraint_schema = tc.table_schema
        JOIN information_schema.key_column_usage ccu
            ON  ccu.constraint_name  = rc.unique_constraint_name
            AND ccu.table_schema     = rc.unique_constraint_schema
            AND ccu.ordinal_position = kcu.ordinal_position
        WHERE tc.table_schema    = %s
          AND tc.table_name      = %s
          AND tc.constraint_type = 'FOREIGN KEY'
        ORDER BY tc.constraint_name, kcu.ordinal_position
    """, (schema, table_name))
    fk_rows = cur.fetchall()
    # Group by constraint_name to handle multi-col FKs
    fk_groups = {}
    for cname, child_col, ref_table, ref_col, upd, del_ in fk_rows:
        fk_groups.setdefault(cname, {
            'child_cols': [], 'ref_table': ref_table,
            'ref_cols': [], 'upd': upd, 'del': del_
        })
        fk_groups[cname]['child_cols'].append(child_col)
        fk_groups[cname]['ref_cols'].append(ref_col)

    # ── Check constraints ─────────────────────────────────────────────────────
    cur.execute("""
        SELECT tc.constraint_name, cc.check_clause
        FROM information_schema.table_constraints tc
        JOIN information_schema.check_constraints cc
            ON  cc.constraint_name   = tc.constraint_name
            AND cc.constraint_schema = tc.table_schema
        WHERE tc.table_schema    = %s
          AND tc.table_name      = %s
          AND tc.constraint_type = 'CHECK'
          AND tc.constraint_name NOT LIKE '%%_not_null'
          AND cc.check_clause    NOT LIKE '%%IS NOT NULL%%'
        ORDER BY tc.constraint_name
    """, (schema, table_name))
    check_rows = cur.fetchall()

    # ── Build column definitions ───────────────────────────────────────────────
    col_defs = []
    for col in columns:
        col_name, data_type, char_len, num_prec, num_scale, nullable, default, udt = col

        if data_type == 'character varying':
            type_str = f"VARCHAR({char_len})" if char_len else "TEXT"
        elif data_type == 'character':
            type_str = f"CHAR({char_len})" if char_len else "CHAR"
        elif data_type == 'numeric':
            if num_prec and num_scale is not None:
                type_str = f"NUMERIC({num_prec},{num_scale})"
            elif num_prec:
                type_str = f"NUMERIC({num_prec})"
            else:
                type_str = "NUMERIC"
        elif data_type == 'USER-DEFINED':
            type_str = udt
        elif data_type == 'ARRAY':
            type_str = udt.lstrip('_') + '[]'
        else:
            type_str = data_type.upper()

        if default and 'nextval' in str(default):
            if any(x in data_type for x in ('integer', 'int4', 'int2', 'smallint')):
                col_def = f"    {col_name:<30} SERIAL"
            elif any(x in data_type for x in ('bigint', 'int8')):
                col_def = f"    {col_name:<30} BIGSERIAL"
            else:
                col_def = f"    {col_name:<30} {type_str} DEFAULT {default}"
        else:
            col_def = f"    {col_name:<30} {type_str}"
            if default:
                col_def += f" DEFAULT {default}"

        if nullable == 'NO' and 'nextval' not in str(default or ''):
            col_def += " NOT NULL"

        col_defs.append(col_def)

    # ── Build constraint definitions ───────────────────────────────────────────
    constraint_defs = []

    for cname, cols in pk_cols.items():
        constraint_defs.append(
            f"    CONSTRAINT {cname} PRIMARY KEY ({', '.join(cols)})"
        )

    for cname, cols in uq_cols.items():
        constraint_defs.append(
            f"    CONSTRAINT {cname} UNIQUE ({', '.join(cols)})"
        )

    for cname, fk in fk_groups.items():
        child = ', '.join(fk['child_cols'])
        parent = ', '.join(fk['ref_cols'])
        fk_def = (f"    CONSTRAINT {cname} FOREIGN KEY ({child})\n"
                  f"        REFERENCES {fk['ref_table']} ({parent})")
        if fk['del'] and fk['del'] != 'NO ACTION':
            fk_def += f" ON DELETE {fk['del']}"
        if fk['upd'] and fk['upd'] != 'NO ACTION':
            fk_def += f" ON UPDATE {fk['upd']}"
        constraint_defs.append(fk_def)

    for cname, clause in check_rows:
        constraint_defs.append(f"    CONSTRAINT {cname} CHECK {clause}")

    # ── Tablespace ─────────────────────────────────────────────────────────────
    cur.execute("""
        SELECT t.spcname
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        LEFT JOIN pg_tablespace t ON t.oid = c.reltablespace
        WHERE n.nspname = %s AND c.relname = %s
    """, (schema, table_name))
    ts_row = cur.fetchone()
    ts_clause = ""
    if ts_row and ts_row[0]:
        ts_clause = f" TABLESPACE {ts_row[0]}"

    all_defs = col_defs + constraint_defs
    ddl = f"CREATE TABLE IF NOT EXISTS {table_name} (\n"
    ddl += ',\n'.join(all_defs)
    ddl += f"\n){ts_clause};\n"

    # ── Table comment ──────────────────────────────────────────────────────────
    cur.execute("""
        SELECT obj_description(
            (quote_ident(%s) || '.' || quote_ident(%s))::regclass, 'pg_class'
        )
    """, (schema, table_name))
    comment = cur.fetchone()[0]
    if comment:
        safe = comment.replace("'", "''")
        ddl += f"COMMENT ON TABLE {table_name} IS '{safe}';\n"

    return ddl


def get_indexes(cur, schema, table_name):
    """Return CREATE INDEX statements excluding constraint-backing indexes."""
    cur.execute("""
        SELECT indexname, indexdef
        FROM pg_indexes
        WHERE schemaname = %s AND tablename = %s
          AND indexname NOT IN (
              SELECT constraint_name
              FROM information_schema.table_constraints
              WHERE table_schema = %s AND table_name = %s
          )
        ORDER BY indexname
    """, (schema, table_name, schema, table_name))
    ddls = []
    for iname, idef in cur.fetchall():
        idef = idef.replace('CREATE INDEX ', 'CREATE INDEX IF NOT EXISTS ', 1)
        idef = idef.replace('CREATE UNIQUE INDEX ', 'CREATE UNIQUE INDEX IF NOT EXISTS ', 1)
        ddls.append(idef + ';')
    return ddls


def get_views(cur, schema):
    cur.execute("""
        SELECT table_name, view_definition
        FROM information_schema.views
        WHERE table_schema = %s
        ORDER BY table_name
    """, (schema,))
    return [(r[0], r[1]) for r in cur.fetchall() if is_portal_table(r[0])]


def get_materialized_views(cur, schema):
    cur.execute("""
        SELECT matviewname, definition, ispopulated
        FROM pg_matviews WHERE schemaname = %s
        ORDER BY matviewname
    """, (schema,))
    return [(r[0], r[1], r[2]) for r in cur.fetchall() if is_portal_table(r[0])]


def get_mv_indexes(cur, schema, mvname):
    cur.execute("""
        SELECT indexname, indexdef FROM pg_indexes
        WHERE schemaname = %s AND tablename = %s ORDER BY indexname
    """, (schema, mvname))
    ddls = []
    for iname, idef in cur.fetchall():
        idef = idef.replace('CREATE INDEX ', 'CREATE INDEX IF NOT EXISTS ', 1)
        idef = idef.replace('CREATE UNIQUE INDEX ', 'CREATE UNIQUE INDEX IF NOT EXISTS ', 1)
        ddls.append(idef + ';')
    return ddls


def get_functions(cur, schema):
    cur.execute("""
        SELECT p.proname, pg_get_functiondef(p.oid)
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = %s AND p.prokind IN ('f','p')
        ORDER BY p.proname
    """, (schema,))
    return cur.fetchall()


def get_tablespaces(cur):
    cur.execute("""
        SELECT spcname FROM pg_tablespace
        WHERE spcname NOT IN ('pg_default','pg_global')
        ORDER BY spcname
    """)
    return [r[0] for r in cur.fetchall()]


def main():
    parser = argparse.ArgumentParser(
        description="Extract DDL for DAR Portal database objects"
    )
    parser.add_argument('--output', '-o',
        default='schema/awr_portal_full_schema_extracted_from_database.sql',
        help='Output SQL file')
    parser.add_argument('--schema', '-s', default='public',
        help='PostgreSQL schema (default: public)')
    parser.add_argument('--no-functions', action='store_true',
        help='Skip function/procedure DDL')
    parser.add_argument('--include-all', action='store_true',
        help='Include ALL tables (disable portal-only filter)')
    args = parser.parse_args()

    if args.include_all:
        # Bypass the whitelist — extract every object in the schema
        global is_portal_table
        is_portal_table = lambda name: True
        print("WARNING: --include-all set — extracting ALL objects in schema")

    print("Connecting to database...")
    try:
        conn = get_db_connection()
        conn.autocommit = True
        cur = conn.cursor()
        print("Connected ✓")
    except Exception as e:
        print(f"Connection failed: {e}")
        sys.exit(1)

    schema = args.schema
    output = os.path.join(_PROJECT_ROOT, args.output)
    os.makedirs(os.path.dirname(output), exist_ok=True)
    lines = []

    lines.append(HEADER.format(
        timestamp=datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        output=os.path.basename(output)
    ))

    # ── Tablespaces ──────────────────────────────────────────────────────────
    tablespaces = get_tablespaces(cur)
    if tablespaces:
        lines.append(SECTION.format(title="TABLESPACES"))
        lines.append("-- Edit LOCATION paths before running on a new server.")
        lines.append("-- Directories must exist first (mkdir).\n")
        for ts in tablespaces:
            lines.append(f"-- CREATE TABLESPACE {ts}")
            lines.append(f"--     LOCATION '/path/to/tablespaces/{ts}';")
            lines.append(f"-- (Uncomment and edit the path above)\n")

    # ── Custom types / enums ─────────────────────────────────────────────────
    types = get_types(cur, schema)
    if types:
        lines.append(SECTION.format(title="CUSTOM TYPES / ENUMS"))
        for tname, ttype, labels in types:
            if ttype == 'e' and labels:
                label_list = ", ".join(f"'{l}'" for l in labels)
                lines.append(f"CREATE TYPE {tname} AS ENUM ({label_list});\n")

    # ── Tables ───────────────────────────────────────────────────────────────
    tables = get_tables(cur, schema)
    lines.append(SECTION.format(title=f"TABLES ({len(tables)} portal tables)"))
    print(f"Extracting {len(tables)} portal tables...")

    all_indexes = []
    for tname in tables:
        try:
            lines.append(f"-- Table: {tname}")
            ddl = get_table_ddl(cur, schema, tname)
            lines.append(ddl)
            idx = get_indexes(cur, schema, tname)
            if idx:
                all_indexes.extend(idx)
                all_indexes.append("")
        except Exception as e:
            lines.append(f"-- ERROR extracting {tname}: {e}\n")
            print(f"  WARNING: {tname}: {e}")

    # ── Indexes ──────────────────────────────────────────────────────────────
    if all_indexes:
        lines.append(SECTION.format(title=f"INDEXES ({len([i for i in all_indexes if i.strip()])} indexes)"))
        lines.extend(all_indexes)

    # ── Views ────────────────────────────────────────────────────────────────
    views = get_views(cur, schema)
    if views:
        lines.append(SECTION.format(title=f"VIEWS ({len(views)} portal views)"))
        print(f"Extracting {len(views)} portal views...")
        for vname, vdef in views:
            if vdef:
                lines.append(f"-- View: {vname}")
                lines.append(f"CREATE OR REPLACE VIEW {vname} AS\n{vdef.rstrip()};\n")

    # ── Materialized Views ───────────────────────────────────────────────────
    mvs = get_materialized_views(cur, schema)
    if mvs:
        lines.append(SECTION.format(title=f"MATERIALIZED VIEWS ({len(mvs)} portal MVs)"))
        print(f"Extracting {len(mvs)} portal materialized views...")
        mv_indexes = []
        for mvname, mvdef, populated in mvs:
            if mvdef:
                lines.append(f"-- Materialized View: {mvname}")
                lines.append(
                    f"CREATE MATERIALIZED VIEW IF NOT EXISTS {mvname} AS\n"
                    f"{mvdef.rstrip()}\nWITH {'DATA' if populated else 'NO DATA'};\n"
                )
                idx = get_mv_indexes(cur, schema, mvname)
                if idx:
                    mv_indexes.extend(idx)
                    mv_indexes.append("")

        if mv_indexes:
            lines.append(SECTION.format(title="MATERIALIZED VIEW INDEXES"))
            lines.extend(mv_indexes)

        lines.append(SECTION.format(title="REFRESH MATERIALIZED VIEWS"))
        lines.append("-- Run after initial data load to populate all MVs:")
        for mvname, _, _ in mvs:
            lines.append(f"REFRESH MATERIALIZED VIEW CONCURRENTLY {mvname};")
        lines.append("")

    # ── Functions / Procedures ───────────────────────────────────────────────
    funcs = []
    if not args.no_functions:
        funcs = get_functions(cur, schema)
        if funcs:
            lines.append(SECTION.format(
                title=f"FUNCTIONS & PROCEDURES ({len(funcs)} total)"
            ))
            print(f"Extracting {len(funcs)} functions...")
            for fname, fdef in funcs:
                if fdef:
                    lines.append(f"-- Function: {fname}")
                    lines.append(f"CREATE OR REPLACE {fdef.strip()};\n")

    # ── Permissions ──────────────────────────────────────────────────────────
    lines.append(SECTION.format(title="PERMISSIONS"))
    lines.append("""\
-- Tablespace grants: REQUIRED so DAR_PORTAL_USER can create tables
-- in the awrparser and awrparser_idx tablespaces.
-- Without these grants CREATE TABLE ... TABLESPACE awrparser returns:
--   ERROR: permission denied for tablespace awrparser
GRANT CREATE ON TABLESPACE awrparser     TO DAR_PORTAL_USER;
GRANT CREATE ON TABLESPACE awrparser_idx TO DAR_PORTAL_USER;

-- Table, sequence and MV object grants:
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
        EXECUTE format('GRANT SELECT,INSERT,UPDATE,DELETE ON TABLE public.%I TO DAR_PORTAL_USER', r.tablename);
    END LOOP;
    FOR r IN SELECT sequencename FROM pg_sequences WHERE schemaname = 'public' LOOP
        EXECUTE format('GRANT USAGE,SELECT ON SEQUENCE public.%I TO DAR_PORTAL_USER', r.sequencename);
    END LOOP;
    FOR r IN SELECT matviewname FROM pg_matviews WHERE schemaname = 'public' LOOP
        EXECUTE format('GRANT SELECT ON TABLE public.%I TO DAR_PORTAL_USER', r.matviewname);
    END LOOP;
END $$;
""")

    # ── Footer ───────────────────────────────────────────────────────────────
    idx_count = len([i for i in all_indexes if i.strip()])
    func_count = len(funcs) if not args.no_functions else 'skipped'
    lines.append(f"""\
-- ============================================================
-- END OF SCHEMA SCRIPT
-- Tables:              {len(tables)}
-- Views:               {len(views)}
-- Materialized Views:  {len(mvs)}
-- Indexes:             {idx_count}
-- Functions:           {func_count}
-- Generated:           {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
-- ============================================================
""")

    content = '\n'.join(lines)
    with open(output, 'w', encoding='utf-8') as f:
        f.write(content)

    cur.close()
    conn.close()

    print(f"\n✅  DDL extracted successfully:")
    print(f"    Tables:              {len(tables)}")
    print(f"    Views:               {len(views)}")
    print(f"    Materialized Views:  {len(mvs)}")
    print(f"    Indexes:             {idx_count}")
    if not args.no_functions:
        print(f"    Functions:           {len(funcs)}")
    print(f"\n    Output: {output}")
    print(f"\nTo recreate schema:")
    print(f"    psql -U postgres -d postgres -f {args.output}")

    # ── Quick constraint sanity check ────────────────────────────────────────
    print(f"\nConstraint sanity check (verify no duplicate column names in PKs):")
    cur2 = conn.cursor() if not conn.closed else get_db_connection().cursor()
    try:
        cur2.execute("""
            SELECT tc.table_name, tc.constraint_name,
                   array_agg(kcu.column_name ORDER BY kcu.ordinal_position) AS cols,
                   count(kcu.column_name) AS col_count
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON  kcu.constraint_name = tc.constraint_name
                AND kcu.table_schema    = tc.table_schema
                AND kcu.table_name      = tc.table_name
            WHERE tc.table_schema   = %s
              AND tc.constraint_type IN ('PRIMARY KEY','UNIQUE')
            GROUP BY tc.table_name, tc.constraint_name
            HAVING count(kcu.column_name) != count(DISTINCT kcu.column_name)
        """, (schema,))
        dups = cur2.fetchall()
        if dups:
            print("  WARNING — duplicate columns found in these constraints:")
            for tname, cname, cols, cnt in dups:
                print(f"    {tname}.{cname}: {cols} (count={cnt})")
        else:
            print("  OK — no duplicate constraint columns found.")
    except Exception:
        pass


if __name__ == "__main__":
    main()
