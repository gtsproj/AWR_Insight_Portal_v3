# modules/plan/plan_parser.py
# ============================================================
# Oracle Execution Plan Parser
# Supports DBMS_XPLAN.DISPLAY / DISPLAY_CURSOR output format
# Extracts: SQL ID, plan hash, steps, cost, rows, bytes,
#           predicates, notes, full scans, nested loops
# ============================================================

import re
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class PlanStep:
    step_id:    int
    operation:  str
    object_name: str = ""
    rows_est:   Optional[int] = None
    bytes_est:  Optional[int] = None
    cost:       Optional[float] = None
    time_est:   str = ""
    indent:     int = 0
    predicates: str = ""
    is_problem: bool = False
    problem_reason: str = ""


@dataclass
class ExecutionPlan:
    sql_id:      str = ""
    plan_hash:   str = ""
    sql_text:    str = ""
    plan_text:   str = ""
    steps:       list = field(default_factory=list)
    predicates:  dict = field(default_factory=dict)  # step_id -> predicate text
    notes:       list = field(default_factory=list)
    total_cost:  Optional[float] = None
    total_rows:  Optional[int] = None
    has_full_scan:   bool = False
    has_nested_loop: bool = False
    error:       str = ""


# ── Problem detection thresholds ─────────────────────────────────────
FULL_SCAN_OPS = {
    "TABLE ACCESS FULL",
    "FIXED TABLE FULL",
}
# INDEX FAST FULL SCAN is only a problem on large tables (flagged separately below)
INDEX_FULL_OPS = {"INDEX FAST FULL SCAN"}
NESTED_LOOP_OPS = {"NESTED LOOPS", "NESTED LOOPS OUTER"}
HIGH_COST_THRESHOLD = 10000   # flag steps with cost > this


def _parse_size(val: str) -> Optional[int]:
    """Parse K/M/G/T-suffixed numbers as Oracle's DBMS_XPLAN actually
    renders them: '26K' -> 26000, '129M' -> 129000000, '1.2G' -> 1200000000.

    BUG FIX (2026-08-31): the previous implementation only stripped the
    'K' suffix character and never applied any multiplier at all --
    '26K' parsed as 26, not 26000; 'M'/'G' suffixes weren't stripped at
    all, so the regex just grabbed the leading digits and silently
    discarded the multiplier; decimal values like '1.2G' lost everything
    after the decimal point since \\d+ doesn't match '.'. This fed
    directly into the >10000-row and >1000-row problem-detection
    thresholds below, causing real large-scan/large-nested-loop
    problems to go undetected whenever Oracle displayed the count with
    a K/M/G suffix -- which is the normal case for anything above a
    few hundred rows, not an edge case.
    """
    if not val or val.strip() in ("", "-"):
        return None
    val = val.strip().replace(",", "")
    m = re.match(r"([\d.]+)\s*([KMGT]?)$", val, re.IGNORECASE)
    if not m:
        return None
    number_part, suffix = m.group(1), m.group(2).upper()
    try:
        number = float(number_part)
    except ValueError:
        return None
    multiplier = {"": 1, "K": 1_000, "M": 1_000_000, "G": 1_000_000_000, "T": 1_000_000_000_000}[suffix]
    return int(number * multiplier)


def _parse_cost(val: str) -> Optional[float]:
    """Parse cost value, handling '(%CPU)' suffix: '26166' or '129K'."""
    if not val or val.strip() in ("", "-"):
        return None
    # Remove (%CPU) part
    val = re.sub(r"\(\d+\)", "", val).strip()
    val = val.replace(",", "")
    try:
        return float(val)
    except ValueError:
        return None


def _detect_problems(step: PlanStep) -> PlanStep:
    """Flag problematic operations."""
    op = step.operation.upper().strip("* ")

    reasons = []
    # TABLE ACCESS FULL and FIXED TABLE FULL always flagged
    for fso in FULL_SCAN_OPS:
        if fso in op:
            step.is_problem = True
            reasons.append(f"Full scan on {step.object_name or 'table'}")
            break

    # INDEX FAST FULL SCAN only flagged if large rows
    if any(ifo in op for ifo in INDEX_FULL_OPS):
        if step.rows_est and step.rows_est > 10000:
            step.is_problem = True
            reasons.append(f"Index fast full scan on large result ({step.rows_est:,} rows)")

    if any(nlo in op for nlo in NESTED_LOOP_OPS):
        if step.rows_est and step.rows_est > 1000:
            step.is_problem = True
            reasons.append(f"Nested loop on large result ({step.rows_est:,} rows)")

    if step.cost and step.cost > HIGH_COST_THRESHOLD:
        step.is_problem = True
        reasons.append(f"High cost ({step.cost:,.0f})")

    step.problem_reason = "; ".join(reasons)
    return step


