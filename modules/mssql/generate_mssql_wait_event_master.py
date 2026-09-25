"""
Generates schema/mssql_wait_event_master_data.sql from the wait-event
CSV Ganesh provided (1,335 raw sys.dm_os_wait_stats wait_type values)
plus the 24 sys.query_store_wait_stats wait_category values from his
second file.

Classification approach, stated honestly:
  - wait_class: derived from naming-convention pattern matching --
    reasonable confidence for the vast majority (SQL Server's wait
    type names are genuinely systematic), not individually verified
    per-entry.
  - is_benign: ONLY set true for exact matches against
    rule_engine.py's own BENIGN_WAIT_TYPES -- the single source of
    truth already used by the actual rule evaluation code, not a
    broader guess. Every other entry defaults to false, even ones
    that are very likely also benign by naming pattern (e.g. most
    SLEEP_*, most XE_*) -- left as false rather than extending
    is_benign beyond what's actually been researched and wired into
    the rule engine itself.
  - has_specific_rule / rule_ids: computed by actually loading
    recommendation_rules_mssql_v1.json and matching each event name
    against every rule's event_pattern (wildcard-aware, same logic as
    rule_engine._match_event_pattern) -- not hand-maintained, so this
    can never drift out of sync with the real rules file.
  - guidance_text / source: populated only for entries this project
    has genuinely researched this conversation (every rule-covered
    event, every BENIGN_WAIT_TYPES entry) -- everything else gets
    NULL, which is the honest state, not a placeholder string.
"""

import csv
import json
import os
import sys

_REPO = os.path.abspath(os.path.join(os.path.dirname(__file__)))
sys.path.insert(0, os.path.join(_REPO, 'modules', 'mssql'))
sys.path.insert(0, os.path.join(_REPO, 'modules'))
sys.path.insert(0, os.path.join(_REPO, 'common'))

import rule_engine as re_mssql

CSV_PATH = "/mnt/user-data/uploads/dm_os_wait_stats_-_wait_events.csv"
CATEGORIES = [
    "Unknown", "CPU", "Parallelism", "Memory", "Latch", "Compilation", "Network IO",
    "Buffer Latch", "Buffer IO", "Other Disk IO", "Lock", "Access Methods",
    "External Resource", "User Wait", "Tracing", "Transaction Log",
    "Replication", "Sparse Column", "CLR", "Mirroring", "Transaction",
    "Idle", "Preemptive", "Worker Termination",
]
# Note: "External External Resource" in Ganesh's file is a paste artifact --
# used "External Resource" here as the intended value.
#
# "Transaction Log" above is the FORMAL enum name from Ganesh's reference
# file -- but a real run against his actual instance showed the live
# wait_category_desc value is genuinely "Tran Log IO", not "Transaction
# Log" (confirmed directly: MSSQL_WAIT_009 was built and tested against
# the real observed string, not the reference list). Added as its own
# entry below rather than silently overwriting/renaming the formal
# reference value -- both are worth keeping, with a note explaining why
# they differ, since a future reader shouldn't have to rediscover this.
EXTRA_CATEGORY_NOTES = {
    "Tran Log IO": "The actual observed wait_category_desc string from live sys.query_store_wait_stats data "
                   "(confirmed against a real instance run) -- differs from 'Transaction Log', the formal enum "
                   "name in Microsoft's own reference documentation. MSSQL_WAIT_009 targets this real string.",
}

