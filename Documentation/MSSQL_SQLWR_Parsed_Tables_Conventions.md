# MS SQL Server SQLWR parsed tables — conventions

Applies to the `mssql_sqlwr_*` section tables filled by the `modules/mssql/sqlwr_*_parser.py`
parsers from generated SQLWR reports. Everything below was checked against the report generator
(`sqlwr_report_generator.py`), the parsers, and real reports; where it describes a limitation it
says so.

## 1. Keys — what identifies a row

Every parsed table carries the same core columns:

| Column | Meaning |
|---|---|
| `database_name` | The report-level database (from the report's Database Summary). |
| `instance_id` | The SQL Server instance (`mssql_instance_master.id`). |
| `snapshot_time` | The time of the report's **END** snapshot (full precision, incl. microseconds). |
| `begin_snapshot_id` | **The report's key.** A report is `begin -> end`; all its rows share this value. |
| `row_hash` | Hash of the row's parsed values. Unique together with `(database_name, instance_id, begin_snapshot_id)`; this is what makes re-parsing the same report insert nothing new. |

Sections that list objects also have their own database column (`io_database_name`,
`seg_database_name`, `blocked_database_name`) — that is the row's own database, not the report's.

Dashboards analyse a report by `begin_snapshot_id`. There is deliberately no `end_snapshot_id`
column; see section 4 for how to reach the end snapshot.

## 2. Three kinds of time semantics

The section decides what the numbers mean. `begin_snapshot_id` is the same in all three; what
differs is *what was observed*.

**A. Read at the END snapshot only (point-in-time — not a delta, not a window).**
The values describe the server at the instant of the end snapshot. They say nothing about the
period between begin and end.

| Report section | Table(s) |
|---|---|
| Instance Efficiency Percentages | `mssql_sqlwr_instance_efficiency` |
| Memory Statistics | `mssql_sqlwr_memory_stats` |
| Blocking Summary (at End Snapshot) | `mssql_sqlwr_blocking_summary` |
| Plan Cache Health | `mssql_sqlwr_plan_cache_summary`, `mssql_sqlwr_plan_cache_detail` |
| TempDB Usage | `mssql_sqlwr_tempdb_sessions`, `mssql_sqlwr_tempdb_tasks` |

These seven tables carry a `POINT-IN-TIME` note in their `COMMENT ON TABLE`.

Consequence worth knowing when inspecting data by hand: the raw sample for a report `73 -> 74` is
stored in `mssql_blocking_snapshot` (etc.) under `snapshot_id = 74`, while the parsed row carries
`begin_snapshot_id = 73`. So a blocked session seen at snapshot 74 appears in report `73 -> 74`,
**not** in `74 -> 75` (whose end snapshot is 75). An empty Blocking Summary for a report therefore
means "nothing was blocked at its end snapshot", not "nothing was blocked during the window".

**B. Time window.** Rows are taken from data stamped with a time and filtered to the window
`begin snapshot time .. end snapshot time`: CPU Utilization and Deadlock Summary; and the sections
built from Query Store, which use the Query Store intervals overlapping the window — Wait Events by
Stored Procedure, the four `SQL ordered by ...` sections, and Complete List of SQL Text.

**C. Delta between the begin and end snapshots.** Cumulative counters are differenced: Load Profile,
Wait Classes, Top Wait Types, IO Profile, IO Stalls by File Type and the six `Top Objects by ...`
sections. In the `Top Objects by ...` sections a counter reset between the two snapshots (SQL Server
clears an index's counters when its metadata leaves the cache) is floored at zero rather than shown
as a negative number.

## 3. Sections that are empty by design

Not every empty section is a problem. There are two shapes:

* **Placeholder row** — a single row whose first cell starts with `(`, e.g.
  `(no blocking observed at end-snapshot time)`. Used by most sections.
* **Header only** — a table with a header row and no data rows. This is how the four
  `SQL ordered by ...` sections render when there is no Query Store data (some older reports rendered
  those sections this way too).

Both are normal: the parser logs INFO and inserts nothing.

**Two sections contain two tables**, each with its own placeholder, and each has its own parser and
table: *Plan Cache Health* (summary -> `mssql_sqlwr_plan_cache_summary`, top cached plans ->
`mssql_sqlwr_plan_cache_detail`) and *TempDB Usage* (sessions -> `mssql_sqlwr_tempdb_sessions`,
tasks -> `mssql_sqlwr_tempdb_tasks`). They are classified independently: report `1_70_71` has an empty
plan cache summary next to a full detail table. The TempDB tasks table is empty in every report seen
so far, because it only lists tasks that happen to be allocating TempDB at the end-snapshot instant. A section that is missing from the report
altogether (an older report that predates it) logs a WARNING and inserts nothing.

## 4. Getting from a parsed row back to the raw data

`begin_snapshot_id + 1` is **not** a safe way to find the end snapshot: it fails for a report that
spans more than one snapshot. Use `snapshot_time`, which is the end snapshot's exact time:

```sql
SELECT p.begin_snapshot_id,
       s.snapshot_id AS end_snapshot_id,
       p.session_id, p.blocked_by, p.wait_time_s,
       b.wait_resource, b.blocked_statement_text
FROM mssql_sqlwr_blocking_summary p
JOIN mssql_dmv_snapshot s
  ON s.instance_id = p.instance_id AND s.snapshot_time = p.snapshot_time
JOIN mssql_blocking_snapshot b
  ON b.snapshot_id = s.snapshot_id
 AND b.session_id = p.session_id AND b.blocking_session_id = p.blocked_by;
```

The same join through `mssql_dmv_snapshot` reaches the end snapshot for any parsed table.

## 5. The SQL sections (`SQL ordered by ...` and `Complete List of SQL Text`)

* **`sql_id` is Query Store's `query_id`, as text.** Reports generated before the cosmetic `q` prefix
  was dropped carry `q39`; current ones carry `39`. Parsers normalize to `39`, so one query has one id
  regardless of report age (`normalize_sql_id` in `sqlwr_parser_utils.py`).
* **Each of the four sections takes its own top 15 from a larger pool of queries**, so a query can be
  in one section and not another (seen in report `1_74_75`: a pool of 18 queries). Do not assume every
  `sql_id` appears in all four tables. `Complete List of SQL Text` covers every query referenced in the
  four sections.
* **Full text lives only in `mssql_sqlwr_sql_text`**, joined on `(begin_snapshot_id, sql_id)`. The
  ordered-by sections show a 30-character preview which the parsers do not store. The text is read
  from the raw HTML cell, because pandas collapses whitespace and a `--` comment would then swallow the
  rest of a statement.
* **`stored_procedure`** holds the literal `(ad hoc / no object)` for statements that belong to no
  stored procedure. Treat that literal as "none", not as a procedure name.
* **`%Total` is a share of the queries fetched for the report, not of all SQL activity in the
  window.** The generator divides by the sum over that fetched pool. Within a report whose pool is 15
  or fewer, the shown rows therefore always sum to 100. (Current behaviour; not yet changed.)
* **`%CPU` can exceed 100.** CPU time is summed across the workers of a parallel plan.
* **`SQL ordered by Gets`, `Elapsed Time (s)` column:** reports generated before the generator fix
  carry a percentage in this column. The Gets parser detects that format and takes the correct
  seconds from the report's Elapsed Time, CPU Time and Executions sections. Current reports are stored
  as shown.

## 6. Sentinel and special values stored exactly as the report shows them

| Where | Value | Meaning |
|---|---|---|
| Memory Statistics | `2147483647` (and a near-equal "Free within Allocated") | `max_server_memory` is at SQL Server's unlimited default — not megabytes. |
| Top Objects sections | index name `(heap)` | The table is a heap. |
| SQL sections | stored procedure `(ad hoc / no object)` | Not in a stored procedure. |
| Wait Events by Stored Procedure | no row for a zero cell | The report rounds to 0.1 s, so 0.0 cannot separate "none" from "under 0.05 s". `executions` repeats on each category row of a procedure: never sum it across the table. |

## 7. Re-parsing

Idempotency is keyed on a hash of the parsed values. Re-running the same report with the same parser
inserts nothing. If a parser is changed so that a value it produces changes, re-running an already
loaded report **adds a second set of rows**; delete that report's rows (by `begin_snapshot_id`)
first.

## 8. Things that look like ids but are not, and a known upstream limit

* **`query_hash` (plan cache detail) is not `sql_id`.** `mssql_sqlwr_plan_cache_detail.query_hash` is the
  plan cache's hash of the statement text (16 hex characters, stored as text — it can be all digits or start
  with zeros). `sql_id` in the `SQL ordered by ...` tables is Query Store's `query_id`. They are different
  identifiers and do not join. Several cached plans can share one `query_hash`.
* **TempDB sessions are cumulative; `session_id` is only unique within a report.** The figures are the
  session's allocations over its whole lifetime, and SQL Server reuses a session id after a disconnect.
* **Parallel requests are understated in `mssql_sqlwr_tempdb_tasks`.** `sys.dm_db_task_space_usage` returns one
  row per *task* (per `exec_context_id`); a parallel query runs several tasks under the same session and request.
  The collector keeps one row per (snapshot, session, request) — the first task it sees — and discards the
  rest, so a parallel request's Allocated/Deallocated shows one worker's share, not the request's total (shown
  on the database: three 8 MB workers in, one 8 MB row stored, true total 24 MB). Treat those numbers as a
  lower bound for parallel requests until the collector sums per (session, request).