def _fetch_object_metadata_map(dbname: str, object_names: list) -> dict:
    """
    Single query returning ALL awr_object_metadata rows for the given
    objects, keyed by UPPER(object_name) -> row dict. Both
    _fetch_plan_metadata_warnings (the existing stats/clustering/blevel
    warnings) and analyse_plan's scan-finding action text (added
    2026-08-31, see _build_scan_action) share this one fetch rather
    than each running their own query against the same table.
    """
    if not dbname or not object_names:
        return {}
    try:
        import sys as _sys, os as _os
        _sys.path.insert(0, _os.path.join(
            _os.path.abspath(_os.path.dirname(__file__)), "..", "..", "common"))
        from db import get_db_connection

        conn = get_db_connection()
        result = {}
        with conn.cursor() as cur:
            placeholders = ",".join(["%s"] * len(object_names))
            cur.execute(f"""
                SELECT object_name, object_type, num_rows, last_analyzed,
                       blevel, distinct_keys, clustering_factor,
                       index_columns, partition_type, uniqueness
                FROM awr_object_metadata
                WHERE dbname = %s
                  AND UPPER(object_name) IN ({placeholders})
            """, [dbname] + [o.upper() for o in object_names])
            for (obj_name, obj_type, num_rows, last_analyzed, blevel,
                 distinct_keys, clust_factor, idx_cols,
                 partition_type, uniqueness) in cur.fetchall():
                # An object name can have both a TABLE row and an INDEX
                # row (different object_type) -- keep whichever one has
                # richer info if both exist under the same name, but in
                # practice table/index names never collide in Oracle so
                # this just keeps the one match.
                result[obj_name.upper()] = {
                    "object_name": obj_name, "object_type": obj_type,
                    "num_rows": num_rows, "last_analyzed": last_analyzed,
                    "blevel": blevel, "distinct_keys": distinct_keys,
                    "clustering_factor": clust_factor, "index_columns": idx_cols,
                    "partition_type": partition_type, "uniqueness": uniqueness,
                }
        conn.close()
        return result
    except Exception as e:
        import logging
        logging.getLogger("plan_parser").debug(f"Metadata map fetch failed: {e}")
        return {}


def _build_scan_action(obj_name: str, meta_map: dict, predicate_text: str) -> str:
    """
    Build a specific, data-driven action string for a full-scan finding,
    instead of the previous identical canned text for every row.
    Uses whatever awr_object_metadata has for this object (row count,
    stats staleness) plus the plan's own captured predicate text --
    honest about what it can and can't say: this schema has no
    index-to-table linkage (indexes and tables are separate rows with
    no FK), so this deliberately does NOT claim "no index exists on
    this table" -- that would need a different data source
    (DBA_IND_COLUMNS-style table_name linkage) that isn't captured
    anywhere in this codebase today.
    """
    meta = meta_map.get((obj_name or "").upper())
    parts = []

    if meta and meta.get("num_rows"):
        rows = int(meta["num_rows"])
        parts.append(f"{obj_name} has {rows:,} rows")
    elif obj_name:
        parts.append(f"{obj_name}")

    if meta and meta.get("last_analyzed") is None:
        parts.append("statistics have never been gathered (optimizer is using defaults, which makes this row-count context unreliable too)")
    elif meta and meta.get("last_analyzed"):
        from datetime import datetime as _dt
        days = (_dt.now() - meta["last_analyzed"]).days
        if days > 30:
            parts.append(f"statistics are {days} days stale")

    if predicate_text:
        parts.append(f"a filter predicate is present ({predicate_text.strip()[:120]}) but the optimizer still chose a full scan -- check whether this predicate is sargable (not wrapped in a function/implicit datatype conversion) and whether a selective index exists covering the filtered column(s)")
    else:
        parts.append("no filter predicate reaches this table at all -- confirm this is an intentional whole-table read (e.g. a batch/reporting job); if not, an index cannot help regardless of what exists, since nothing is being filtered on")

    if not parts:
        return "Verify scans are expected. For OLTP workloads check for missing selective indexes."
    capitalized = [p[0].upper() + p[1:] if p else p for p in parts]
    return ". ".join(capitalized) + "."