# ── wait_class classification (naming-convention based) ──────────
CLASS_RULES = [
    ("LCK_", "Lock"),
    ("PAGEIOLATCH_", "Buffer IO"),
    ("PAGELATCH_", "Buffer Latch"),
    ("LATCH_", "Latch"),
    ("CXPACKET", "Parallelism"), ("CXCONSUMER", "Parallelism"),
    ("CXSYNC_", "Parallelism"), ("CXROWSET_", "Parallelism"),
    ("EXCHANGE", "Parallelism"),
    ("RESOURCE_SEMAPHORE", "Memory"),
    ("CMEMTHREAD", "Memory"), ("CMEMPARTITIONED", "Memory"),
    ("WRITELOG", "Transaction Log"), ("LOGMGR", "Transaction Log"),
    ("LOGBUFFER", "Transaction Log"), ("LOGGENERATION", "Transaction Log"),
    ("LOG_", "Transaction Log"),
    ("ASYNC_NETWORK_IO", "Network IO"), ("NET_", "Network IO"),
    ("SNI_", "Network IO"),
    ("HADR_", "Replication/HA"), ("DBMIRROR", "Mirroring"),
    ("BROKER_", "Service Broker"),
    ("XE_", "Extended Events"),
    ("CLR_", "CLR"),
    ("SLEEP_", "Idle/Sleep"), ("WAITFOR", "Idle/Sleep"),
    ("QDS_", "Query Store Internal"),
    ("XACT", "Transaction"), ("TRAN_", "Transaction"), ("DTC", "Transaction"),
    ("BACKUP", "Backup/Restore"),
    ("IO_COMPLETION", "Other Disk IO"), ("IO_", "Other Disk IO"),
    ("FT_", "Full Text Search"), ("FULLTEXT", "Full Text Search"),
    ("SP_SERVER_", "Internal"),
    ("WAIT_XTP_", "In-Memory OLTP"), ("XTP_", "In-Memory OLTP"),
    ("PREEMPTIVE_", "Preemptive"),
    ("SOS_", "CPU/Scheduler"),
    ("CHECKPOINT", "Checkpoint"), ("CHKPT", "Checkpoint"),
    ("HT", "Hash Join"),
    ("BMP", "Bitmap"),
    ("REPL_", "Replication/HA"),
    ("DISPATCHER_", "Internal"),
]


def classify_wait_class(name: str) -> str:
    for prefix, cls in CLASS_RULES:
        if name.startswith(prefix):
            return cls
    return "Other"


