# common/utils.py

import hashlib

import hashlib
import pandas as pd
import warnings
import math
 
# suppress pandas FutureWarnings globally
warnings.simplefilter(action="ignore", category=FutureWarning)

# --- Helper to compute row hash for uniqueness ---
def get_col(row, column_name, logger=None, context=""):
    """
    Look up a pandas Series/row value by column name, tolerating the AWR
    HTML quirks that cause exact-match KeyErrors:
      - non-breaking spaces (\\xa0) instead of regular spaces
      - leading/trailing whitespace
      - repeated internal whitespace collapsed differently

    Falls back to a normalized-whitespace match across the row's index if
    the exact key isn't found. Returns None (and logs a warning, if a
    logger is given) rather than raising, so one unexpected/renamed
    column degrades that single field instead of failing the whole file.
    """
    if column_name in row.index:
        return row[column_name]

    def _norm(s):
        return " ".join(str(s).replace("\xa0", " ").split()).strip().lower()

    target = _norm(column_name)
    for col in row.index:
        if _norm(col) == target:
            return row[col]

    if logger:
        logger.warning(f"⚠️ Column '{column_name}' not found{f' ({context})' if context else ''} — got columns: {list(row.index)}")
    return None


def row_hash(record: dict) -> str:
    """
    Compute an MD5 hash from the concatenated values of a record dict.
    """
    concat = "|".join([str(record.get(k, "")) for k in sorted(record.keys())])
    return hashlib.md5(concat.encode("utf-8")).hexdigest()


# --- Clean numeric strings (handles commas, spaces, etc.) ---
def clean_number(value):
    """
    Convert AWR numeric strings like '1,230,065.1' into float/int.
    Returns None if not numeric.
    """
    if value is None:
        return None
    try:
        return float(str(value).replace(",", "").strip())
    except Exception:
        return None

#---- convert to milisecs ----
def convert_to_ms(value: str) -> float:
    """Convert Avg Wait values into milliseconds (ms)."""
    if not value or value.strip() == "" or value.strip() == "&#160;":
        return None
    val = value.strip().lower().replace(",", "")
    try:
        if val.endswith("us"):
            return float(val.replace("us", "")) / 1000
        elif val.endswith("ms"):
            return float(val.replace("ms", ""))
        elif val.endswith("s"):
            return float(val.replace("s", "")) * 1000
        else:
            return float(val)
    except ValueError:
        return None

#---- convert to Megabytes ----
def convert_to_mb(value: str) -> float:
    """Convert Read/Write/Data per sec values into MB."""
    if not value:
        return None

    val = str(value).strip().replace(",", "").upper()

    try:
        if val.endswith("G"):
            return float(val.replace("G", "")) * 1024
        elif val.endswith("M"):
            return float(val.replace("M", ""))
        elif val.endswith("K"):
            return float(val.replace("K", "")) / 1024
        elif val == "0" or val == "0M":
            return 0
        else:
            return float(val)
    except Exception:
        return None

#---- convert to multiple of Thousand ----
def convert_to_thousand(value: str) -> float:
    """Convert Waits: Count values into number."""
    if not value:
        return None

    val = str(value).strip().replace(",", "").upper()

    try:
        if val.endswith("K"):
            return float(val.replace("K", "")) * 1000
        elif val.endswith("M"):
            return float(val.replace("M", "")) * 1000 * 1000
        elif val == "0" or val == "0K":            return 0
        else:
            return float(val)
    except Exception:
        return None

# --- This function will clean any NaN, empty string, or malformed values in a dictionary before DB insert ---

def sanitize_record(record):
    """Replace NaN or empty values with None for safe DB insertion."""
    for k, v in record.items():
        if pd.isna(v) or v in ("", "nan", "NaN", "None"):
            record[k] = None
    return record

# --- This function will gracefully skip any section that doesnt have any records -----
def is_section_empty(table: pd.DataFrame, section_name: str, module_name: str) -> bool:
    """
    Check if the table is empty (no records or only headers). If empty, log a warning and return True.
    """
    if table.empty or table.dropna(how="all").empty:
        logger.warning(f"⚠️ {section_name} section not found.")
        logger.warning(f"⚠️ No records to insert into {module_name}")
        return True
    return False