def _fetch_plan_metadata_warnings(dbname: str, object_names: list, meta_map: dict = None) -> list:
    """
    Look up awr_object_metadata for objects in an execution plan.
    Returns list of finding dicts with metadata-driven warnings.
    Pass a pre-fetched meta_map (from _fetch_object_metadata_map) to
    avoid a second identical query when the caller already has one --
    analyse_plan fetches it up front for _build_scan_action and reuses
    it here instead of querying awr_object_metadata twice per plan.
    """
    if not dbname or not object_names:
        return []
    try:
        from datetime import datetime as _dt
        if meta_map is None:
            meta_map = _fetch_object_metadata_map(dbname, object_names)
        warnings = []
        now = _dt.now()

        for row in meta_map.values():
            obj_name, obj_type, num_rows, last_analyzed, blevel = (
                row["object_name"], row["object_type"], row["num_rows"],
                row["last_analyzed"], row["blevel"])
            distinct_keys, clust_factor, idx_cols, partition_type, uniqueness = (
                row["distinct_keys"], row["clustering_factor"], row["index_columns"],
                row["partition_type"], row["uniqueness"])

            # Missing statistics
            if last_analyzed is None:
                warnings.append({
                    "severity": "HIGH",
                    "pattern":  "Missing Statistics",
                    "detail":   f"{obj_name}: never analyzed — optimizer using defaults",
                    "action":   f"EXEC DBMS_STATS.GATHER_TABLE_STATS(owner,'{obj_name}',CASCADE=>TRUE);",
                })
            elif (now - last_analyzed).days > 30:
                days = (now - last_analyzed).days
                warnings.append({
                    "severity": "HIGH" if days > 90 else "MEDIUM",
                    "pattern":  "Stale Statistics",
                    "detail":   f"{obj_name}: last analyzed {days} days ago ({last_analyzed.strftime('%Y-%m-%d')})",
                    "action":   f"EXEC DBMS_STATS.GATHER_TABLE_STATS(owner,'{obj_name}',CASCADE=>TRUE,ESTIMATE_PERCENT=>DBMS_STATS.AUTO_SAMPLE_SIZE);",
                })

            # High clustering factor
            if obj_type == 'INDEX' and clust_factor and num_rows:
                try:
                    ratio = float(clust_factor) / float(num_rows)
                    if ratio > 0.8:
                        warnings.append({
                            "severity": "HIGH" if ratio > 1.5 else "MEDIUM",
                            "pattern":  "High Clustering Factor",
                            "detail":   f"{obj_name}: clustering_factor={int(clust_factor):,} / num_rows={int(num_rows):,} = {ratio:.1f}x",
                            "action":   "Rebuild table sorted by index key, or evaluate full scan + parallel query.",
                        })
                except (TypeError, ZeroDivisionError):
                    pass

            # Deep B-tree index
            if obj_type == 'INDEX' and blevel and blevel >= 4:
                warnings.append({
                    "severity": "HIGH" if blevel >= 5 else "MEDIUM",
                    "pattern":  "Deep B-tree Index",
                    "detail":   f"{obj_name}: blevel={blevel} (healthy ≤ 3) — {blevel+1} I/Os per lookup",
                    "action":   f"ALTER INDEX {obj_name} REBUILD ONLINE;",
                })

            # Index column info
            if obj_type == 'INDEX' and idx_cols:
                try:
                    import json as _json
                    cols = _json.loads(idx_cols)
                    col_list = ", ".join(c.get("col","") for c in cols)
                    warnings.append({
                        "severity": "INFO",
                        "pattern":  "Index Definition",
                        "detail":   f"{obj_name} [{uniqueness}]: ({col_list})",
                        "action":   "Verify predicate selectivity matches index column order.",
                    })
                except Exception:
                    pass

            # Row count context for tables
            if obj_type == 'TABLE' and num_rows:
                try:
                    rows_k = int(num_rows)
                    if rows_k > 0:
                        warnings.append({
                            "severity": "INFO",
                            "pattern":  "Table Size",
                            "detail":   f"{obj_name}: {rows_k:,} rows"
                                        + (f", partitioned ({partition_type})" if partition_type else ", unpartitioned"),
                            "action":   "Use this row count to validate optimizer cardinality estimates.",
                        })
                except (TypeError, ValueError):
                    pass

        return warnings
    except Exception as e:
        import logging
        logging.getLogger("plan_parser").debug(f"Metadata warning fetch failed: {e}")
        return []