## 9. Database Summary (whole-report summary, added after the 26 section parsers)

`mssql_sqlwr_database_summary` (one row per report, parsed first by the master parser --
see section 10) extends the report's Database Summary section to carry the same
information an Oracle AWR report's own Database Summary screen shows: DB Name, DB Id,
Unique Name, Role, Edition, Release, RAC, CDB, Instance, Inst Num, Startup Time, Host
Name, Platform, CPUs, Cores, Sockets, Memory (GB) -- plus Sessions/Elapsed/DB Time from
the Snapshot Summary table. Field-by-field reasoning, including which fields are always
'N/A' (RAC, CDB -- Oracle-only concepts) or always NULL (Inst Num, cursors_per_session --
no SQL Server equivalent), is in that table's own `COMMENT ON TABLE`
(schema/mssql_sqlwr_section_tables.sql) and the parser's module docstring
(sqlwr_database_summary_parser.py). `elapsed_minutes` is computed directly from
begin/end snap time (always available) rather than parsed from the report's own
"Elapsed:" text, so it is populated even for reports generated before that row existed;
`db_time_minutes` has no such fallback and is NULL for those older reports, since DB Time
is an approximation the report computes, not something the parser can honestly re-derive
without duplicating that logic.

Five of its fields (`database_id`, `socket_count`/`sockets`, `cores_per_socket`/`cores`,
`host_platform`, `host_distribution`/part of `platform`) depend on 5 new columns added to
`mssql_config_snapshot` (schema/mssql_config_snapshot_host_extend.sql) and 5 new T-SQL
SELECT expressions added to the collector's `_collect_config()`. Unlike everything else in
this document, that specific collector addition has only been schema/parser-tested against
constructed data, not run against a live SQL Server -- see the NOTE in
`_collect_config()`'s own docstring.

