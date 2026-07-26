#!/usr/bin/env python3
"""
extract_ddl.py
==============
Extracts complete DDL for all portal objects from the live PostgreSQL database
and writes them to a single consolidated SQL file.

Objects extracted (in dependency order):
  - Tables (with constraints)
  - Indexes
  - Views
  - Materialized Views
  - Sequences

Usage:
  py extract_ddl.py
  py extract_ddl.py --out schema/awr_portal_live_schema.sql
  py extract_ddl.py --schema public --out my_ddl.sql

Output file can be used to:
  - Replace the schema folder scripts with the currently deployed DDL
  - Recreate the database on a new server
  - Review and validate the deployed DDL against the source scripts
"""

import os
import sys
import argparse
import datetime

_PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))

def _load_settings() -> dict:
    try:
        import yaml
        with open(os.path.join(_PROJECT_ROOT, 'config', 'settings.yaml'),
                  encoding='utf-8') as f:
            return yaml.safe_load(f) or {}
    except Exception:
        return {}

def get_connection():
    cfg = _load_settings().get('database', {})
    import psycopg2
    return psycopg2.connect(
        host     = cfg.get('host',     'localhost'),
        port     = cfg.get('port',     5432),
        dbname   = cfg.get('dbname',   'postgres'),
        user     = cfg.get('user',     'postgres'),
        password = cfg.get('password', ''),
    )