def parse_plan(text: str) -> ExecutionPlan:
    """
    Parse a raw DBMS_XPLAN output string into an ExecutionPlan object.
    Handles multiple plan formats in the same file — returns first plan found.
    """
    plan = ExecutionPlan()
    plan.plan_text = text

    lines = text.splitlines()

    # ── Extract SQL_ID ────────────────────────────────────────────────
    for line in lines:
        m = re.match(r"SQL_ID\s+(\S+)", line.strip())
        if m:
            plan.sql_id = m.group(1).rstrip(",")
            break

    # ── Extract Plan hash value ───────────────────────────────────────
    for line in lines:
        m = re.match(r"Plan hash value:\s*(\d+)", line.strip())
        if m:
            plan.plan_hash = m.group(1)
            break

    # ── Extract SQL text (between SQL_ID line and "Plan hash value") ──
    in_sql = False
    sql_lines = []
    for line in lines:
        if re.match(r"SQL_ID\s+", line.strip()):
            in_sql = True
            continue
        if in_sql:
            if re.match(r"Plan hash value:", line.strip()):
                break
            if re.match(r"-{10,}", line.strip()):
                break
            if line.strip().startswith("---"):
                break
            sql_lines.append(line.rstrip())
    plan.sql_text = "\n".join(sql_lines).strip()

    # ── Find the plan table (row starting with |) ─────────────────────
    # Detect column header line: | Id | Operation | Name | ...
    header_idx = None
    divider_pat = re.compile(r"^\s*[-|+]{5,}")

    for i, line in enumerate(lines):
        if re.match(r"\|\s*Id\s*\|\s*Operation", line.strip()):
            header_idx = i
            break

    if header_idx is None:
        plan.error = "No plan table found"
        return plan

    # ── Parse column positions from header ───────────────────────────
    header = lines[header_idx]
    # Columns: Id | Operation | Name | Rows | Bytes | Cost | Time
    col_names = [c.strip() for c in header.split("|") if c.strip()]

    def col_idx(name):
        for j, c in enumerate(col_names):
            if name.lower() in c.lower():
                return j
        return -1

    ci_id   = col_idx("id")
    ci_op   = col_idx("operation")
    ci_name = col_idx("name")
    ci_rows = col_idx("rows")
    ci_bytes= col_idx("bytes")
    ci_cost = col_idx("cost")
    ci_time = col_idx("time")

    # ── Parse plan rows ───────────────────────────────────────────────
    in_plan  = False
    past_header = False
    seen_data_row = False   # at least one data row seen

    for line in lines[header_idx:]:
        stripped = line.strip()

        is_divider = bool(divider_pat.match(line)) and not stripped.startswith("|")

        if is_divider:
            if seen_data_row:
                break    # end of plan table — only break after seeing real data
            continue     # skip dividers before/between header and first data row

        if not stripped.startswith("|"):
            if seen_data_row and stripped:
                break
            continue

        # Skip the header row itself
        if "Id" in stripped and "Operation" in stripped:
            past_header = True
            continue

        if not past_header:
            continue

        parts = [p for p in line.split("|")]
        if len(parts) < 3:
            continue

        def get_col(idx):
            if idx < 0 or idx + 1 >= len(parts):
                return ""
            return parts[idx + 1].strip()

        raw_id  = get_col(ci_id)
        raw_op  = get_col(ci_op)
        raw_name= get_col(ci_name) if ci_name >= 0 else ""
        raw_rows= get_col(ci_rows) if ci_rows >= 0 else ""
        raw_bytes= get_col(ci_bytes) if ci_bytes >= 0 else ""
        raw_cost = get_col(ci_cost) if ci_cost >= 0 else ""
        raw_time = get_col(ci_time) if ci_time >= 0 else ""

        # Extract step_id (may have * prefix)
        id_match = re.search(r"\*?\s*(\d+)", raw_id)
        if not id_match:
            continue
        step_id = int(id_match.group(1))

        # Measure indent from leading spaces in operation
        indent = len(raw_op) - len(raw_op.lstrip())
        operation = raw_op.strip().lstrip("*").strip()

        step = PlanStep(
            step_id    = step_id,
            operation  = operation,
            object_name= raw_name,
            rows_est   = _parse_size(raw_rows),
            bytes_est  = _parse_size(raw_bytes),
            cost       = _parse_cost(raw_cost),
            time_est   = raw_time,
            indent     = indent,
        )
        step = _detect_problems(step)
        plan.steps.append(step)
        seen_data_row = True

        if operation.upper() in FULL_SCAN_OPS:
            plan.has_full_scan = True
        if any(nlo in operation.upper() for nlo in NESTED_LOOP_OPS):
            plan.has_nested_loop = True

    # ── Total cost from SELECT STATEMENT (step 0) ────────────────────
    for step in plan.steps:
        if step.step_id == 0:
            plan.total_cost = step.cost
            plan.total_rows = step.rows_est
            break

    # ── Parse Predicate Information ───────────────────────────────────
    # BUG FIX (2026-08-31): standard Oracle DBMS_XPLAN output always has
    # a blank line between the '---' divider and the first numbered
    # predicate entry (this is standard formatting, not an edge case --
    # every real plan looks like this). The old logic treated ANY blank
    # line inside the predicate section as "end of section", including
    # that one, so it exited before ever reading a single predicate
    # line -- plan.predicates came back empty for every real-world
    # plan pasted into this tool. Fixed by only treating a blank line
    # as end-of-section once at least one real predicate entry has
    # actually been captured.
    pred_section = False
    current_pred_id = None
    pred_lines = {}
    seen_pred_line = False

    for line in lines:
        if "Predicate Information" in line:
            pred_section = True
            continue
        if pred_section:
            if re.match(r"\s*Note\s*$", line) or re.match(r"\s*-{5,}", line):
                if "Note" in line:
                    pred_section = False
                continue
            m = re.match(r"\s+(\d+)\s*-\s*(.*)", line)
            if m:
                current_pred_id = int(m.group(1))
                pred_lines[current_pred_id] = m.group(2).strip()
                seen_pred_line = True
            elif current_pred_id and line.strip():
                pred_lines[current_pred_id] += " " + line.strip()
            elif not line.strip() and seen_pred_line:
                pred_section = False

    plan.predicates = pred_lines

    # Attach predicates to steps
    for step in plan.steps:
        if step.step_id in pred_lines:
            step.predicates = pred_lines[step.step_id]

    # ── Parse Notes ───────────────────────────────────────────────────
    note_section = False
    for line in lines:
        if re.match(r"\s*Note\s*$", line.strip()):
            note_section = True
            continue
        if note_section:
            if re.match(r"\s*-{3,}", line):
                continue
            if line.strip():
                plan.notes.append(line.strip().lstrip("- "))
            else:
                note_section = False

    return plan