KNOWN PRE-EXISTING ISSUE (not introduced by the database-summary work, found while testing
it more thoroughly than prior sections were): on `sqlwr_1_7_8.html` -- the one uploaded
report whose Database Summary table has no "DB Name" column at all (an older report
format) -- `extract_workload_repo_metadata()`'s positional fallback (common/utils.py) reads
column 0 of that table ("Host Name") as if it were the database name, so `database_name`
comes back as the HOST name for every parsed table on that one report, not just
`mssql_sqlwr_database_summary`. Confirmed this is pre-existing and not specific to today's
work: `mssql_sqlwr_load_profile` and `mssql_sqlwr_wait_classes` (already-shipped parsers)
show the identical wrong value for the same report. Left unfixed -- it is shared code also
used by the Oracle side, out of scope to change as a side effect of the MSSQL database
summary task; flagged for a decision on whether/how to fix it.

## 10. Master parser

`modules/mssql/mssql_master_parser.py` runs all 27 parsers (the 26 section parsers plus
Database Summary) against one report, Database Summary first, then the rest in the
report's own top-to-bottom order. One parser failing does not stop the others -- every
call is individually try/excepted and logged; the run's overall exit code reflects
whether any parser failed. A single shared connection is opened once and passed to every
parser's `parse_X()` call (each accepts `pg_conn=None` for exactly this reason); the
insert side still opens its own short-lived connection per table via the shared
`insert_records()`, unchanged. It does not refresh the wait/SQL/segment summary
materialized views -- they still source from raw collector tables, not from these parsed
tables (a separate, later roadmap step), and the collector scheduler already refreshes
them once per cycle.

    py modules\\mssql\\mssql_master_parser.py "C:\\...\\sqlwr_reports\\MYDB\\sqlwr_1_75_76.html" --archive
    py modules\\mssql\\mssql_master_parser.py --dir "C:\\...\\sqlwr_reports" --archive
    py modules\\mssql\\mssql_master_parser.py --cleanup-archive

## 11. Report file layout, archiving, retention

`sqlwr_report_generator.py`'s `auto_generate_sqlwr_reports()` (called after each collection
cycle by `mssql_collector_scheduler.py`) writes each report into a subfolder named after
the report's OWN database, resolved the same way the Database Summary section itself is
(`_resolve_report_db_name()`, factored out so both call the same logic without a second
DB round-trip inside `generate_sqlwr_report()` itself):

    sqlwr_reports/<DB_NAME>/sqlwr_<instance_id>_<begin_snap>_<end_snap>.html

A window with no Query Store activity at all goes in `sqlwr_reports/UNKNOWN_DB/`; a
report whose window spans more than one database (the `db_name_for_summary` comma-joined
fallback) goes in `sqlwr_reports/_multiple_databases/` rather than a folder named after
that joined string. `_safe_folder_name()` also strips characters Windows forbids in a
folder name and prefixes a name that collides with a Windows reserved device name (CON,
PRN, AUX, NUL, COM1-9, LPT1-9) with an underscore.

