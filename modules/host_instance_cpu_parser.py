#modules/host_instance_cpu_parser.py

# modules/host_instance_cpu_parser.py
#
# Parses the "Host CPU" and "Instance CPU" summary tables from the AWR
# report (the compact single-row tables near the top of the report,
# just after Load Profile / Report Summary — NOT the detailed
# "Operating System Statistics" section already covered by
# operating_system_statistics_parser.py, which is a different, longer
# V$OSSTAT-style dump).
#
# Both tables are single data-row, multi-column tables where each COLUMN
# is a metric (e.g. Host CPU: CPUs/Cores/Sockets/%User/%System/%WIO/%Idle;
# Instance CPU: %Total CPU/%Busy CPU/%DB time waiting for CPU (Resource
# Manager)) — the opposite shape from Instance Efficiency's row-per-metric
# layout, so this transposes columns -> metric/value rows rather than
# reading row-pairs, to stay consistent with the metric/value storage
# convention used by instance_efficiency_parser.py.
#
# Follows the same structure/conventions as instance_efficiency_parser.py
# and operating_system_statistics_parser.py so it's auto-discovered by
# master_parser.py's glob-based module scan (Interface 3: exec with
# __name__=="__main__", filepath injected as a global) — no registration
# needed elsewhere.

import os
import re
import sys
import hashlib
import pandas as pd
from bs4 import BeautifulSoup

# --- Import utils ---
sys.path.append(os.path.join(os.path.dirname(__file__), "..", "common"))
from db import get_db_connection
from utils import extract_workload_repo_metadata, clean_number
from logger_utils import get_logger
import io

# ----------------- Logging -----------------
log_dir = os.path.join(os.path.dirname(__file__), "..", "logs")
os.makedirs(log_dir, exist_ok=True)
logger = get_logger("host_instance_cpu_parser")


# ----------------- Helpers -----------------
def row_hash_func(row):
    h = hashlib.md5()
    h.update("|".join([str(x) for x in row]).encode("utf-8"))
    return h.hexdigest()


def _find_section_table(soup, *header_patterns):
    """Locate a section's table via h3 heading first (matches
    operating_system_statistics_parser.py's approach), falling back to a
    plain text-node search (matches instance_efficiency_parser.py's
    approach) for AWR report variants that don't wrap the label in <h3>.

    Real AWR HTML confirmed (2026-08-25, from Ganesh): "Host CPU" and
    "Instance CPU" are bare text nodes with no wrapping tag at all —
    literally `Host CPU<p /><table ...>` — not <h3> headers. The text-node
    fallback below is therefore the primary path for this section, not a
    rare fallback, so it uses a FULL match on the stripped node text
    (not a substring search) to avoid false-positives against any other
    incidental "CPU"/"Host" text elsewhere in a full-length report.
    """
    pattern = re.compile("^(" + "|".join(header_patterns) + ")$", re.IGNORECASE)

    header = soup.find("h3", string=lambda t: t and pattern.match(t.strip()))
    if header:
        table = header.find_next("table")
        if table:
            return table

    header_text = soup.find(string=lambda t: t and pattern.match(t.strip()))
    if header_text and hasattr(header_text, "find_next"):
        table = header_text.find_next("table")
        if table:
            return table

    return None


def _transpose_single_row_table(table, section_label, metadata):
    """Each column header in this table is a metric name; the single data
    row holds the values. Transpose into one record per metric, matching
    the metric/value storage shape already used by
    awr_instance_efficiency."""
    records = []
    try:
        df = pd.read_html(io.StringIO(str(table)))[0]
    except ValueError:
        logger.warning(f"⚠️ {section_label} table found but pandas could not parse it.")
        return records

    if df.empty:
        logger.warning(f"⚠️ {section_label} table is empty.")
        return records

    # Flatten MultiIndex columns if the header spans two HTML rows (some
    # AWR report variants render Host CPU's header as a two-row <thead>).
    if isinstance(df.columns, pd.MultiIndex):
        df.columns = [" ".join(str(c) for c in col if "Unnamed" not in str(c)).strip()
                      for col in df.columns]

    data_row = df.iloc[0]
    for metric, raw_val in data_row.items():
        metric_clean = str(metric).strip()
        if not metric_clean or metric_clean.lower().startswith("unnamed"):
            continue
        value = clean_number(raw_val)
        rec = {
            "dbname":     metadata["dbname"],
            "instance":   metadata["instance"],
            "instnum":    metadata["instnum"],
            "snap_time":  metadata["snap_time"],
            "section":    section_label,
            "metric":     metric_clean,
            "value":      value,
            "begin_snap": metadata["begin_snap"],
        }
        rec["row_hash"] = row_hash_func(list(rec.values()))
        records.append(rec)

    return records


# ----------------- Parser -----------------
def parse_host_instance_cpu(filepath):
    logger.info(f"🔍 Parsing Host CPU / Instance CPU sections from {filepath}")
    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f, "lxml")

    metadata = extract_workload_repo_metadata(soup)
    if not metadata:
        logger.error("❌ Failed to extract workload repo metadata.")
        return []

    records = []

    host_table = _find_section_table(soup, r"Host\s*CPU")
    if host_table is not None:
        host_recs = _transpose_single_row_table(host_table, "host", metadata)
        records.extend(host_recs)
        logger.info(f"✅ Extracted {len(host_recs)} Host CPU metric(s)")
    else:
        logger.warning("Host CPU section not found.")

    instance_table = _find_section_table(soup, r"Instance\s*CPU")
    if instance_table is not None:
        inst_recs = _transpose_single_row_table(instance_table, "instance", metadata)
        records.extend(inst_recs)
        logger.info(f"✅ Extracted {len(inst_recs)} Instance CPU metric(s)")
    else:
        logger.warning("Instance CPU section not found.")

    logger.info(f"✅ Extracted {len(records)} Host/Instance CPU rows total")
    return records


# ----------------- DB Insert -----------------
def insert_host_instance_cpu(records):
    if not records:
        logger.warning("No records to insert into awr_host_instance_cpu")
        return

    try:
        conn = get_db_connection()
        cur = conn.cursor()

        insert_query = """
            INSERT INTO awr_host_instance_cpu
            (dbname, instance, instnum, snap_time, section, metric, value, begin_snap, row_hash)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (dbname, instance, begin_snap, row_hash) DO NOTHING
        """

        inserted = 0
        for rec in records:
            try:
                cur.execute(insert_query, (
                    rec["dbname"], rec["instance"], rec["instnum"], rec["snap_time"],
                    rec["section"], rec["metric"], rec["value"], rec["begin_snap"],
                    rec["row_hash"]
                ))
                inserted += 1
            except Exception as e:
                logger.error(f"❌ Insert failed: {e}")

        conn.commit()
        cur.close()
        conn.close()
        logger.info(f"✅ Inserted {inserted} rows into awr_host_instance_cpu")

    except Exception as e:
        logger.error(f"❌ Database connection failed: {e}")


# ----------------- Main -----------------
if __name__ == "__main__":
    # When called via exec fallback from master_parser,
    # `filepath` is injected into globals
    _target = globals().get("filepath") or locals().get("filepath")
    if not _target:
        _target = sys.argv[1] if len(sys.argv) > 1 else None
    if _target:
        records = parse_host_instance_cpu(_target)
        insert_host_instance_cpu(records)
    else:
        logger.error("No filepath provided")
