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

Both are normal: the parser logs INFO and inserts nothing. A section that is missing from the report
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