`mssql_master_parser.py --archive` moves a report to `sqlwr_archive/<DB_NAME>/` once every
parser has run against it (regardless of whether any of them failed), where `<DB_NAME>` is
read from the report's OWN metadata (`extract_sqlwr_metadata`) -- NOT from whichever
folder the file happened to be sitting in when the master parser was pointed at it, so
this is correct even for a report moved, renamed, or handed to the master parser directly
by path. A filename collision in the destination folder (re-archiving a same-named file)
gets a timestamp suffix rather than overwriting or erroring, e.g.
`sqlwr_1_75_76_20260930_093000.html`.

Retention: `mssql_master_parser.cleanup_sqlwr_archive()` deletes archived `.html` files
older than `portal.sqlwr_archive_retain_days` days (settings.yaml; default 7, same
convention as `awr_archive_retain_days`/`sar_archive_retain_days`/
`nmon_archive_retain_days`), checked recursively across every per-database subfolder in
one call. `mssql_collector_scheduler.py` calls it once per day from both of its
long-running loops (multi-instance `run_from_config()` and the single-instance CLI mode),
mirroring the `last_cleanup_date`-tracked daily-cleanup pattern the Oracle side's
`portal/app.py` already uses for its own AWR/SAR/NMON archives -- a separate, reusable
implementation (not imported from `portal/app.py`, which is a FastAPI app entrypoint, not
a library). It can also be run directly: `mssql_master_parser.py --cleanup-archive`.

Both new settings.yaml keys:

    paths:
      sqlwr_reports_directory:  "sqlwr_reports"   # <this>/<DB_NAME>/sqlwr_....html
      sqlwr_archive_directory:  "sqlwr_archive"    # <this>/<DB_NAME>/sqlwr_....html
    portal:
      sqlwr_archive_retain_days: 7

## 12. mssql_db_info -- the per-database identity registry (RECREATED split, per spec)

`mssql_sqlwr_database_summary` used to carry BOTH per-report facts (sessions, elapsed,
DB time) AND per-database identity facts (edition, host, cores, sockets, memory, AG
role/unique name, database_id) together, repeating the identity facts on every single
report row. Per spec, this was split into two tables:

* **`mssql_db_info`** (modeled on the Oracle side's `awr_db_info`/`db_info_parser.py`,
  table defined alongside `mssql_instance_master` in `schema/mssql_core_tables.sql` --
  standalone migration: `schema/mssql_db_info.sql`): identity facts, **one row per
  (instance, database), inserted ONCE from the first SQLWR report ever parsed for that
  database and never updated or duplicated again** -- a stricter rule than
  `awr_db_info`'s own (which allows a new row when content changes; `row_hash` is
  tracked but not part of the dedup key here, kept only for the project-wide
  convention and for audit). Parser: `mssql_db_info_parser.py`
  (`parse_db_info`/`insert_db_info`), runs FIRST in the master parser's `MODULE_ORDER`.
  `role` stores the report's literal `"N/A (standalone)"` as NULL (a registry should
  read "not applicable" as NULL, not carry report display text) -- confirmed on real
  data: a standalone instance stores `role IS NULL`, an AG-configured one stores the
  real role (e.g. `PRIMARY`). `source_type` defaults to `'local_file'` (mirroring
  `awr_db_info`); `repo_path` is this project's own choice (not populated by Oracle's
  own parser) -- the absolute path of the report that first registered the database.

* **`mssql_sqlwr_database_summary`** (RECREATED, slimmer -- migration:
  `schema/mssql_sqlwr_database_summary_recreate.sql`, **destructive**: drops and
  recreates the table, old rows are lost but recoverable by re-running the master
  parser against the report files still on disk): per-report facts only --
  `startup_time`, `begin_snap_id`/`begin_snapshot_id` (same value, two names: the
  first for symmetry with `end_snap_id`, the second for the report-key convention
  every other `mssql_sqlwr_*` table uses), `end_snap_id`, `end_snap_time` (same value
  as `snapshot_time`), `begin_sessions`/`end_sessions`, `cursors_per_sessions` (always
  NULL), `elapsed_minutes`, `db_time_minutes`. No `instance_id` column -- join back to
  `mssql_dmv_snapshot` on `begin_snap_id`/`end_snap_id` if the instance is ever needed.

Verified end to end on real data: parsing the same report twice registers
`mssql_db_info` once and skips on the second parse (`mssql_sqlwr_database_summary`
still inserts a fresh row each time it parses a NEW report, 0 on a repeat of the SAME
report, same idempotency as every other table); the same database name on two
DIFFERENT instances gets two separate `mssql_db_info` rows (dedup is scoped to
`instance_id` + `database_name`, not `database_name` alone); re-parsing a report whose
underlying config data had since changed still leaves the original `mssql_db_info` row
untouched (no update, no duplicate) -- the first report to see a database is the one
whose facts are kept, by design.