def compare_plans(plan_a: ExecutionPlan, plan_b: ExecutionPlan) -> dict:
    """
    Compare two execution plans and return a structured diff.
    plan_a = baseline (before), plan_b = optimized (after)
    """
    result = {
        "cost_change":     None,
        "cost_pct_change": None,
        "improved":        None,
        "summary":         [],
        "step_diff":       [],
        "new_problems":    [],
        "fixed_problems":  [],
        "access_changes":  [],
    }

    # ── Overall cost comparison ───────────────────────────────────────
    if plan_a.total_cost is not None and plan_b.total_cost is not None:
        result["cost_change"] = plan_b.total_cost - plan_a.total_cost
        if plan_a.total_cost > 0:
            result["cost_pct_change"] = (result["cost_change"] / plan_a.total_cost) * 100
        result["improved"] = plan_b.total_cost < plan_a.total_cost

        direction = "↓ IMPROVED" if result["improved"] else "↑ REGRESSED"
        result["summary"].append(
            f"Total cost: {plan_a.total_cost:,.0f} → {plan_b.total_cost:,.0f} "
            f"({result['cost_pct_change']:+.1f}%) {direction}"
        )

    # ── Full scan changes ─────────────────────────────────────────────
    if plan_a.has_full_scan and not plan_b.has_full_scan:
        result["summary"].append("✅ Full table scan eliminated in optimized plan")
        result["fixed_problems"].append("Full table scan removed")
    elif not plan_a.has_full_scan and plan_b.has_full_scan:
        result["summary"].append("⚠️ New full table scan introduced in optimized plan")
        result["new_problems"].append("Full table scan introduced")

    # ── Step-level diff — match by OPERATION+OBJECT not step_id ─────────
    # This correctly handles plans where steps renumber after optimisation.
    # Strategy: match steps greedily by (operation, object_name) pair.
    # Unmatched steps in baseline = removed; unmatched in optimised = added.

    def op_key(step):
        """Normalised key for matching: operation + object."""
        op  = (step.operation or "").strip().upper()
        obj = (step.object_name or "").strip().upper()
        return (op, obj)

    used_b = set()   # indices of plan_b steps already matched

    matched   = []   # (step_a, step_b)
    unmatched_a = [] # steps in baseline with no match in optimised
    unmatched_b = [] # steps in optimised with no match in baseline

    for sa in plan_a.steps:
        key = op_key(sa)
        # Find first unmatched step in plan_b with same op+obj
        found = None
        for i, sb in enumerate(plan_b.steps):
            if i not in used_b and op_key(sb) == key:
                found = (i, sb)
                break
        if found:
            used_b.add(found[0])
            matched.append((sa, found[1]))
        else:
            unmatched_a.append(sa)

    for i, sb in enumerate(plan_b.steps):
        if i not in used_b:
            unmatched_b.append(sb)

    # Build step_diff from matched pairs
    for sa, sb in matched:
        cost_changed = (sa.cost or 0) != (sb.cost or 0)
        result["step_diff"].append({
            "step_id":    sa.step_id,
            "op_a":       sa.operation,
            "op_b":       sb.operation,
            "obj_a":      sa.object_name,
            "obj_b":      sb.object_name,
            "cost_a":     sa.cost,
            "cost_b":     sb.cost,
            "rows_a":     sa.rows_est,
            "rows_b":     sb.rows_est,
            "bytes_a":    sa.bytes_est,
            "bytes_b":    sb.bytes_est,
            "op_changed": False,
            "obj_changed":False,
            "status":     "same",
        })

    # Pair unmatched_a with unmatched_b by position — these are genuine changes
    max_len = max(len(unmatched_a), len(unmatched_b))
    for i in range(max_len):
        sa = unmatched_a[i] if i < len(unmatched_a) else None
        sb = unmatched_b[i] if i < len(unmatched_b) else None

        if sa and sb:
            # Genuine operation change
            result["step_diff"].append({
                "step_id":    sa.step_id,
                "op_a":       sa.operation,
                "op_b":       sb.operation,
                "obj_a":      sa.object_name,
                "obj_b":      sb.object_name,
                "cost_a":     sa.cost,
                "cost_b":     sb.cost,
                "rows_a":     sa.rows_est,
                "rows_b":     sb.rows_est,
                "bytes_a":    sa.bytes_est,
                "bytes_b":    sb.bytes_est,
                "op_changed": True,
                "obj_changed":sa.object_name != sb.object_name,
                "status":     "changed",
            })
            # This is a genuine access path change
            change = f"{sa.operation} ({sa.object_name}) → {sb.operation} ({sb.object_name})"
            result["access_changes"].append(change)
            if "FULL" in sa.operation.upper() and "FULL" not in sb.operation.upper():
                result["fixed_problems"].append(f"Full scan removed: {sa.operation} on {sa.object_name} → {sb.operation}")
            elif "FULL" not in sa.operation.upper() and "FULL" in sb.operation.upper():
                result["new_problems"].append(f"New full scan: {sb.operation} on {sb.object_name}")

        elif sa:
            # Step removed in optimised
            result["step_diff"].append({
                "step_id": sa.step_id, "status": "removed",
                "op_a": sa.operation, "obj_a": sa.object_name,
                "op_b": "", "obj_b": "",
                "cost_a": sa.cost, "cost_b": None,
                "rows_a": sa.rows_est, "rows_b": None,
                "bytes_a": sa.bytes_est, "bytes_b": None,
                "op_changed": False,
            })
        else:
            # New step in optimised
            result["step_diff"].append({
                "step_id": sb.step_id, "status": "added",
                "op_a": "", "obj_a": "",
                "op_b": sb.operation, "obj_b": sb.object_name,
                "cost_a": None, "cost_b": sb.cost,
                "rows_a": None, "rows_b": sb.rows_est,
                "bytes_a": None, "bytes_b": sb.bytes_est,
                "op_changed": False,
            })

    # Sort step_diff by baseline step_id for display
    result["step_diff"].sort(key=lambda d: d.get("step_id") or 999)

    # ── Re-evaluate new/fixed problems based on OPERATIONS not step numbers ──
    # An operation is "new" only if it doesn't appear anywhere in baseline
    # An operation is "fixed" only if it doesn't appear anywhere in optimised
    ops_a = {s.operation.upper() for s in plan_a.steps}
    ops_b = {s.operation.upper() for s in plan_b.steps}

    # Full scans
    full_ops = {"TABLE ACCESS FULL", "FIXED TABLE FULL", "INDEX FAST FULL SCAN"}
    full_in_a = any(op in s.operation.upper() for s in plan_a.steps for op in full_ops)
    full_in_b = any(op in s.operation.upper() for s in plan_b.steps for op in full_ops)

    if full_in_a and not full_in_b:
        result["fixed_problems"] = [p for p in result["fixed_problems"]
                                    if "Full scan" not in p] + ["Full table scan removed"]
    elif not full_in_a and full_in_b:
        result["new_problems"] = [p for p in result["new_problems"]
                                  if "Full scan" not in p] + ["Full table scan introduced"]

    # Remove any false-positive "new full scan" entries that were added by step-ID matching
    # (operation existed in baseline under a different step number)
    cleaned_new = []
    for prob in result["new_problems"]:
        if "Full scan" in prob or "FULL" in prob.upper():
            # Only keep if full scan op is genuinely new (not in baseline)
            if not full_in_a:
                cleaned_new.append(prob)
            # else: it existed in baseline — skip (step renumbering artifact)
        else:
            cleaned_new.append(prob)
    result["new_problems"] = cleaned_new

    # Filter access_changes — remove step-renumbering artifacts
    # A change is genuine only if the NEW operation didn't exist anywhere in baseline
    # OR the OLD operation didn't exist anywhere in optimised plan
    cleaned_access = []
    for change in result["access_changes"]:
        parts = change.split("→")
        if len(parts) == 2:
            old_op = parts[0].strip().split("(")[0].strip().upper()
            # Extract just op name before object in parens
            old_op = old_op.split("Step")[1].strip() if "Step" in old_op else old_op
            # Clean step number prefix: "Step 7: HASH JOIN" → "HASH JOIN"
            if ":" in old_op:
                old_op = old_op.split(":")[-1].strip()
            new_op = parts[1].strip().split("(")[0].strip().upper()

            new_op_in_baseline  = any(new_op in s.operation.upper() for s in plan_a.steps)
            old_op_in_optimised = any(old_op in s.operation.upper() for s in plan_b.steps)

            # Skip if new op already existed in baseline AND old op still exists in optimised
            # This means both operations exist in both plans — it's just a step renumber
            if new_op_in_baseline and old_op_in_optimised:
                continue

            # Also skip if new op already existed in baseline (moved, not introduced)
            if new_op_in_baseline:
                continue

        cleaned_access.append(change)
    result["access_changes"] = cleaned_access

    # Re-clean new_problems using same logic
    cleaned_new = []
    for prob in result["new_problems"]:
        if any(scan in prob.upper() for scan in ["FULL SCAN", "TABLE ACCESS FULL"]):
            if not full_in_a:  # Only flag if genuinely not in baseline
                cleaned_new.append(prob)
        else:
            cleaned_new.append(prob)
    result["new_problems"] = cleaned_new

    return result