# ── Guidance text for genuinely researched entries only ──────────
# Sourced directly from this project's own rule_engine.py rules and
# BENIGN_WAIT_TYPES comments -- reusing what was already researched
# and verified, not re-deriving it.
RESEARCHED_GUIDANCE = {
    "PAGEIOLATCH_SH": ("Waiting for a data page to be read from disk into the buffer pool (shared/read access). "
                        "High values indicate buffer pool pressure, missing/stale statistics, or storage-layer latency.",
                        "MSSQL_WAIT_001 root_cause, this project"),
    "PAGEIOLATCH_EX": ("Waiting for a data page to be read from disk into the buffer pool (exclusive/write access). "
                        "Same root causes as PAGEIOLATCH_SH.", "MSSQL_WAIT_001 root_cause, this project"),
    "WRITELOG": ("Waiting for the transaction log buffer to be flushed to disk on COMMIT/CHECKPOINT/log-block-full. "
                 "Low avg_wait_ms with high volume points at commit frequency (many small transactions); "
                 "high avg_wait_ms points at genuine log I/O latency.", "MSSQL_WAIT_008 root_cause, this project; Redgate Monitor alert thresholds"),
    "CXPACKET": ("Parallel query threads waiting for each other to synchronize -- the actionable side of parallelism. "
                 "High volume often means Cost Threshold for Parallelism is too low or MAXDOP is mismatched to the workload.",
                 "MSSQL_WAIT_003 root_cause, this project"),
    "CXCONSUMER": ("The benign, expected side of parallelism (a consumer thread waiting for a producer to provide rows) -- "
                   "deliberately split from CXPACKET so it wouldn't be mistaken for a problem. Excluded from findings.",
                   "Paul Randal / multiple DBA sources, verified this project"),
    "CXSYNC_PORT": ("New in SQL Server 2022 -- exchange port synchronization overhead between parallel producer/consumer "
                    "threads. Genuinely actionable, most often accompanies a blocking operator (sort/hash/spool) feeding an exchange.",
                    "MSSQL_WAIT_007 root_cause, this project"),
    "SOS_SCHEDULER_YIELD": ("A task voluntarily yielded the CPU and had to wait for its turn again -- genuine CPU-pressure "
                             "signal distinct from I/O or lock waits.", "MSSQL_WAIT_004 root_cause, this project"),
    "SOS_WORK_DISPATCHER": ("Benign -- idle SQLOS worker threads waiting for work to dispatch. Commonly the #1 wait on "
                             "SQL Server 2019+. Excluded from findings.", "Paul Randal, sqlskills.com, verified this project"),
    "RESOURCE_SEMAPHORE": ("A query's memory grant request (for sorts/hash joins) couldn't be satisfied because other "
                            "concurrent queries hold the memory. Can escalate to error 8645 if sustained.",
                            "MSSQL_WAIT_013 root_cause, this project; Microsoft Books Online"),
    "ASYNC_NETWORK_IO": ("SQL Server has results ready but is waiting for the client to consume them -- very often a "
                          "slow-consuming client application (row-by-row fetch), not genuine network latency.",
                          "MSSQL_WAIT_011 root_cause, this project"),
    "IO_COMPLETION": ("Non-buffer-pool I/O completion -- most commonly backup/restore or DBCC CHECKDB I/O. Expected "
                       "during known maintenance windows; a real signal outside them.", "MSSQL_WAIT_014 root_cause, this project"),
    "HADR_SYNC_COMMIT": ("Always On Availability Groups synchronous commit -- primary waiting for log hardening "
                          "confirmation from ALL synchronous secondaries. Points at secondary/network latency, not local storage.",
                          "MSSQL_WAIT_015 root_cause, this project"),
    "LATCH_EX": ("Exclusive latch on a non-page internal structure -- distinct from PAGELATCH/PAGEIOLATCH. Common "
                 "cause: a data/log file autogrow event briefly serializing access.", "MSSQL_WAIT_016 root_cause, this project"),
    "PREEMPTIVE_OS_AUTHENTICATIONOPS": ("Waiting on a Windows authentication API call. Small values routine; genuinely "
                                          "high/sustained values can indicate a real Active Directory/Domain Controller problem.",
                                          "MSSQL_WAIT_017 root_cause, this project"),
    "QDS_PERSIST_TASK_MAIN_LOOP_SLEEP": ("Benign -- Query Store's own persistence task sleeping between its ~60-second "
                                           "checks, not query workload. Excluded from findings.", "Paul Randal, sqlskills.com, verified this project"),
    "QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP": ("Benign -- Query Store's cleanup task's own sleep loop, same "
                                                          "nature as QDS_PERSIST_TASK_MAIN_LOOP_SLEEP.", "Paul Randal, sqlskills.com, verified this project"),
    "QDS_ASYNC_QUEUE": ("Benign -- Query Store's async persist-queue task sleeping between scheduled writes. Flushes "
                         "to sys.dm_os_wait_stats in bursts, not continuously, so large values are expected, not alarming.",
                         "Paul Randal (forum reply: 'entirely expected'), verified this project"),
}


def build_master_rows():
    with open(CSV_PATH, encoding="utf-8-sig") as f:
        wait_types = [l.strip() for l in f if l.strip()]

    engine = re_mssql.MssqlRuleEngine()
    rows = []

    for wt in wait_types:
        is_benign = wt in re_mssql.BENIGN_WAIT_TYPES
        matched_rules = [r["rule_id"] for r in engine.rules
                          if r.get("category") == "mssql_wait_type"
                          and re_mssql._match_event_pattern(r.get("event_pattern", "*"), wt)]
        guidance, source = RESEARCHED_GUIDANCE.get(wt, (None, None))
        rows.append({
            "tier": "wait_type", "event_name": wt,
            "wait_class": classify_wait_class(wt),
            "is_benign": is_benign,
            "has_specific_rule": len(matched_rules) > 0,
            "rule_ids": ",".join(matched_rules) if matched_rules else None,
            "guidance_text": guidance, "source": source,
        })

    for cat in CATEGORIES + list(EXTRA_CATEGORY_NOTES.keys()):
        cat_name = "External Resource" if "External" in cat else cat
        matched_rules = [r["rule_id"] for r in engine.rules
                          if r.get("category") == "mssql_wait_category"
                          and re_mssql._match_event_pattern(r.get("event_pattern", "*"), cat_name)]
        rows.append({
            "tier": "wait_category", "event_name": cat_name,
            "wait_class": None,  # categories ARE the class-equivalent already, no further classification needed
            "is_benign": False,
            "has_specific_rule": len(matched_rules) > 0,
            "rule_ids": ",".join(matched_rules) if matched_rules else None,
            "guidance_text": EXTRA_CATEGORY_NOTES.get(cat_name),
            "source": "Verified against a real instance run, this project" if cat_name in EXTRA_CATEGORY_NOTES else None,
        })

    return rows