# --- Extract DB metadata from workload repository header ---
def extract_workload_repo_metadata(soup):
    """
    Extract dbname, instance, instnum, begin_snap, snap_time from AWR HTML.

    Handles Oracle AWR formats (with or without summary= attributes):
      Oracle 11g/12c : single table (DB Name | DB Id | Instance | Inst Num | ...)
      Oracle 19c+    : two tables (DB-level, then instance-level)
      Generated/test : plain <table border=1> under <h3>Database Summary</h3>
    """
    from io import StringIO

    metadata = {
        "dbname":     None,
        "instance":   None,
        "instnum":    None,
        "begin_snap": None,
        "snap_time":  None,
    }

    def _safe_str(v):
        s = str(v).strip()
        return None if s.lower() in ("nan", "none", "", "null") else s

    def _try_parse_df(df):
        """Try to pull dbname/instance/instnum from any DB-summary-style df."""
        if df is None or df.empty:
            return
        cols = [str(c).lower() for c in df.columns]
        row  = df.iloc[0]
        # Strategy 1: use column names to find fields
        for i, c in enumerate(cols):
            if c in ("db name", "dbname", "db_name") and metadata["dbname"] is None:
                metadata["dbname"] = _safe_str(row.iloc[i])
            if c in ("instance", "instance name", "inst name") and metadata["instance"] is None:
                metadata["instance"] = _safe_str(row.iloc[i])
            if ("inst num" in c or c in ("inst num", "inst_num", "instnum")) and metadata["instnum"] is None:
                try: metadata["instnum"] = int(float(str(row.iloc[i])))
                except: pass
        # Strategy 2: positional fallback (11g format: col0=dbname, col2=instance, col3=instnum)
        if metadata["dbname"] is None and len(row) > 0:
            metadata["dbname"] = _safe_str(row.iloc[0])
        if metadata["instance"] is None and len(row) > 2:
            metadata["instance"] = _safe_str(row.iloc[2])
        if metadata["instnum"] is None and len(row) > 3:
            try: metadata["instnum"] = int(float(str(row.iloc[3])))
            except: pass

    def _try_snap_df(df):
        """Extract begin_snap and snap_time from a snapshot-summary df."""
        if df is None or df.empty:
            return
        cols_l = [str(c).lower() for c in df.columns]
        for _, row in df.iterrows():
            vals = list(row)
            label = _safe_str(vals[0]) or ""
            label_l = label.lower()
            if "begin snap" in label_l:
                # Format A: Begin Snap | snap_id | snap_time
                try: metadata["begin_snap"] = int(float(str(vals[1])))
                except: pass
                if len(vals) > 2:
                    try:
                        ts = _safe_str(vals[2])
                        if ts:
                            metadata["snap_time"] = pd.to_datetime(ts, errors="coerce", dayfirst=True)
                    except: pass
                return
        # Format B: table header is Snap Id | Snap Time | ... (first data row = begin snap)
        snap_id_col = snap_time_col = None
        for i, c in enumerate(cols_l):
            if "snap" in c and ("id" in c or c == "snap id"):
                snap_id_col = i
            if "snap" in c and "time" in c:
                snap_time_col = i
        if snap_id_col is not None and not df.empty:
            row = df.iloc[0]
            try: metadata["begin_snap"] = int(float(str(row.iloc[snap_id_col])))
            except: pass
            if snap_time_col is not None:
                try:
                    ts = _safe_str(row.iloc[snap_time_col])
                    if ts:
                        metadata["snap_time"] = pd.to_datetime(ts, errors="coerce", dayfirst=True)
                except: pass

    try:
        # ── PATH 1: Oracle tables with summary= attribute ─────────────────
        inst_tables = soup.find_all(
            "table",
            summary="This table displays database instance information"
        )

        if len(inst_tables) >= 1:
            df1 = pd.read_html(StringIO(str(inst_tables[0])))[0]
            if len(inst_tables) == 1:
                _try_parse_df(df1)
            else:
                # 19c two-table format
                metadata["dbname"] = _safe_str(df1.iloc[0, 0]) if not df1.empty else None
                df2 = pd.read_html(StringIO(str(inst_tables[1])))[0]
                _try_parse_df(df2)
                # In 19c df2, instance is usually col0, instnum col1
                if metadata["dbname"] and metadata["instance"] is None and not df2.empty:
                    metadata["instance"] = _safe_str(df2.iloc[0, 0])

        snap_table = soup.find("table", summary="This table displays snapshot information")
        if snap_table is not None:
            _try_snap_df(pd.read_html(StringIO(str(snap_table)))[0])

        # ── PATH 2: Fallback — find by heading text (no summary= attribute) ─
        if metadata["dbname"] is None:
            for h in soup.find_all(["h2", "h3", "h4", "h5"]):
                htxt = h.get_text(strip=True).lower()
                if any(k in htxt for k in ("database summary", "db summary",
                                            "database instance information")):
                    # Look for the first table after this heading
                    sib = h.find_next_sibling()
                    while sib:
                        if getattr(sib, "name", None) == "table":
                            try:
                                df = pd.read_html(StringIO(str(sib)))[0]
                                _try_parse_df(df)
                                if metadata["dbname"]:
                                    break
                            except: pass
                        elif getattr(sib, "name", None) in ("h2", "h3"):
                            break
                        sib = sib.find_next_sibling()
                if metadata["dbname"]:
                    break

        if metadata["begin_snap"] is None:
            for h in soup.find_all(["h2", "h3", "h4", "h5"]):
                htxt = h.get_text(strip=True).lower()
                if any(k in htxt for k in ("snapshot summary", "snap summary",
                                            "snapshot information")):
                    sib = h.find_next_sibling()
                    while sib:
                        if getattr(sib, "name", None) == "table":
                            try:
                                df = pd.read_html(StringIO(str(sib)))[0]
                                _try_snap_df(df)
                                if metadata["begin_snap"]:
                                    break
                            except: pass
                        elif getattr(sib, "name", None) in ("h2", "h3"):
                            break
                        sib = sib.find_next_sibling()
                if metadata["begin_snap"]:
                    break

        # ── PATH 3: h1 title fallback — "DB: EXADB Snap: 25039–25040" ────
        if metadata["dbname"] is None or metadata["begin_snap"] is None:
            h1 = soup.find("h1")
            if h1:
                txt = h1.get_text(separator=" ", strip=True)
                # "DB: EXADB Snap: 25039–25040"
                import re as _re
                m_db  = _re.search(r"DB[:\s]+([A-Za-z0-9_]+)", txt)
                m_sn  = _re.search(r"Snap[:\s]+(\d+)", txt)
                m_ins = _re.search(r"Inst(?:ance)?[:\s]+([A-Za-z0-9_]+)", txt, _re.I)
                if m_db  and not metadata["dbname"]:
                    metadata["dbname"]  = m_db.group(1).strip()
                if m_ins and not metadata["instance"]:
                    metadata["instance"] = m_ins.group(1).strip()
                if m_sn  and not metadata["begin_snap"]:
                    try: metadata["begin_snap"] = int(m_sn.group(1))
                    except: pass

    except Exception as e:
        print(f"[utils.extract_workload_repo_metadata] Failed: {e}")

    return metadata