# ── Compatibility wrappers for plan_upload route ──────────────────────
# The /upload/plan route uses these older function names.
# They bridge the old API to the new parse_plan() internally.

import sys as _sys
import os as _os


def parse_plan_text(text: str, dbname: str, sql_id: str = None,
                    begin_snap: int = None, upload_source: str = "paste") -> list:
    """
    Parse a single execution plan text and return a list of row dicts
    compatible with insert_plan() / awr_execution_plans table.
    """
    plan = parse_plan(text)
    rows = []
    for step in plan.steps:
        rows.append({
            "dbname":           dbname,
            "sql_id":           sql_id or plan.sql_id or "",
            "plan_hash_value":  plan.plan_hash or "",
            "begin_snap":       begin_snap,
            "step_id":          step.step_id,
            "operation":        step.operation,
            "object_name":      step.object_name,
            "cost":             step.cost,
            "cardinality":      step.rows_est,
            "bytes":            step.bytes_est,
            "time_est":         step.time_est,
            "filter_predicates":step.predicates,
            "has_full_scan":    "FULL" in (step.operation or "").upper(),
            "plan_warning":     step.problem_reason or None,
            "upload_source":    upload_source,
        })
    return rows


def parse_multi_plan_file(text: str, dbname: str, begin_snap: int = None,
                          upload_source: str = "file") -> list:
    """
    Split a multi-plan file (multiple SQL_ID blocks) and parse each plan.
    Returns a list of dicts: {sql_id, plan_hash, rows, analysis}
    """
    import re
    # Split on SQL_ID markers
    blocks = re.split(r"(?=SQL_ID\s+[A-Za-z0-9_$#]+)", text, flags=re.IGNORECASE)
    results = []
    for block in blocks:
        block = block.strip()
        if not block:
            continue
        plan = parse_plan(block)
        if not plan.steps:
            continue
        rows = parse_plan_text(block, dbname,
                               sql_id=plan.sql_id or None,
                               begin_snap=begin_snap,
                               upload_source=upload_source)
        results.append({
            "sql_id":     plan.sql_id,
            "plan_hash":  plan.plan_hash,
            "sql_text":   plan.sql_text,
            "rows":       rows,
            "analysis":   analyse_plan(rows),
        })
    return results