def sql_escape(val):
    if val is None:
        return "NULL"
    if isinstance(val, bool):
        return "true" if val else "false"
    return "'" + str(val).replace("'", "''") + "'"


def main():
    rows = build_master_rows()
    n_benign = sum(1 for r in rows if r["is_benign"])
    n_rule = sum(1 for r in rows if r["has_specific_rule"])
    n_guidance = sum(1 for r in rows if r["guidance_text"])
    print(f"Total rows: {len(rows)} ({sum(1 for r in rows if r['tier']=='wait_type')} wait_type + "
          f"{sum(1 for r in rows if r['tier']=='wait_category')} wait_category)")
    print(f"  is_benign=true: {n_benign}")
    print(f"  has_specific_rule=true: {n_rule}")
    print(f"  guidance_text populated: {n_guidance}")

    out_path = os.path.join(_REPO, "schema", "mssql_wait_event_master_data.sql")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("-- ============================================================\n")
        f.write("-- mssql_wait_event_master data population\n")
        f.write("-- Auto-generated from the wait-event CSV + Query Store category\n")
        f.write("-- list Ganesh provided -- see generate_mssql_wait_event_master.py\n")
        f.write("-- for the classification logic. Run AFTER\n")
        f.write("-- mssql_wait_event_master_table.sql.\n")
        f.write(f"-- {len(rows)} rows: {n_benign} benign, {n_rule} rule-covered, {n_guidance} with researched guidance_text.\n")
        f.write("-- ============================================================\n\n")
        f.write("\\echo 'Populating mssql_wait_event_master...'\n\n")

        # Batch INSERTs, 200 rows per statement -- large enough to be
        # efficient, small enough to stay readable/diffable.
        batch_size = 200
        for i in range(0, len(rows), batch_size):
            batch = rows[i:i + batch_size]
            f.write("INSERT INTO mssql_wait_event_master\n")
            f.write("    (tier, event_name, wait_class, is_benign, has_specific_rule, rule_ids, guidance_text, source)\n")
            f.write("VALUES\n")
            value_lines = []
            for r in batch:
                value_lines.append(
                    f"    ({sql_escape(r['tier'])}, {sql_escape(r['event_name'])}, {sql_escape(r['wait_class'])}, "
                    f"{sql_escape(r['is_benign'])}, {sql_escape(r['has_specific_rule'])}, {sql_escape(r['rule_ids'])}, "
                    f"{sql_escape(r['guidance_text'])}, {sql_escape(r['source'])})"
                )
            f.write(",\n".join(value_lines))
            f.write("\nON CONFLICT (tier, event_name) DO UPDATE SET\n")
            f.write("    wait_class = EXCLUDED.wait_class, is_benign = EXCLUDED.is_benign,\n")
            f.write("    has_specific_rule = EXCLUDED.has_specific_rule, rule_ids = EXCLUDED.rule_ids,\n")
            f.write("    guidance_text = EXCLUDED.guidance_text, source = EXCLUDED.source;\n\n")

        f.write("\\echo 'mssql_wait_event_master population: done'\n")
        f.write("SELECT tier, count(*), count(*) FILTER (WHERE is_benign), "
                "count(*) FILTER (WHERE has_specific_rule), count(*) FILTER (WHERE guidance_text IS NOT NULL)\n")
        f.write("FROM mssql_wait_event_master GROUP BY tier;\n")

    print(f"\nWritten: {out_path}")


if __name__ == "__main__":
    main()