def extract_ddl(schema: str = 'public', out_path: str = None) -> str:
    conn = get_connection()
    cur  = conn.cursor()
    lines = []

    header = f"""-- ============================================================
-- AWR Insight Portal — Live Database DDL Extract
-- Generated: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
-- Schema:    {schema}
-- ============================================================
-- This file was extracted from the live PostgreSQL database.
-- Use this as the authoritative DDL reference.
--
-- Object order:
--   1. Sequences
--   2. Tables (with inline constraints)
--   3. Indexes
--   4. Views
--   5. Materialized Views
--   6. Grants (select privileges on MVs)
-- ============================================================

SET search_path = {schema};
SET client_min_messages = WARNING;

"""
    lines.append(header)

    # ── 1. Sequences ─────────────────────────────────────────────────────────
    cur.execute("""
        SELECT sequence_name
        FROM information_schema.sequences
        WHERE sequence_schema = %s
        ORDER BY sequence_name
    """, (schema,))
    seqs = cur.fetchall()

    if seqs:
        lines.append('-- ============================================================\n')
        lines.append('-- SEQUENCES\n')
        lines.append('-- ============================================================\n\n')
        for (seq_name,) in seqs:
            cur.execute("""
                SELECT start_value, minimum_value, maximum_value,
                       increment, cycle_option, cache_size
                FROM information_schema.sequences
                WHERE sequence_schema = %s AND sequence_name = %s
            """, (schema, seq_name))
            row = cur.fetchone()
            if row:
                start, minv, maxv, inc, cycle, cache = row
                cycle_sql = 'CYCLE' if cycle == 'YES' else 'NO CYCLE'
                lines.append(
                    f'CREATE SEQUENCE IF NOT EXISTS {seq_name}\n'
                    f'    START WITH {start}\n'
                    f'    INCREMENT BY {inc}\n'
                    f'    MINVALUE {minv}\n'
                    f'    MAXVALUE {maxv}\n'
                    f'    CACHE {cache}\n'
                    f'    {cycle_sql};\n\n'
                )

    # ── 2. Tables ─────────────────────────────────────────────────────────────
    cur.execute("""
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = %s AND table_type = 'BASE TABLE'
        ORDER BY table_name
    """, (schema,))
    tables = [r[0] for r in cur.fetchall()]

    lines.append('-- ============================================================\n')
    lines.append(f'-- TABLES ({len(tables)} tables)\n')
    lines.append('-- ============================================================\n\n')

    for tbl in tables:
        # Get columns
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
        """, (schema, tbl))
        cols = cur.fetchall()

        # Get constraints
        cur.execute("""
            SELECT
                tc.constraint_name,
                tc.constraint_type,
                kcu.column_name,
                cc.check_clause,
                ccu.table_name AS ref_table,
                ccu.column_name AS ref_col
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
                AND tc.table_schema = kcu.table_schema
            LEFT JOIN information_schema.check_constraints cc
                ON tc.constraint_name = cc.constraint_name
            LEFT JOIN information_schema.constraint_column_usage ccu
                ON tc.constraint_name = ccu.constraint_name
                AND tc.constraint_type = 'FOREIGN KEY'
            WHERE tc.table_schema = %s AND tc.table_name = %s
            ORDER BY tc.constraint_type, tc.constraint_name, kcu.ordinal_position
        """, (schema, tbl))
        constraints = cur.fetchall()

        # Get tablespace
        cur.execute("""
            SELECT spcname
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            LEFT JOIN pg_tablespace t ON t.oid = c.reltablespace
            WHERE n.nspname = %s AND c.relname = %s AND c.relkind = 'r'
        """, (schema, tbl))
        ts_row = cur.fetchone()
        tablespace = ts_row[0] if ts_row and ts_row[0] else None

        col_defs = []
        for col_name, data_type, char_max, num_prec, num_scale, nullable, default, udt in cols:
            # Build type string
            if data_type == 'character varying':
                type_str = f'VARCHAR({char_max})' if char_max else 'TEXT'
            elif data_type == 'character':
                type_str = f'CHAR({char_max})' if char_max else 'CHAR'
            elif data_type == 'numeric':
                if num_prec and num_scale:
                    type_str = f'NUMERIC({num_prec},{num_scale})'
                elif num_prec:
                    type_str = f'NUMERIC({num_prec})'
                else:
                    type_str = 'NUMERIC'
            elif data_type == 'integer':
                type_str = 'INT'
            elif data_type == 'bigint':
                type_str = 'BIGINT'
            elif data_type == 'smallint':
                type_str = 'SMALLINT'
            elif data_type == 'timestamp without time zone':
                type_str = 'TIMESTAMP'
            elif data_type == 'timestamp with time zone':
                type_str = 'TIMESTAMPTZ'
            elif data_type == 'boolean':
                type_str = 'BOOLEAN'
            elif data_type == 'text':
                type_str = 'TEXT'
            elif data_type == 'USER-DEFINED':
                type_str = udt.upper()
            else:
                type_str = data_type.upper()

            null_str = '' if nullable == 'YES' else ' NOT NULL'
            # Clean up default
            if default:
                # Replace nextval with SERIAL hint in comment
                if 'nextval' in default:
                    default_str = f' DEFAULT {default}'
                else:
                    default_str = f' DEFAULT {default}'
            else:
                default_str = ''

            col_defs.append(f'    {col_name} {type_str}{null_str}{default_str}')

        # Add constraints
        seen_constraints = set()
        constraint_defs = []
        pk_cols = []
        unique_constraints = {}
        check_constraints = {}
        fk_constraints = {}

        for cname, ctype, col, check_clause, ref_table, ref_col in constraints:
            if ctype == 'PRIMARY KEY':
                pk_cols.append(col)
            elif ctype == 'UNIQUE':
                if cname not in unique_constraints:
                    unique_constraints[cname] = []
                unique_constraints[cname].append(col)
            elif ctype == 'CHECK' and cname not in seen_constraints:
                seen_constraints.add(cname)
                if check_clause and 'IS NOT NULL' not in check_clause:
                    check_constraints[cname] = check_clause
            elif ctype == 'FOREIGN KEY' and cname not in seen_constraints:
                seen_constraints.add(cname)
                fk_constraints[cname] = (col, ref_table, ref_col)

        if pk_cols:
            constraint_defs.append(
                f'    CONSTRAINT pk_{tbl} PRIMARY KEY ({", ".join(pk_cols)})'
            )
        for cname, ucols in unique_constraints.items():
            constraint_defs.append(
                f'    CONSTRAINT {cname} UNIQUE ({", ".join(ucols)})'
            )
        for cname, clause in check_constraints.items():
            constraint_defs.append(f'    CONSTRAINT {cname} CHECK ({clause})')
        for cname, (col, ref_tbl, ref_col) in fk_constraints.items():
            constraint_defs.append(
                f'    CONSTRAINT {cname} FOREIGN KEY ({col}) REFERENCES {ref_tbl}({ref_col})'
            )

        all_defs = col_defs + constraint_defs
        ts_clause = f'\nTABLESPACE {tablespace}' if tablespace and tablespace != 'pg_default' else ''
        lines.append(f'CREATE TABLE IF NOT EXISTS {tbl} (\n')
        lines.append(',\n'.join(all_defs) + '\n')
        lines.append(f'){ts_clause};\n\n')

    # ── 3. Indexes ────────────────────────────────────────────────────────────
    cur.execute("""
        SELECT
            i.relname AS index_name,
            t.relname AS table_name,
            ix.indisunique,
            ix.indisprimary,
            pg_get_indexdef(ix.indexrelid) AS index_def
        FROM pg_index ix
        JOIN pg_class i ON i.oid = ix.indexrelid
        JOIN pg_class t ON t.oid = ix.indrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE n.nspname = %s
          AND NOT ix.indisprimary
          AND t.relkind IN ('r', 'm')
        ORDER BY t.relname, i.relname
    """, (schema,))
    indexes = cur.fetchall()

    if indexes:
        lines.append('-- ============================================================\n')
        lines.append(f'-- INDEXES ({len(indexes)} indexes)\n')
        lines.append('-- ============================================================\n\n')
        for idx_name, tbl_name, is_unique, is_pk, idx_def in indexes:
            # Convert to IF NOT EXISTS style
            idx_ddl = idx_def
            if idx_ddl.startswith('CREATE INDEX'):
                idx_ddl = idx_ddl.replace('CREATE INDEX', 'CREATE INDEX IF NOT EXISTS', 1)
            elif idx_ddl.startswith('CREATE UNIQUE INDEX'):
                idx_ddl = idx_ddl.replace('CREATE UNIQUE INDEX', 'CREATE UNIQUE INDEX IF NOT EXISTS', 1)
            lines.append(f'{idx_ddl};\n\n')

    # ── 4. Views ─────────────────────────────────────────────────────────────
    cur.execute("""
        SELECT table_name, view_definition
        FROM information_schema.views
        WHERE table_schema = %s
        ORDER BY table_name
    """, (schema,))
    views = cur.fetchall()

    if views:
        lines.append('-- ============================================================\n')
        lines.append(f'-- VIEWS ({len(views)} views)\n')
        lines.append('-- ============================================================\n\n')
        for vname, vdef in views:
            lines.append(f'CREATE OR REPLACE VIEW {vname} AS\n{vdef};\n\n')

    # ── 5. Materialized Views ─────────────────────────────────────────────────
    cur.execute("""
        SELECT
            c.relname AS mv_name,
            pg_get_viewdef(c.oid) AS mv_def,
            t.spcname AS tablespace_name
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        LEFT JOIN pg_tablespace t ON t.oid = c.reltablespace
        WHERE n.nspname = %s AND c.relkind = 'm'
        ORDER BY c.relname
    """, (schema,))
    mvs = cur.fetchall()

    if mvs:
        lines.append('-- ============================================================\n')
        lines.append(f'-- MATERIALIZED VIEWS ({len(mvs)} MVs)\n')
        lines.append('-- ============================================================\n\n')
        for mv_name, mv_def, mv_ts in mvs:
            ts_clause = f'\nTABLESPACE {mv_ts}' if mv_ts and mv_ts != 'pg_default' else ''
            lines.append(
                f'CREATE MATERIALIZED VIEW IF NOT EXISTS {mv_name}{ts_clause}\nAS\n{mv_def}\nWITH DATA;\n\n'
            )

    # ── 6. Grants ─────────────────────────────────────────────────────────────
    cur.execute("""
        SELECT
            grantee,
            table_name,
            string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privileges
        FROM information_schema.role_table_grants
        WHERE table_schema = %s
          AND grantee NOT IN ('PUBLIC', 'postgres')
        GROUP BY grantee, table_name
        ORDER BY table_name, grantee
    """, (schema,))
    grants = cur.fetchall()

    if grants:
        lines.append('-- ============================================================\n')
        lines.append('-- GRANTS\n')
        lines.append('-- ============================================================\n\n')
        for grantee, tbl_name, privs in grants:
            lines.append(f'GRANT {privs} ON {tbl_name} TO {grantee};\n')

    cur.close()
    conn.close()

    ddl = ''.join(lines)

    if out_path:
        os.makedirs(os.path.dirname(out_path) if os.path.dirname(out_path) else '.', exist_ok=True)
        with open(out_path, 'w', encoding='utf-8') as f:
            f.write(ddl)
        print(f'DDL written to: {out_path}')
        print(f'Tables: {len(tables)}, Indexes: {len(indexes)}, '
              f'Views: {len(views)}, MVs: {len(mvs)}, Sequences: {len(seqs)}')

    return ddl


def main():
    parser = argparse.ArgumentParser(
        description='Extract live DDL from the AWR Portal database'
    )
    parser.add_argument('--out', default='schema/awr_portal_live_schema.sql',
                        help='Output file path (default: schema/awr_portal_live_schema.sql)')
    parser.add_argument('--schema', default='public',
                        help='PostgreSQL schema to extract (default: public)')
    args = parser.parse_args()

    print(f'Extracting DDL from live database...')
    extract_ddl(schema=args.schema, out_path=args.out)


if __name__ == '__main__':
    main()