def insert_plan(records: list) -> int:
    """Insert plan step records into awr_execution_plans. Returns inserted count."""
    if not records:
        return 0
    try:
        _sys.path.insert(0, _os.path.join(
            _os.path.abspath(_os.path.dirname(__file__)), "..", "..", "common"))
        from db import get_db_connection
        conn = get_db_connection()
        count = 0
        try:
            with conn.cursor() as cur:
                for r in records:
                    cur.execute("""
                        INSERT INTO awr_execution_plans
                          (dbname, sql_id, plan_hash_value, begin_snap,
                           step_id, operation, object_name, cost,
                           cardinality, bytes, filter_predicates,
                           has_full_scan, plan_warning, upload_source)
                        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                        ON CONFLICT (dbname, sql_id, plan_hash_value, step_id)
                        DO UPDATE SET cost=EXCLUDED.cost,
                                      cardinality=EXCLUDED.cardinality,
                                      has_full_scan=EXCLUDED.has_full_scan
                    """, (
                        r.get("dbname",""), r.get("sql_id",""),
                        r.get("plan_hash_value",""), r.get("begin_snap"),
                        r.get("step_id"), r.get("operation"),
                        r.get("object_name"), r.get("cost"),
                        r.get("cardinality"), r.get("bytes"),
                        r.get("filter_predicates"), r.get("has_full_scan", False),
                        r.get("plan_warning"), r.get("upload_source","paste"),
                    ))
                    count += 1
            conn.commit()
        finally:
            conn.close()
        return count
    except Exception as e:
        import logging
        logging.getLogger("plan_parser").error(f"insert_plan failed: {e}")
        return 0


def insert_multi_plan(results: list) -> dict:
    """Insert multiple plans. Returns {sql_id: step_count}."""
    summary = {}
    for r in results:
        n = insert_plan(r.get("rows", []))
        summary[r.get("sql_id", "unknown")] = n
    return summary


def analyse_plan(records: list) -> dict:
    """
    Analyse plan records and return summary dict for the template.
    Works with both list-of-dicts (from parse_plan_text) format.
    Includes finding_count and all attributes accessed via dot notation in template.
    """
    if not records:
        from types import SimpleNamespace
        return SimpleNamespace(
            sql_id="", plan_hash="", step_count=0,
            total_cost=None, has_full_scan=False,
            findings=[], finding_count=0,
            has_nested_loop=False, notes=[],
            top_issue=None,
        )

    sql_id     = records[0].get("sql_id", "")
    plan_hash  = records[0].get("plan_hash_value", "")
    total_cost = None
    has_full   = False
    has_nl     = False
    findings   = []

    # Track full scan objects to avoid duplicates
    full_scan_objects = set()

    # Fetch object metadata ONCE, up front, so the scan findings below can
    # build specific action text (row counts, stats staleness) instead of
    # identical canned text for every row -- same query
    # _fetch_plan_metadata_warnings uses further down, shared via
    # _fetch_object_metadata_map rather than queried twice.
    _dbname = records[0].get("dbname", "") if records else ""
    _obj_names_upfront = list({r.get("object_name", "") for r in records
                                if r.get("object_name", "")})
    _meta_map = _fetch_object_metadata_map(_dbname, _obj_names_upfront)

    for r in records:
        if r.get("step_id") == 0 and r.get("cost"):
            total_cost = r["cost"]
        op  = (r.get("operation") or "").upper()
        obj = r.get("object_name", "") or ""

        # Full table scan
        if "TABLE ACCESS FULL" in op or "FIXED TABLE FULL" in op:
            has_full = True
            if obj not in full_scan_objects:
                full_scan_objects.add(obj)
                findings.append({
                    "severity": "HIGH",
                    "pattern":  "Full Table / Index Fast Full Scan",
                    "detail":   f"Objects: {obj}" if obj else "",
                    "action":   _build_scan_action(obj, _meta_map, r.get("filter_predicates") or r.get("access_predicates")),
                })

        # Index fast full scan — only flag if large cardinality
        if "INDEX FAST FULL SCAN" in op:
            card = r.get("cardinality") or 0
            if float(card) > 10000 and obj not in full_scan_objects:
                has_full = True
                full_scan_objects.add(obj)
                findings.append({
                    "severity": "HIGH",
                    "pattern":  "Full Table / Index Fast Full Scan",
                    "detail":   f"Objects: {obj}",
                    "action":   _build_scan_action(obj, _meta_map, r.get("filter_predicates") or r.get("access_predicates")),
                })

        # Unbounded full scan — full scan with no filter predicate
        if ("TABLE ACCESS FULL" in op and
                not r.get("filter_predicates") and
                not r.get("access_predicates")):
            findings.append({
                "severity": "HIGH",
                "pattern":  "Unbounded Full Scan",
                "detail":   f"Step {r.get('step_id')}: {obj} — no filter predicate",
                "action":   _build_scan_action(obj, _meta_map, None),
            })

        # High cost step
        cost = r.get("cost") or 0
        if float(cost) > 10000 and r.get("step_id") != 0:
            # Collect top operations for context
            pass

        # Nested loops on large results
        if "NESTED LOOP" in op:
            has_nl = True
            card = r.get("cardinality") or 0
            if float(card) > 1000:
                findings.append({
                    "severity": "MEDIUM",
                    "pattern":  "Nested Loop on Large Result",
                    "detail":   f"Step {r.get('step_id')}: {card:,.0f} rows",
                    "action":   "Consider hash join for large datasets.",
                })

    # High cost summary (do once across all steps)
    max_cost_rec = max(
        (r for r in records if r.get("step_id") != 0),
        key=lambda r: float(r.get("cost") or 0),
        default=None
    )
    if max_cost_rec and float(max_cost_rec.get("cost") or 0) > 10000:
        top_ops = list({r.get("operation") for r in records
                        if float(r.get("cost") or 0) > 1000 and r.get("step_id") != 0})[:3]
        findings.append({
            "severity": "MEDIUM",
            "pattern":  "High Cost Operation",
            "detail":   f"Max step cost {float(max_cost_rec.get('cost',0)):,.0f}. "
                        f"Top operations: {top_ops}",
            "action":   "Validate row estimates and statistics currency.",
        })

    # ── Metadata enrichment ───────────────────────────────────────────
    # Look up object metadata for each object in the plan
    # Adds warnings like "45M rows, never analyzed" or "blevel=5, rebuild needed"
    # Reuses _meta_map fetched up front (see above) instead of querying again.
    meta_warnings = _fetch_plan_metadata_warnings(
        _dbname, _obj_names_upfront, meta_map=_meta_map
    )
    for w in meta_warnings:
        findings.append(w)
        if w.get("severity") == "HIGH":
            has_full = True  # surface as notable issue

    # Deduplicate findings
    seen = set()
    unique_findings = []
    for f in findings:
        key = (f["pattern"], f["detail"][:40])
        if key not in seen:
            seen.add(key)
            unique_findings.append(f)

    from types import SimpleNamespace
    d = {
        "sql_id":          sql_id,
        "plan_hash":       plan_hash,
        "step_count":      len(records),
        "total_cost":      total_cost,
        "has_full_scan":   has_full,
        "has_nested_loop": has_nl,
        "findings":        unique_findings,
        "finding_count":   len(unique_findings),
        "top_issue":       unique_findings[0] if unique_findings else None,
        "notes":           [],
    }
    # Return as SimpleNamespace so template dot-notation (analysis.finding_count) works
    result = SimpleNamespace(**d)
    # Also attach findings as list of SimpleNamespace objects for template dot access
    result.findings = [SimpleNamespace(**f) for f in unique_findings]
    result.top_issue = result.findings[0] if result.findings else None
    return result
