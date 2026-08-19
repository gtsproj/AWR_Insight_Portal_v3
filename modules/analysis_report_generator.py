#!/usr/bin/env python3
"""
modules/analysis_report_generator.py
============================================================
Builds the data context for the AWR Analysis Report.
Queries tables already populated by the AWR upload pipeline.

Tables used:
  awr_db_info                — DB / host metadata
  awr_load_profile           — per-second workload metrics
  awr_os_statistics          — OS CPU / I/O stats → Host CPU %
  awr_foreground_wait_events — wait event breakdown
  awr_foreground_wait_class  — wait class summary
  awr_instance_efficiency    — buffer hit %, soft parse %, etc.
  awr_sql_elapsed_time       — top SQL by elapsed time
  awr_sql_text               — SQL text (hover previews)
  awr_seg_logical_reads      — top segments by logical reads
============================================================
"""

import os
import sys
from datetime import datetime, timezone

sys.path.append(os.path.join(os.path.dirname(__file__), "..", "common"))
from db import get_db_connection
from logger_utils import get_logger
from feature_flags import EXADATA_FEATURE_ENABLED

# recommendation_engine.py lives at the repo root, not in modules/ or common/
sys.path.append(os.path.join(os.path.dirname(__file__), ".."))

logger = get_logger("analysis_report_generator")


# ── Rules/AI mode recommendation integration ──────────────────────────────
# Mirrors the portal's Rules / Local AI / Cloud AI mode used elsewhere
# (AWR Intelligence dashboard, /ai-recommendations page): the 60+-rule
# engine in recommendation_engine.py always runs first regardless of mode
# (it's the "rules" data), and AI mode adds a narrative supplement on top
# of the rule findings — it does not replace them. Same design recommendation_engine.py
# itself documents and follows.
#
# IMPORTANT config-source note: recommendation_engine.py reads its own
# AI_MODE from config/settings.yaml at import time (common/config_loader.py)
# — a static file, separate from portal_config in the database. The
# Settings UI's AI Mode tab (and every other ai_mode check in this portal,
# including the Analysis Report picker's own ai_mode in ('local_ai','cloud_ai')
# checks) reads/writes portal_config via _get_config()/_set_config() in
# portal/app.py instead. Those two sources are not kept in sync. To make
# the Analysis Report actually follow the mode an admin selects in
# Settings, this integration reads portal_config directly (see
# _get_ai_settings() below) and does its own AI call using the same
# provider config keys portal/app.py's /api/ai/generate already uses,
# rather than trusting recommendation_engine.py's internal AI_MODE/
# _call_ollama/_call_anthropic (which would silently use settings.yaml's
# value instead of what the admin actually picked).

def _get_ai_settings(cur) -> dict:
    """Read AI mode + provider settings from portal_config — the same
    source the Settings UI's AI Mode tab writes to. Never raises."""
    try:
        cur.execute(
            "SELECT key, value FROM portal_config WHERE key IN "
            "('ai_mode','ai_local_url','ai_local_model',"
            "'ai_cloud_provider','ai_cloud_api_key','ai_cloud_model')"
        )
        cfg = {k: (v or "") for k, v in cur.fetchall()}
    except Exception as e:
        logger.warning(f"Could not read AI settings from portal_config: {e}")
        cfg = {}
    return {
        "ai_mode":          cfg.get("ai_mode", "rules") or "rules",
        "ai_local_url":     cfg.get("ai_local_url", "http://localhost:11434"),
        "ai_local_model":   cfg.get("ai_local_model", "llama3.1:8b"),
        "ai_cloud_provider":cfg.get("ai_cloud_provider", "claude"),
        "ai_cloud_api_key": cfg.get("ai_cloud_api_key", ""),
        "ai_cloud_model":   cfg.get("ai_cloud_model", ""),
    }


def _get_rule_engine_findings(dbname: str, instance: str,
                               begin_snap: int, end_snap: int) -> list:
    """Run the full 60+-rule engine (recommendation_engine.py) for this
    DB/snap range and return its findings list. Never raises — an import
    failure, missing table, or rule-file problem falls back to an empty
    list so the report still generates with its existing KPI-threshold
    hotspots/recommendations rather than failing outright."""
    try:
        from recommendation_engine import RecommendationEngine
        result = RecommendationEngine().evaluate(
            dbname=dbname, begin_snap=begin_snap, end_snap=end_snap,
            instance=instance)
        findings = result.get("findings", [])
        logger.info(f"Rule engine: {len(findings)} findings for {dbname} "
                    f"snaps {begin_snap}-{end_snap}")
        return findings
    except Exception as e:
        logger.warning(f"Rule engine evaluation failed, falling back to "
                        f"built-in hotspot/recommendation logic only: {e}")
        return []


def _call_ai_narrative(findings: list, dbname: str, instance: str,
                        snap_range: str, ai_settings: dict) -> dict:
    """Generate an AI narrative summary of the rule engine's top findings,
    using the SAME provider config the rest of the portal's AI features use
    (see _get_ai_settings). Returns {"text": ..., "provider": ..., "model": ...}
    — text is empty ("") in rules mode, on any failure, or with no findings,
    so callers never need special-case error handling; the report simply
    omits the AI panel. Bounded timeout so a slow/unreachable AI endpoint
    can't hang report generation indefinitely."""
    ai_mode = ai_settings["ai_mode"]
    empty = {"text": "", "provider": "", "model": ""}
    if ai_mode not in ("local_ai", "cloud_ai") or not findings:
        return empty

    top = findings[:6]
    prompt = (
        f"You are an Oracle DBA expert reviewing an AWR analysis for "
        f"database {dbname}/{instance} (snapshots {snap_range}). "
        f"The rule engine below already identified these findings — do not "
        f"repeat them verbatim. Instead, in 3-4 short paragraphs: "
        f"1) summarise the overall performance state in plain language, "
        f"2) call out the top 3 most urgent items in priority order and why, "
        f"3) note any cross-finding pattern (e.g. one root cause explaining "
        f"several findings). Be concise and factual — no generic filler.\n\n"
        f"Findings:\n" + _json_dumps_safe(top)
    )

    try:
        import urllib.request, json as _json
        if ai_mode == "local_ai":
            url   = (ai_settings["ai_local_url"] or "http://localhost:11434").rstrip("/")
            model = ai_settings["ai_local_model"] or "llama3.1:8b"
            payload = _json.dumps({
                "model": model, "prompt": prompt, "stream": False,
                "options": {"temperature": 0.3, "num_predict": 900},
            }).encode()
            req = urllib.request.Request(
                f"{url}/api/generate", data=payload,
                headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=45) as resp:
                text = _json.loads(resp.read()).get("response", "").strip()
            return {"text": text, "provider": "Local AI (Ollama)", "model": model} if text else empty

        elif ai_mode == "cloud_ai":
            provider = (ai_settings["ai_cloud_provider"] or "claude").lower()
            api_key  = ai_settings["ai_cloud_api_key"]
            model    = ai_settings["ai_cloud_model"]
            if not api_key:
                logger.info("Cloud AI selected but no API key configured — skipping AI narrative")
                return empty
            if provider == "openai":
                payload = _json.dumps({
                    "model": model or "gpt-4o-mini", "max_tokens": 900,
                    "temperature": 0.3,
                    "messages": [{"role": "user", "content": prompt}],
                }).encode()
                req = urllib.request.Request(
                    "https://api.openai.com/v1/chat/completions", data=payload,
                    headers={"Content-Type": "application/json",
                             "Authorization": f"Bearer {api_key}"})
                with urllib.request.urlopen(req, timeout=30) as resp:
                    text = _json.loads(resp.read())["choices"][0]["message"]["content"].strip()
                return {"text": text, "provider": "Cloud AI (OpenAI)", "model": model or "gpt-4o-mini"} if text else empty
            else:
                payload = _json.dumps({
                    "model": model or "claude-haiku-4-5", "max_tokens": 900,
                    "messages": [{"role": "user", "content": prompt}],
                }).encode()
                req = urllib.request.Request(
                    "https://api.anthropic.com/v1/messages", data=payload,
                    headers={"Content-Type": "application/json",
                             "x-api-key": api_key,
                             "anthropic-version": "2023-06-01"})
                with urllib.request.urlopen(req, timeout=30) as resp:
                    text = _json.loads(resp.read())["content"][0]["text"].strip()
                return {"text": text, "provider": "Cloud AI (Claude)", "model": model or "claude-haiku-4-5"} if text else empty
    except Exception as e:
        logger.warning(f"AI narrative call failed ({ai_mode}): {e}")
        return empty
    return empty


def _json_dumps_safe(obj) -> str:
    import json
    try:
        return json.dumps(obj, indent=2, default=str)
    except Exception:
        return str(obj)


# ── helpers ─────────────────────────────────────────────────────────────

def _fnum(v, default=0.0):
    try:
        return float(v)
    except (TypeError, ValueError):
        return default


def _find_metric(profile: dict, *keywords, exclude=None) -> float:
    exclude = exclude or []
    for label, val in profile.items():
        low = label.lower()
        if all(k in low for k in keywords) and not any(x in low for x in exclude):
            return _fnum(val)
    return 0.0


def _find_os_stat(stats: dict, *names) -> float:
    for name in names:
        for k, v in stats.items():
            if k.upper() == name.upper():
                return _fnum(v)
    return 0.0


def _sql_severity(pct: float) -> tuple:
    """Return (label, hex_color, bg_color) for a SQL's elapsed-time %."""
    if pct >= 30:
        return "CRITICAL", "#dc2626", "#fef2f2"
    if pct >= 15:
        return "HIGH",     "#ea580c", "#fff7ed"
    if pct >= 5:
        return "MEDIUM",   "#ca8a04", "#fefce8"
    return     "LOW",      "#16a34a", "#f0fdf4"


def _seg_severity(pct: float) -> tuple:
    """Return (label, hex_color) for a segment's logical-read share."""
    if pct >= 30:
        return "HOT",    "#dc2626", "#fef2f2"
    if pct >= 10:
        return "WARM",   "#ea580c", "#fff7ed"
    if pct >= 5:
        return "COOL",   "#ca8a04", "#fefce8"
    return     "NORMAL", "#16a34a", "#f0fdf4"


# ── discovery helpers ────────────────────────────────────────────────────

def get_available_dbs():
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT DISTINCT dbname FROM awr_load_profile ORDER BY dbname")
            return [r[0] for r in cur.fetchall()]
    finally:
        conn.close()


def get_instances(dbname: str):
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT DISTINCT instance FROM awr_load_profile
                WHERE dbname = %s ORDER BY instance
            """, (dbname,))
            return [r[0] for r in cur.fetchall()]
    finally:
        conn.close()


def get_snapshots(dbname: str, instance: str):
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT DISTINCT begin_snap,
                       to_char(snap_time, 'YYYY-MM-DD HH24:MI:SS') AS snap_time
                FROM awr_load_profile
                WHERE dbname = %s AND instance = %s
                ORDER BY begin_snap DESC
                LIMIT 200
            """, (dbname, instance))
            return [{"begin_snap": r[0], "snap_time": r[1]} for r in cur.fetchall()]
    finally:
        conn.close()


# ── main context builder ─────────────────────────────────────────────────

def build_report_context(dbname: str, instance: str, snap_ids: list) -> dict:
    if not snap_ids:
        raise ValueError("At least one snapshot must be selected")

    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            ph = ",".join(["%s"] * len(snap_ids))
            p  = [dbname, instance] + snap_ids

            # ── DB info ───────────────────────────────────────────────
            cur.execute("""
                SELECT edition, release, host_name, platform, cpu, cores, memory, rac, cdb
                FROM awr_db_info
                WHERE db_name=%s AND instance=%s
                ORDER BY created_at DESC LIMIT 1
            """, (dbname, instance))
            row = cur.fetchone()
            db_info = {
                "edition":  row[0] if row else "",
                "release":  row[1] if row else "",
                "host_name":row[2] if row else "",
                "platform": row[3] if row else "",
                "cpu":      row[4] if row else None,
                "cores":    row[5] if row else None,
                "memory":   float(row[6]) if row and row[6] else None,
                "rac":      row[7] if row else "",
                "cdb":      row[8] if row else "",
            } if row else {}

            # ── Load profile ─────────────────────────────────────────
            cur.execute(f"""
                SELECT begin_snap, snap_time, metric, per_sec
                FROM awr_load_profile
                WHERE dbname=%s AND instance=%s AND begin_snap IN ({ph})
                ORDER BY begin_snap
            """, p)
            lp_rows = cur.fetchall()

            per_snap_profile = {}
            snap_times = {}
            for bsnap, stime, metric, per_sec in lp_rows:
                per_snap_profile.setdefault(bsnap, {})[metric] = per_sec
                snap_times[bsnap] = stime

            snap_ids_sorted = sorted(per_snap_profile.keys())

            def agg(*keywords, exclude=None):
                vals = [_find_metric(per_snap_profile[s], *keywords, exclude=exclude)
                        for s in snap_ids_sorted]
                vals = [v for v in vals if v is not None]
                return sum(vals) / len(vals) if vals else 0.0

            # Both DB Time and DB CPU in same unit: seconds/second (s/s)
            # awr_load_profile.per_sec for 'DB Time(s)' is already s/s
            db_time_ss   = agg("db time")          # s/s — aggregate seconds per elapsed second
            db_cpu_ss    = agg("db cpu")            # s/s
            tps          = agg("transaction")
            logical_reads= agg("logical read")
            physical_reads=agg("physical read")
            hard_parses  = agg("hard pars")
            executes_ps  = agg("execut")

            # ── OS statistics → Host CPU % ────────────────────────────
            # Source: awr_os_statistics, derived from BUSY_TIME & IDLE_TIME
            # (populated by awr_os_statistics_parser.py from Oracle AWR
            #  or from SAR data when correlated with OS monitoring)
            cur.execute(f"""
                SELECT begin_snap, statistic, value
                FROM awr_os_statistics
                WHERE dbname=%s AND instance=%s AND begin_snap IN ({ph})
            """, p)
            per_snap_os = {}
            for bsnap, stat, val in cur.fetchall():
                per_snap_os.setdefault(bsnap, {})[stat] = val

            cpu_busy_pcts, io_wait_pcts = [], []
            for s in snap_ids_sorted:
                stats = per_snap_os.get(s, {})
                busy   = _find_os_stat(stats, "BUSY_TIME",   "AVG_BUSY_TIME")
                idle   = _find_os_stat(stats, "IDLE_TIME",   "AVG_IDLE_TIME")
                iowait = _find_os_stat(stats, "IOWAIT_TIME", "AVG_IOWAIT_TIME")
                total  = busy + idle
                if total > 0:
                    cpu_busy_pcts.append(round(busy   / total * 100, 1))
                    io_wait_pcts .append(round(iowait / total * 100, 1))

            host_cpu_busy = (sum(cpu_busy_pcts) / len(cpu_busy_pcts)
                             if cpu_busy_pcts else None)
            host_io_wait  = (sum(io_wait_pcts)  / len(io_wait_pcts)
                             if io_wait_pcts  else None)

            # ── Wait events (aggregated) ──────────────────────────────
            cur.execute(f"""
                SELECT event,
                       SUM(waits)             AS waits,
                       AVG(pct_db_time)       AS pct_db_time,
                       SUM(total_wait_time_s) AS total_wait_s
                FROM awr_foreground_wait_events
                WHERE dbname=%s AND instance=%s AND begin_snap IN ({ph})
                GROUP BY event
                ORDER BY pct_db_time DESC NULLS LAST
                LIMIT 10
            """, p)
            wait_events = [{
                "event":       r[0],
                "waits":       int(r[1] or 0),
                "pct_db_time": round(float(r[2] or 0), 1),
                "total_wait_s":round(float(r[3] or 0), 1),
            } for r in cur.fetchall()]
            # exclude header-only/blank rows
            wait_events = [e for e in wait_events if e["event"] and
                           e["event"].lower() not in ("event", "")]
            top_wait_event = wait_events[0]["event"] if wait_events else "N/A"

            # ── Wait class distribution ───────────────────────────────
            cur.execute(f"""
                SELECT wait_class, AVG(pct_db_time) AS pct_db_time
                FROM awr_foreground_wait_class
                WHERE dbname=%s AND instance=%s AND begin_snap IN ({ph})
                GROUP BY wait_class
                ORDER BY pct_db_time DESC NULLS LAST
                LIMIT 8
            """, p)
            wait_classes = [{"wait_class": r[0],
                             "pct_db_time": round(float(r[1] or 0), 1)}
                            for r in cur.fetchall()]

            # ── Cache / instance efficiency ───────────────────────────
            cur.execute(f"""
                SELECT metric, AVG(value)
                FROM awr_instance_efficiency
                WHERE dbname=%s AND instance=%s AND begin_snap IN ({ph})
                GROUP BY metric
            """, p)
            eff = {r[0]: round(float(r[1] or 0), 2) for r in cur.fetchall()}

            def eff_pick(*kws):
                for k, v in eff.items():
                    if all(kw in k.lower() for kw in kws):
                        return v
                return None

            cache_ratios = {
                "buffer_hit":    eff_pick("buffer", "hit"),
                "library_hit":   eff_pick("library", "hit"),
                "soft_parse":    eff_pick("soft", "pars"),
                "buffer_nowait": eff_pick("buffer", "nowait") or
                                 eff_pick("buffer", "no wait"),
                "execute_to_parse": eff_pick("execute", "parse"),
                "pct_non_parse_cpu":eff_pick("non-parse") or eff_pick("non parse"),
            }

            # ── Top SQL — joined across SQL stat tables ──────────────────
            # awr_sql_cpu_time has the real cpu_time_s column
            # awr_sql_gets/reads add buffer gets and physical reads per exec
            cur.execute(f"""
                SELECT
                    e.sql_id,
                    e.sql_module,
                    SUM(e.executions)                        AS execs,
                    SUM(e.elapsed_time_s)                    AS total_elapsed,
                    SUM(COALESCE(c.cpu_time_s,
                        e.elapsed_time_s * e.pct_cpu / 100.0)) AS total_cpu,
                    AVG(e.elapsed_time_per_exec_s)           AS avg_elapsed,
                    AVG(COALESCE(g.gets_per_exec, 0))        AS avg_gets,
                    AVG(COALESCE(r.reads_per_exec, 0))       AS avg_reads
                FROM awr_sql_elapsed_time e
                LEFT JOIN awr_sql_cpu_time c
                    ON c.sql_id=e.sql_id AND c.dbname=e.dbname
                    AND c.begin_snap=e.begin_snap AND c.instance=e.instance
                LEFT JOIN awr_sql_gets g
                    ON g.sql_id=e.sql_id AND g.dbname=e.dbname
                    AND g.begin_snap=e.begin_snap AND g.instance=e.instance
                LEFT JOIN awr_sql_reads r
                    ON r.sql_id=e.sql_id AND r.dbname=e.dbname
                    AND r.begin_snap=e.begin_snap AND r.instance=e.instance
                WHERE e.dbname=%s AND e.instance=%s AND e.begin_snap IN ({ph})
                GROUP BY e.sql_id, e.sql_module
                ORDER BY total_elapsed DESC NULLS LAST
                LIMIT 15
            """, p)
            sql_rows = cur.fetchall()
            total_elapsed_all = sum(_fnum(r[3]) for r in sql_rows) or 1.0

            # Plan stability proxy: variance in elapsed_per_exec across snaps
            plan_unstable_ids = set()
            try:
                cur.execute(f"""
                    SELECT sql_id,
                           STDDEV(elapsed_time_per_exec_s) AS stddev_e,
                           AVG(elapsed_time_per_exec_s)    AS avg_e
                    FROM awr_sql_elapsed_time
                    WHERE dbname=%s AND instance=%s AND begin_snap IN ({ph})
                    GROUP BY sql_id
                    HAVING AVG(elapsed_time_per_exec_s) > 0
                       AND STDDEV(elapsed_time_per_exec_s) /
                           NULLIF(AVG(elapsed_time_per_exec_s), 0) > 0.5
                """, p)
                plan_unstable_ids = {r[0] for r in cur.fetchall()}
            except Exception:
                pass

            top_sql = []
            for row in sql_rows:
                sql_id, module = row[0], row[1]
                execs    = _fnum(row[2])
                total_e  = _fnum(row[3])
                total_c  = _fnum(row[4])
                avg_e    = _fnum(row[5])
                avg_gets = _fnum(row[6])
                avg_reads= _fnum(row[7])
                pct      = round(total_e / total_elapsed_all * 100, 1)
                sev_label, sev_color, sev_bg = _sql_severity(pct)
                top_sql.append({
                    "sql_id":          sql_id,
                    "module":          module or "",
                    "executions":      int(execs),
                    "total_elapsed":   round(total_e, 1),
                    "total_cpu":       round(total_c, 1),
                    "elapsed_per_exec":round(avg_e, 3),
                    "cpu_per_exec":    round(total_c / execs, 3) if execs else 0,
                    "avg_gets":        round(avg_gets, 0),
                    "avg_reads":       round(avg_reads, 0),
                    "pct_total":       pct,
                    "severity":        sev_label,
                    "sev_color":       sev_color,
                    "sev_bg":          sev_bg,
                    "plan_unstable":   sql_id in plan_unstable_ids,
                })

            # SQL text
            sql_texts = {}
            if top_sql:
                sql_ids = [s["sql_id"] for s in top_sql]
                cur.execute(f"""
                    SELECT DISTINCT ON (sql_id) sql_id, sql_text
                    FROM awr_sql_text
                    WHERE dbname=%s AND sql_id IN ({','.join(['%s']*len(sql_ids))})
                """, [dbname] + sql_ids)
                sql_texts = {r[0]: (r[1] or "")[:200] for r in cur.fetchall()}
            for s in top_sql:
                s["sql_text_preview"] = sql_texts.get(s["sql_id"], "")

            # SQL severity summary
            sev_counts = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0}
            for s in top_sql:
                sev_counts[s["severity"]] = sev_counts.get(s["severity"], 0) + 1

            # ── Top segments — with severity + % ─────────────────────
            cur.execute(f"""
                SELECT owner, object_name, obj_type, SUM(logical_reads) AS lr
                FROM awr_seg_logical_reads
                WHERE dbname=%s AND instance=%s AND begin_snap IN ({ph})
                GROUP BY owner, object_name, obj_type
                ORDER BY lr DESC NULLS LAST
                LIMIT 15
            """, p)
            seg_rows = cur.fetchall()
            total_lr_all = sum(_fnum(r[3]) for r in seg_rows) or 1

            top_objects = []
            for owner, obj_name, obj_type, lr in seg_rows:
                lr  = int(_fnum(lr))
                pct = round(lr / total_lr_all * 100, 1)
                sev_label, sev_color, sev_bg = _seg_severity(pct)
                top_objects.append({
                    "owner":        owner,
                    "object_name":  obj_name,
                    "obj_type":     obj_type or "",
                    "logical_reads":lr,
                    "pct_total":    pct,
                    "severity":     sev_label,
                    "sev_color":    sev_color,
                    "sev_bg":       sev_bg,
                })

            seg_sev_counts = {"HOT": 0, "WARM": 0, "COOL": 0, "NORMAL": 0}
            for o in top_objects:
                seg_sev_counts[o["severity"]] = seg_sev_counts.get(o["severity"], 0) + 1

            # ── Per-snapshot cards + trend series ─────────────────────
            snapshot_cards = []
            trend = {"labels": [], "db_time": [], "db_cpu": [], "tps": [],
                     "hard_parses": [], "physical_reads": [], "host_cpu": [],
                     "logical_reads": []}

            for idx, s in enumerate(snap_ids_sorted):
                prfl     = per_snap_profile.get(s, {})
                s_dt_ss  = _find_metric(prfl, "db time")
                s_cpu_ss = _find_metric(prfl, "db cpu")
                s_tps    = _find_metric(prfl, "transaction")
                s_lr     = _find_metric(prfl, "logical read")
                s_pr     = _find_metric(prfl, "physical read")
                s_hp     = _find_metric(prfl, "hard pars")
                s_cpu_busy = cpu_busy_pcts[idx] if idx < len(cpu_busy_pcts) else None

                snap_time_str = str(snap_times.get(s, ""))
                # Short label for charts: "HH:MM" or date if multi-day
                try:
                    dt = datetime.fromisoformat(snap_time_str)
                    short_lbl = dt.strftime("%H:%M")
                except Exception:
                    short_lbl = str(s)

                snapshot_cards.append({
                    "snap_id":      s,
                    "snap_time":    snap_time_str,
                    "short_label":  short_lbl,
                    "db_time_ss":   round(s_dt_ss,  2),
                    "db_cpu_ss":    round(s_cpu_ss, 2),
                    "tps":          round(s_tps,    1),
                    "logical_reads":round(s_lr,     0),
                    "physical_reads":round(s_pr,    0),
                    "hard_parses":  round(s_hp,     1),
                    "host_cpu_pct": s_cpu_busy,
                })

                trend["labels"].append(short_lbl)
                trend["db_time"].append(round(s_dt_ss,  2))
                trend["db_cpu"].append(round(s_cpu_ss, 2))
                trend["tps"].append(round(s_tps,   1))
                trend["hard_parses"].append(round(s_hp, 1))
                trend["physical_reads"].append(round(s_pr, 0))
                trend["host_cpu"].append(s_cpu_busy or 0)
                trend["logical_reads"].append(round(s_lr, 0))

            # ── Load profile comparison table ─────────────────────────
            load_profile_table = []
            for label, kw, unit in [
                ("DB Time (s/s)",     ["db time"],       "s/s"),
                ("DB CPU (s/s)",      ["db cpu"],        "s/s"),
                ("Transactions/s",    ["transaction"],   "/s"),
                ("Executes/s",        ["execut"],        "/s"),
                ("Logical reads/s",   ["logical read"],  "/s"),
                ("Physical reads/s",  ["physical read"], "/s"),
                ("Hard parses/s",     ["hard pars"],     "/s"),
                ("Parses/s",          ["pars"],          "/s"),
            ]:
                row_vals = []
                for s in snap_ids_sorted:
                    v = _find_metric(per_snap_profile.get(s, {}), *kw)
                    row_vals.append(round(v, 2))
                # Peak and delta
                non_zero = [v for v in row_vals if v > 0]
                peak = max(non_zero) if non_zero else 0
                load_profile_table.append({
                    "label": label, "unit": unit,
                    "vals":  row_vals, "peak": peak,
                })

        # ── Exadata-specific data ────────────────────────────────
        # Step 0: Master switch — see common/feature_flags.py. While the
        #         Exadata parsers are paused, force exa_licensed False here
        #         regardless of the portal_config DB value, so no Exadata
        #         hotspots/recommendations/sections can leak into the report
        #         even if that config value is still 'true' from earlier.
        # Step 1: Read license_exadata from portal_config.
        # Step 2: Only if both the master switch is on AND licensed, call
        #         _fetch_exadata_context which then also auto-detects
        #         whether any Exadata data exists for these snaps.
        exa_licensed = False
        if not EXADATA_FEATURE_ENABLED:
            logger.info("Exadata feature disabled (EXADATA_FEATURE_ENABLED=False) — skipping Exadata table queries")
        else:
            try:
                cur.execute(
                    "SELECT value FROM portal_config "
                    "WHERE key='license_exadata' LIMIT 1"
                )
                _lic_row = cur.fetchone()
                if _lic_row:
                    _lic_val = str(_lic_row[0] or "").strip().lower()
                    exa_licensed = (_lic_val == "true")
                    logger.debug(f"license_exadata from portal_config: '{_lic_val}' → exa_licensed={exa_licensed}")
                else:
                    logger.debug("license_exadata key not found in portal_config — defaulting to False")
            except Exception as _lic_err:
                logger.warning(f"Could not read license_exadata from portal_config: {_lic_err}")
                exa_licensed = False

        if exa_licensed:
            logger.info(f"Exadata licensed — fetching from 14 Exadata tables for {dbname}")
            exa_ctx = _fetch_exadata_context(cur, dbname, instance,
                                              snap_ids_sorted, ph, p)
            logger.info(f"Exadata fetch complete: is_exadata={exa_ctx.get('is_exadata')}")
        else:
            logger.info(f"Exadata not licensed — skipping Exadata table queries for {dbname}")
            exa_ctx = {"is_exadata": False, "license_disabled": True}

        # ── I/O Profile from awr_iostat_function ─────────────────────
        io_profile = []
        try:
            cur.execute(f"""
                SELECT function_name,
                       AVG(reads_reqs_per_sec)    AS avg_read_rps,
                       AVG(reads_data_per_sec_mb) AS avg_read_mbps,
                       AVG(writes_reqs_per_sec)   AS avg_write_rps,
                       AVG(writes_data_per_sec_mb)AS avg_write_mbps,
                       AVG(avg_time_ms)            AS avg_latency_ms
                FROM awr_iostat_function
                WHERE dbname=%s AND instance=%s AND begin_snap IN ({ph})
                GROUP BY function_name
                ORDER BY avg_read_rps DESC NULLS LAST
            """, p)
            io_profile = [{
                "function_name":  r[0],
                "avg_read_rps":   round(float(r[1] or 0), 1),
                "avg_read_mbps":  round(float(r[2] or 0), 1),
                "avg_write_rps":  round(float(r[3] or 0), 1),
                "avg_write_mbps": round(float(r[4] or 0), 1),
                "avg_latency_ms": round(float(r[5] or 0), 2),
            } for r in cur.fetchall()]
        except Exception as e:
            logger.warning(f"IO profile fetch: {e}")

        # ── Parsing pressure from load profile ────────────────────────
        # exclude="hard" so this can never accidentally match the "Hard
        # Parses (SQL)" row instead of "Parses (SQL)" — both labels contain
        # the substring "pars", and _find_metric returns on first match, so
        # without the exclusion this depended on incidental row order.
        parses_ps   = agg("pars", exclude=["hard"])
        hard_ps     = agg("hard pars")
        parse_eff   = round((parses_ps - hard_ps) / parses_ps * 100, 1) if parses_ps > 0 else 100.0

        # ── Redo sizing from load profile ─────────────────────────────
        redo_size_ps = agg("redo size")   # bytes/s
        redo_mb_ps   = round(redo_size_ps / (1024*1024), 2) if redo_size_ps > 0 else 0
        # Recommended log size = redo MB/s × 1200 s (20-min switch target),
        # capped at a practical maximum. A single Oracle redo log file sized
        # in the tens of GB (which the raw 20-min-target formula produces on
        # high-redo-rate systems) is not a realistic recommendation — no DBA
        # would size a redo log that large. Past the cap, the right guidance
        # is to add more log GROUPS at the capped size (accepting more
        # frequent switches) rather than one oversized file — see
        # redo_switches_per_hour below, shown in the report when capped.
        MAX_REDO_LOG_MB = 3072  # 3 GB — practical upper bound for one redo log file
        _raw_recommended_log_mb = round(redo_mb_ps * 1200, 0) if redo_mb_ps > 0 else None
        recommended_log_mb = (min(_raw_recommended_log_mb, MAX_REDO_LOG_MB)
                               if _raw_recommended_log_mb else None)
        redo_log_capped = bool(_raw_recommended_log_mb
                                and _raw_recommended_log_mb > MAX_REDO_LOG_MB)
        # Switches/hour implied by the (possibly capped) recommended size —
        # only meaningful to show when the cap actually changed the number.
        redo_switches_per_hour = (
            round(redo_size_ps * 3600 / (recommended_log_mb * 1024 * 1024), 1)
            if recommended_log_mb else None)

        # ── Session activity per snap ─────────────────────────────────
        user_calls_ps = agg("user call")
        db_cpu_count  = db_info.get("cpu") or 1

        # ── Health Score (0–100 RAG composite) ────────────────────────
        host_cpu_v   = host_cpu_busy or 50
        buf_hit_v    = (cache_ratios.get("buffer_hit") or 90)
        top_wait_pct = wait_events[0]["pct_db_time"] if wait_events else 50
        hard_p_v     = hard_parses or 0

        cpu_pts   = max(0, 25.0 * (1 - host_cpu_v  / 100))
        cache_pts = max(0, 25.0 * min(buf_hit_v / 100, 1.0))
        wait_pts  = max(0, 25.0 * (1 - top_wait_pct / 100))
        parse_pts = max(0, 25.0 * (1 - min(hard_p_v / 50, 1.0)))
        health_score = round(cpu_pts + cache_pts + wait_pts + parse_pts, 1)
        if   health_score >= 75: health_rag, health_color = "GREEN", "#16a34a"
        elif health_score >= 50: health_rag, health_color = "AMBER", "#ca8a04"
        else:                    health_rag, health_color = "RED",   "#dc2626"

        health = {
            "score":  health_score,
            "rag":    health_rag,
            "color":  health_color,
            "cpu_pts":   round(cpu_pts,  1),
            "cache_pts": round(cache_pts,1),
            "wait_pts":  round(wait_pts, 1),
            "parse_pts": round(parse_pts,1),
        }

        # ── Plan stability summary ────────────────────────────────────
        plan_unstable_sqls = [s for s in top_sql if s.get("plan_unstable")]

        # ── Rules/AI mode settings (read while cur is still open) ──────
        ai_settings = _get_ai_settings(cur)

    finally:
        conn.close()

    is_multi = len(snap_ids_sorted) > 1

    # Snap date range for filename
    first_date = ""
    try:
        first_date = str(snap_times.get(snap_ids_sorted[0], "")).split(" ")[0]
    except Exception:
        pass
    snap_range_str = (f"{snap_ids_sorted[0]}-{snap_ids_sorted[-1]}"
                      if len(snap_ids_sorted) > 1 else str(snap_ids_sorted[0]))
    pdf_filename = (
        f"AWR_Analysis_{dbname}_{instance}"
        f"{'_' + first_date if first_date else ''}"
        f"_Snaps_{snap_range_str}"
    )

    # ── Rule engine (always) + AI narrative (local_ai/cloud_ai only) ───
    # See the module-level comment near _get_ai_settings() for why this
    # reads portal_config directly instead of trusting
    # recommendation_engine.py's own settings.yaml-based AI_MODE.
    rule_findings = _get_rule_engine_findings(
        dbname, instance, snap_ids_sorted[0], snap_ids_sorted[-1])
    ai_narrative = _call_ai_narrative(
        rule_findings, dbname, instance, snap_range_str, ai_settings)

    context = {
        "dbname": dbname, "instance": instance,
        "db_info": db_info,
        "snapshot_count": len(snap_ids_sorted),
        "is_multi": is_multi,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "pdf_filename": pdf_filename,
        "snap_id_list": snap_ids_sorted,
        "snap_times": {str(k): str(v) for k, v in snap_times.items()},
        "kpi": {
            "db_time_ss":    round(db_time_ss,    2),
            "db_cpu_ss":     round(db_cpu_ss,     2),
            "tps":           round(tps,            1),
            "logical_reads": round(logical_reads,  0),
            "physical_reads":round(physical_reads, 0),
            "hard_parses":   round(hard_parses,    1),
            "executes_ps":   round(executes_ps,    1),
            "host_cpu_busy": round(host_cpu_busy, 1) if host_cpu_busy is not None else None,
            "host_io_wait":  round(host_io_wait,  1) if host_io_wait  is not None else None,
        },
        "wait_events":   wait_events,
        "top_wait_event":top_wait_event,
        "wait_classes":  wait_classes,
        "cache_ratios":  cache_ratios,
        "top_sql":       top_sql,
        "sql_sev_counts":sev_counts,
        "top_objects":   top_objects,
        "seg_sev_counts":seg_sev_counts,
        "snapshot_cards":snapshot_cards,
        "trend":         trend,
        "load_profile_table": load_profile_table,
    }
    context["exadata"]         = exa_ctx
    context["exa_licensed"]    = exa_licensed

    # Exadata wait event interpretation map — annotates generic wait events
    # with Exadata-specific meaning when shown for Exadata databases
    context["exa_wait_map"] = {
        "cell smart table scan": {
            "type": "Smart Scan",
            "icon": "🟢",
            "meaning": "Smart Scan IO — cell offloading eligible rows/blocks. "
                       "High % is EXPECTED for analytics workloads on Exadata. "
                       "Check Smart IO passthru% if response time is poor.",
            "action": "Verify Smart Scan is serving from Flash Cache (not disk). "
                      "Check awr_exadata_smart_io for flash_mb vs disk_mb ratio.",
        },
        "cell smart table scan: passthru": {
            "type": "Smart Scan Passthru",
            "icon": "🔴",
            "meaning": "Smart Scan rows NOT offloaded — returning full blocks to "
                       "the DB server instead. High passthru% degrades Smart Scan "
                       "benefit and increases network + DB CPU.",
            "action": "Check for CELL_FLASH_CACHE NONE hints, encryption on columns, "
                      "or compressed tables with incompatible algorithms.",
        },
        "cell single block physical read": {
            "type": "Sequential Read",
            "icon": "🔵",
            "meaning": "OLTP-style index-range scan or single-block fetch from "
                       "Exadata cell. Should be served from Flash Cache. "
                       "High latency here suggests Flash Cache miss or flushing.",
            "action": "Check FC OLTP hit% in awr_exadata_perf_summary. "
                      "If < 80%, Flash Cache may be undersized or flushing.",
        },
        "cell multiblock read request": {
            "type": "Large Read",
            "icon": "🔵",
            "meaning": "Full-scan or large index read from cell. Expected during "
                       "analytics. High counts alongside high passthru suggest "
                       "Smart Scan is not being invoked for eligible queries.",
            "action": "Review session parameter CELL_OFFLOAD_PROCESSING. "
                      "Ensure statistics are current for tables driving large reads.",
        },
        "cell list of blocks physical read": {
            "type": "List-of-Blocks Read",
            "icon": "🔵",
            "meaning": "Clustered index or bitmap scan reading specific blocks. "
                       "Normal for star-schema queries. Should be Flash-cached.",
            "action": "Verify Flash Cache FC hit% is adequate for index workloads.",
        },
        "cell smart index scan": {
            "type": "Smart Index Scan",
            "icon": "🟢",
            "meaning": "Exadata offloaded index scan — reads index blocks from "
                       "cell with storage-side filtering. Good for range scans.",
            "action": "Expected wait — confirm index is effectively selective.",
        },
    }
    context["io_profile"]   = io_profile
    context["health"]       = health
    context["parse_eff"]    = parse_eff
    context["parses_ps"]    = round(parses_ps, 1)
    context["hard_ps"]      = round(hard_ps, 1)
    context["redo_mb_ps"]   = redo_mb_ps
    context["recommended_log_mb"] = recommended_log_mb
    context["redo_log_capped"] = redo_log_capped
    context["redo_switches_per_hour"] = redo_switches_per_hour
    context["user_calls_ps"]= round(user_calls_ps, 1)
    context["plan_unstable_sqls"] = plan_unstable_sqls
    context["ai_mode"]      = ai_settings["ai_mode"]
    context["rule_findings"]= rule_findings
    context["ai_narrative"] = ai_narrative
    context["conclusion"] = build_conclusion(context)
    return context




# ── Exadata-specific context ─────────────────────────────────────────────

def _fetch_exadata_context(cur, dbname: str, instance: str,
                            snap_ids: list, ph: str = None, p: list = None) -> dict:
    """
    Fetch Exadata-specific metrics from Wave 1+2 tables.
    ph and p are rebuilt internally from snap_ids to avoid
    length-mismatch errors when snap_ids_sorted < user-selected ids.
    """
    exa = {"is_exadata": False}
    # Always rebuild ph from the actual snap_ids passed in — never trust external ph
    snap_ids = list(snap_ids)
    _ph = ",".join(["%s"] * len(snap_ids))   # local placeholder string

    try:
        # ── Detect Exadata data presence ─────────────────────────────
        cur.execute(
            f"SELECT COUNT(*) FROM awr_exadata_perf_summary "
            f"WHERE dbname=%s AND begin_snap IN ({_ph})",
            [dbname] + snap_ids)
        cnt = (cur.fetchone() or [0])[0]
        logger.debug(f"awr_exadata_perf_summary count for {dbname} snaps={snap_ids}: {cnt}")
        if cnt == 0:
            logger.info(f"No Exadata data in awr_exadata_perf_summary for {dbname} — "
                        f"is_exadata=False (run reparse_exadata.py if data should exist)")
            return exa
        exa["is_exadata"] = True

        # ── Wave 1: Performance Summary (averaged across snaps) ───────
        cur.execute(f"""
            SELECT
              AVG(fc_pct)         AS avg_fc_pct,
              AVG(xrmem_pct)      AS avg_xrmem_pct,
              AVG(rdma_pct)       AS avg_rdma_pct,
              AVG(oltp_hit_pct)   AS avg_oltp_hit,
              AVG(scan_hit_pct)   AS avg_scan_hit,
              SUM(read_skips)     AS total_read_skips,
              AVG(scrub_mbps)     AS avg_scrub_mbps,
              SUM(read_misses)    AS total_read_misses
            FROM awr_exadata_perf_summary
            WHERE dbname=%s AND begin_snap IN ({_ph})
        """, [dbname] + snap_ids)
        ps = cur.fetchone()
        exa["perf_summary"] = {
            "avg_fc_pct":      round(float(ps[0] or 0), 1),
            "avg_xrmem_pct":   round(float(ps[1] or 0), 1),
            "avg_rdma_pct":    round(float(ps[2] or 0), 1),
            "avg_oltp_hit":    round(float(ps[3] or 0), 1),
            "avg_scan_hit":    round(float(ps[4] or 0), 1),
            "total_read_skips":int(ps[5] or 0),
            "avg_scrub_mbps":  round(float(ps[6] or 0), 1),
            "total_read_misses":int(ps[7] or 0),
        } if ps else {}

        # ── Wave 1: FC Config — flushing cells ───────────────────────
        cur.execute(f"""
            SELECT cell_name, is_flushing, flash_cache_size_gb
            FROM awr_exadata_fc_config
            WHERE dbname=%s AND begin_snap IN ({_ph})
            ORDER BY cell_name
        """, [dbname] + snap_ids)
        fc_cfg_rows = cur.fetchall()
        # Unique cells, flagging any that were ever flushing
        cell_status = {}
        for cell, flushing, size in fc_cfg_rows:
            if cell not in cell_status:
                cell_status[cell] = {"cell_name": cell, "is_flushing": False,
                                     "size_gb": float(size or 0)}
            if flushing:
                cell_status[cell]["is_flushing"] = True
        exa["fc_config"]     = list(cell_status.values())
        exa["flushing_cells"]= [c["cell_name"] for c in exa["fc_config"] if c["is_flushing"]]

        # ── Wave 1: Smart IO — aggregated across cells+snaps ─────────
        cur.execute(f"""
            SELECT cell_name,
              AVG(eligible_mb)    AS avg_eligible,
              AVG(si_savings_mb)  AS avg_si_savings,
              AVG(flash_mb)       AS avg_flash,
              AVG(disk_mb)        AS avg_disk,
              AVG(passthru_mb)    AS avg_passthru,
              AVG(passthru_pct)   AS avg_passthru_pct,
              AVG(disk_pct)       AS avg_disk_pct
            FROM awr_exadata_smart_io
            WHERE dbname=%s AND begin_snap IN ({_ph})
            GROUP BY cell_name
            ORDER BY cell_name
        """, [dbname] + snap_ids)
        exa["smart_io"] = [{
            "cell_name":      r[0],
            "avg_eligible":   round(float(r[1] or 0), 0),
            "avg_si_savings": round(float(r[2] or 0), 0),
            "avg_flash":      round(float(r[3] or 0), 0),
            "avg_disk":       round(float(r[4] or 0), 0),
            "avg_passthru":   round(float(r[5] or 0), 0),
            "avg_passthru_pct": round(float(r[6] or 0), 1),
            "avg_disk_pct":   round(float(r[7] or 0), 1),
        } for r in cur.fetchall()]

        # Compute total-level SI savings %
        all_elig   = sum(r["avg_eligible"]   for r in exa["smart_io"] if r["cell_name"] != "All")
        all_si     = sum(r["avg_si_savings"] for r in exa["smart_io"] if r["cell_name"] != "All")
        exa["si_savings_pct"] = round(all_si / all_elig * 100, 1) if all_elig > 0 else 0

        # ── Wave 1: FC Reads — per-cell hit% ─────────────────────────
        cur.execute(f"""
            SELECT cell_name, io_type,
              AVG(hit_pct) AS avg_hit
            FROM awr_exadata_fc_reads
            WHERE dbname=%s AND begin_snap IN ({_ph})
            GROUP BY cell_name, io_type
            ORDER BY cell_name, io_type
        """, [dbname] + snap_ids)
        fc_reads_raw = cur.fetchall()
        fc_reads_by_cell = {}
        for cell, io_type, hit in fc_reads_raw:
            fc_reads_by_cell.setdefault(cell, {})
            fc_reads_by_cell[cell][io_type] = round(float(hit or 0), 1)
        exa["fc_reads"] = [{"cell_name": c, "hits": v}
                           for c, v in sorted(fc_reads_by_cell.items())]

        # ── Wave 2: Top DB — IORM queue time ─────────────────────────
        cur.execute(f"""
            SELECT AVG(iorm_queue_ms)     AS avg_iorm,
                   MAX(iorm_queue_ms)     AS max_iorm,
                   AVG(small_avg_lat_ms)  AS avg_small_lat,
                   AVG(large_avg_lat_ms)  AS avg_large_lat,
                   AVG(flash_req_pct)     AS avg_flash_req,
                   AVG(disk_req_pct)      AS avg_disk_req
            FROM awr_exadata_top_db
            WHERE dbname=%s AND begin_snap IN ({_ph})
        """, [dbname] + snap_ids)
        td = cur.fetchone()
        exa["top_db"] = {
            "avg_iorm_ms":   round(float(td[0] or 0), 1),
            "max_iorm_ms":   round(float(td[1] or 0), 1),
            "avg_small_lat": round(float(td[2] or 0), 1),
            "avg_large_lat": round(float(td[3] or 0), 1),
            "avg_flash_req": round(float(td[4] or 0), 1),
            "avg_disk_req":  round(float(td[5] or 0), 1),
        } if td and td[0] is not None else {}

        # ── Wave 2: Cell IOStat — outlier / max capacity cells ────────
        cur.execute(f"""
            SELECT cell_name,
              AVG(iops) AS avg_iops,
              AVG(util_pct) AS avg_util,
              BOOL_OR(is_outlier) AS ever_outlier,
              BOOL_OR(at_max_capacity) AS ever_maxcap
            FROM awr_exadata_cell_iostat
            WHERE dbname=%s AND begin_snap IN ({_ph})
            GROUP BY cell_name
            ORDER BY avg_iops DESC NULLS LAST
        """, [dbname] + snap_ids)
        exa["cell_iostat"] = [{
            "cell_name":    r[0],
            "avg_iops":     round(float(r[1] or 0), 0),
            "avg_util":     round(float(r[2] or 0), 1),
            "ever_outlier": bool(r[3]),
            "ever_maxcap":  bool(r[4]),
        } for r in cur.fetchall()]
        exa["outlier_cells"] = [c["cell_name"] for c in exa["cell_iostat"] if c["ever_outlier"]]
        exa["maxcap_cells"]  = [c["cell_name"] for c in exa["cell_iostat"] if c["ever_maxcap"]]

        # ── Wave 2: IO Reasons — All-cell aggregate ───────────────────
        cur.execute(f"""
            SELECT reason,
              SUM(total_req) AS total_req,
              SUM(total_mb)  AS total_mb
            FROM awr_exadata_io_reasons
            WHERE dbname=%s AND begin_snap IN ({_ph}) AND cell_name='All'
            GROUP BY reason
            ORDER BY total_req DESC NULLS LAST
        """, [dbname] + snap_ids)
        io_reasons_raw = cur.fetchall()
        total_all_req  = sum(int(r[1] or 0) for r in io_reasons_raw) or 1
        exa["io_reasons"] = [{
            "reason":    r[0],
            "total_req": int(r[1] or 0),
            "total_mb":  round(float(r[2] or 0), 1),
            "pct_req":   round(int(r[1] or 0) / total_all_req * 100, 1),
        } for r in io_reasons_raw]

        # ── Wave 2: FC Space — large_write_pct ───────────────────────
        cur.execute(f"""
            SELECT cell_name,
              AVG(large_write_pct) AS avg_lw_pct,
              MAX(large_write_pct) AS max_lw_pct,
              AVG(total_fc_mb)     AS total_fc_mb
            FROM awr_exadata_fc_space
            WHERE dbname=%s AND begin_snap IN ({_ph})
            GROUP BY cell_name
            ORDER BY avg_lw_pct DESC NULLS LAST
        """, [dbname] + snap_ids)
        exa["fc_space"] = [{
            "cell_name":  r[0],
            "avg_lw_pct": round(float(r[1] or 0), 1),
            "max_lw_pct": round(float(r[2] or 0), 1),
            "total_fc_mb":round(float(r[3] or 0), 0),
        } for r in cur.fetchall()]
        exa["avg_lw_pct"] = (
            sum(c["avg_lw_pct"] for c in exa["fc_space"]) / len(exa["fc_space"])
            if exa["fc_space"] else 0)

        # ── Wave 3: Write Rejections ──────────────────────────────────
        cur.execute(f"""
            SELECT reason, SUM(rejection_count) AS total_rej
            FROM awr_exadata_fc_write_reject
            WHERE dbname=%s AND begin_snap IN ({_ph})
            GROUP BY reason ORDER BY total_rej DESC NULLS LAST
        """, [dbname] + snap_ids)
        exa["write_rejections"] = [{
            "reason": r[0], "total_rej": int(r[1] or 0)
        } for r in cur.fetchall()]
        exa["total_write_rejections"] = sum(r["total_rej"]
                                            for r in exa["write_rejections"])

        # ── Wave 3: Config — hardware + flash log ─────────────────────
        cur.execute(f"""
            SELECT DISTINCT ON (cell_name)
              cell_name, model, storage_version,
              flash_cache_mb, flash_log_mb, has_flash_log
            FROM awr_exadata_config
            WHERE dbname=%s AND begin_snap IN ({_ph})
            ORDER BY cell_name, begin_snap DESC
        """, [dbname] + snap_ids)
        exa["cell_config"] = [{
            "cell_name":    r[0],
            "model":        r[1] or "—",
            "sw_version":   r[2] or "—",
            "flash_cache_gb":round(float(r[3] or 0) / 1024, 1),
            "flash_log_gb": round(float(r[4] or 0) / 1024, 1) if r[4] else None,
            "has_flash_log":bool(r[5]),
        } for r in cur.fetchall()]

        # ── Wave 3: Disk outliers ─────────────────────────────────────
        cur.execute(f"""
            SELECT cell_name, device_type,
              AVG(util_pct) AS avg_util,
              BOOL_OR(is_outlier) AS ever_outlier
            FROM awr_exadata_disk_iostat
            WHERE dbname=%s AND begin_snap IN ({_ph})
            GROUP BY cell_name, device_type
            HAVING BOOL_OR(is_outlier) = true
            ORDER BY avg_util DESC NULLS LAST
            LIMIT 10
        """, [dbname] + snap_ids)
        exa["disk_outliers"] = [{
            "cell_name":  r[0],
            "device_type":r[1] or "—",
            "avg_util":   round(float(r[2] or 0), 1),
        } for r in cur.fetchall()]

    except Exception as e:
        logger.warning(f"Exadata fetch error (non-fatal): {e}")
        exa["fetch_error"] = str(e)

    return exa


# ── rule-based conclusion ────────────────────────────────────────────────

def build_conclusion(ctx: dict) -> dict:
    dbname, instance = ctx["dbname"], ctx["instance"]
    di     = ctx["db_info"]
    kpi    = ctx["kpi"]
    n_snap = ctx["snapshot_count"]
    tw     = ctx["top_wait_event"]

    host_cpu = kpi.get("host_cpu_busy")
    io_wait  = kpi.get("host_io_wait")

    cpu_phrase = (f"Host CPU averaged {host_cpu}% busy"
                  if host_cpu is not None else "Host CPU data unavailable")
    if io_wait is not None:
        cpu_phrase += f" (I/O wait {io_wait}%)"
    cpu_phrase += "."

    if   (host_cpu or 0) >= 90: severity = "critically CPU-stressed"
    elif (host_cpu or 0) >= 70: severity = "moderately loaded"
    else:                        severity = "lightly loaded"

    # Convert s/s to a human-readable interpretation
    db_time_ss = kpi["db_time_ss"]
    cpu_ratio  = (round(kpi["db_cpu_ss"] / db_time_ss * 100, 0)
                  if db_time_ss > 0 else 0)

    conclusion_text = (
        f"AWR analysis of {dbname}/{instance} "
        f"({di.get('release','Oracle')}, {di.get('host_name','—')}, "
        f"{di.get('cpu','?')} CPUs, {di.get('memory','?')} GB RAM) "
        f"across {n_snap} snapshot(s) shows a {severity} database. "
        f"DB Time averaged {db_time_ss} s/s with DB CPU at {kpi['db_cpu_ss']} s/s "
        f"({cpu_ratio}% CPU ratio). "
        f"Throughput averaged {kpi['tps']} TPS with {kpi['logical_reads']} logical reads/s "
        f"and {kpi['physical_reads']} physical reads/s. "
        f"The dominant wait event is '{tw}'. {cpu_phrase}"
    )

    hotspots = [f"Top wait — {tw}"]
    if kpi["physical_reads"] > 10000:
        hotspots.append(f"Physical reads — avg {int(kpi['physical_reads'])}/s "
                        "— buffer cache pressure or full scans")
    if host_cpu is not None:
        hotspots.append(
            f"Host CPU — avg {host_cpu}% busy (I/O wait {io_wait if io_wait is not None else '—'}%)")
    if kpi["hard_parses"] > 5:
        hotspots.append(
            f"Hard parses — avg {kpi['hard_parses']}/s — literal SQL or cursor sharing issue")

    # ── Rule engine hotspots (critical/high severity findings) ─────────
    # rule_findings comes from recommendation_engine.py's 60+-rule set —
    # see _get_rule_engine_findings(). Runs in both Rules and AI mode
    # (AI mode supplements this, never replaces it — see module header).
    # Only critical/high severity surfaces as a hotspot; medium/low still
    # feed the Recommendations list below.
    SEV_ICON = {"critical": "🔴", "high": "🟠"}
    for f in ctx.get("rule_findings", []):
        sev = f.get("severity")
        if sev not in SEV_ICON:
            continue
        label = f"{SEV_ICON[sev]} {f.get('title','')}"
        detail_bits = []
        if f.get("event"):  detail_bits.append(f.get("event"))
        if f.get("sql_id"): detail_bits.append(f"SQL {f.get('sql_id')}")
        if f.get("object"): detail_bits.append(f.get("object"))
        if detail_bits:
            label += f" ({', '.join(detail_bits)})"
        if label not in hotspots:
            hotspots.append(label)

    # ── Exadata-specific hotspots ─────────────────────────────────────────
    exa = ctx.get("exadata", {})
    if exa.get("is_exadata"):
        if exa.get("flushing_cells"):
            hotspots.append(
                f"🔴 Flash Cache FLUSHING on {len(exa['flushing_cells'])} cell(s): "
                f"{', '.join(exa['flushing_cells'])} — IOs redirected to disk")
        if exa.get("maxcap_cells"):
            hotspots.append(
                f"🔴 Cell at MAX IO CAPACITY: {', '.join(exa['maxcap_cells'])} — IO throttling")
        ps = exa.get("perf_summary", {})
        if ps.get("avg_oltp_hit", 100) < 80:
            hotspots.append(f"⚠️  Flash Cache OLTP hit = {ps['avg_oltp_hit']}% (< 80% threshold)")
        if ps.get("avg_scan_hit", 100) < 70:
            hotspots.append(f"⚠️  Flash Cache Scan hit = {ps['avg_scan_hit']}% (< 70% threshold)")
        td = exa.get("top_db", {})
        if td.get("avg_iorm_ms", 0) > 5:
            hotspots.append(
                f"⚠️  IORM large IO queue = {td['avg_iorm_ms']}ms (> 5ms threshold)")
        if exa.get("avg_lw_pct", 0) > 20:
            hotspots.append(
                f"⚠️  Flash Cache Large Write space = {round(exa['avg_lw_pct'],1)}% "
                "(> 20% — Global Limit pressure)")
        if exa.get("total_write_rejections", 0) > 0:
            hotspots.append(
                f"🔴 Flash Cache write rejections: {exa['total_write_rejections']:,} "
                "— Large Write Global Limit hit")

    recs = []
    tw_low = (tw or "").lower()
    if "sequential read" in tw_low:
        recs.append(("Index-Range Scan Pressure",
                     "'db file sequential read' dominates — identify SQL driving high-volume "
                     "index-range scans on large tables. Check execution plans for NESTED LOOPS "
                     "on hot tables; consider faster storage for high-traffic datafiles."))
    elif "scattered read" in tw_low or "direct path read" in tw_low:
        recs.append(("Full-Scan Waits",
                     "Full-scan-style waits dominate — check for missing indexes or stale "
                     "optimizer statistics causing full table/partition scans. "
                     "Run DBMS_STATS.GATHER_TABLE_STATS on hot tables."))
    elif "cpu" in tw_low:
        recs.append(("CPU Pressure",
                     "DB CPU is the dominant consumer — profile top-SQL by CPU time and review "
                     "for inefficient PL/SQL loops, excessive parsing, or under-indexed joins."))
    elif "log file sync" in tw_low or "commit" in tw_low:
        recs.append(("Commit-Rate Pressure",
                     "Commit-related waits are significant — review commit frequency in application "
                     "code (batch commits vs individual commits) and redo log I/O latency."))
    else:
        recs.append(("Top Wait Remediation",
                     f"'{tw}' is the dominant wait — investigate the SQL/sessions most associated "
                     "with this event using ASH or session-level tracing during peak load."))

    if kpi["physical_reads"] > 5000:
        recs.append(("Buffer Cache Sizing",
                     f"Physical reads at {int(kpi['physical_reads'])} blocks/s — review buffer cache "
                     "hit ratio and SGA sizing using the SGA Target Advisory."))

    if ctx["top_sql"] and ctx["top_sql"][0]["pct_total"] >= 15:
        recs.append(("SQL Tuning Priority",
                     f"SQL ID {ctx['top_sql'][0]['sql_id']} accounts for "
                     f"{ctx['top_sql'][0]['pct_total']}% of captured elapsed time — "
                     "review its execution plan and bind variable usage."))

    recs.append(("Comparative Analysis",
                 "Run a comparison between peak-load and off-peak snapshots to isolate "
                 "SQL and wait events that deteriorate specifically under load."))

    # ── Rule engine recommendations (Rules mode: only source beyond the
    # top-wait/buffer-cache/SQL-tuning heuristics above; AI mode: same,
    # plus the AI narrative panel — see ctx["ai_narrative"] and the
    # module header comment on why AI supplements rather than replaces
    # rule output). Already sorted critical-first by the engine; capped
    # here so the report stays readable rather than dumping all 60+
    # possible rules. Skipped if the rule engine returned nothing
    # (import/DB failure — see _get_rule_engine_findings) so the report
    # still shows the KPI-threshold recommendations above on their own.
    existing_titles = {t for t, _ in recs}
    rule_rec_count = 0
    MAX_RULE_RECS = 6
    for f in ctx.get("rule_findings", []):
        if rule_rec_count >= MAX_RULE_RECS:
            break
        title = f.get("title", "")
        if not title or title in existing_titles:
            continue
        detail = f.get("root_cause", "")
        steps = f.get("resolution") or []
        if steps:
            detail = (detail + " " if detail else "") + f"Next step: {steps[0]}"
        if not detail:
            continue
        recs.append((title, detail))
        existing_titles.add(title)
        rule_rec_count += 1

    # ── Exadata-specific recommendations ─────────────────────────────────
    if exa.get("is_exadata"):
        if exa.get("flushing_cells"):
            recs.append(("Flash Cache Flush Recovery",
                         f"Cell(s) {', '.join(exa['flushing_cells'])} are flushing — "
                         "all IOs on those cells are going to hard disk until flush completes. "
                         "Check cellcli alerts and wait for population writes to repopulate cache. "
                         "Avoid restarting cells during business hours."))
        ps = exa.get("perf_summary", {})
        if ps.get("avg_oltp_hit", 100) < 80 or ps.get("avg_scan_hit", 100) < 70:
            recs.append(("Flash Cache Hit Rate",
                         f"OLTP hit {ps.get('avg_oltp_hit',0)}% / Scan hit "
                         f"{ps.get('avg_scan_hit',0)}% — Flash Cache may be undersized "
                         "for this workload. Review cellcli 'list flashcache' sizing "
                         "and consider increasing Flash Cache if storage allows."))
        td = exa.get("top_db", {})
        if td.get("avg_iorm_ms", 0) > 5:
            recs.append(("IORM Queue Saturation",
                         f"IORM large IO queue averages {td['avg_iorm_ms']}ms (max "
                         f"{td.get('max_iorm_ms',0)}ms) — check IORM resource plan "
                         "and identify which database is consuming disproportionate IO "
                         "via the Top Databases section."))
        if exa.get("avg_lw_pct", 0) > 20 or exa.get("total_write_rejections", 0) > 0:
            recs.append(("Flash Cache Large Write Pressure",
                         f"Large Write space at {round(exa.get('avg_lw_pct',0),1)}% with "
                         f"{exa.get('total_write_rejections',0):,} rejection(s). "
                         "Reduce PGA_AGGREGATE_TARGET to cut temp spills; review "
                         "direct-path INSERT jobs; set mainWorkloadType='analytical' "
                         "on cells if this is a DWH workload."))
        if exa.get("maxcap_cells"):
            recs.append(("Cell IO Capacity",
                         f"Cell(s) {', '.join(exa['maxcap_cells'])} reached max IO capacity. "
                         "Check for failed disks reducing available IO bandwidth, "
                         "or uneven data distribution causing hot cells."))
        io_r = exa.get("io_reasons", [])
        ss = next((r for r in io_r if "smart" in r["reason"].lower()), None)
        if ss and ss["pct_req"] < 20:
            recs.append(("Smart Scan Contribution Low",
                         f"Smart Scan accounts for only {ss['pct_req']}% of cell IO — "
                         "expected 40–70%+ for analytics workloads. Review passthru rate, "
                         "partition pruning, and CELL_FLASH_CACHE NONE hints."))
        if exa.get("disk_outliers"):
            outlier = exa["disk_outliers"][0]
            recs.append(("Disk-Level Outlier",
                         f"Cell {outlier['cell_name']} has a disk outlier at "
                         f"{outlier['avg_util']}% util — possible degraded disk. "
                         "Run: cellcli -e 'LIST ALERTHISTORY WHERE severity IN (critical,warning)'"))

    if host_cpu is not None and host_cpu >= 85:
        risk = (f"Host CPU at {host_cpu}% average — at peak load, additional queries will queue "
                "for CPU, causing multi-second response times and possible connection timeouts.")
    elif kpi["physical_reads"] > 20000:
        risk = ("Sustained high physical read rates indicate I/O subsystem pressure — "
                "storage saturation could cause unpredictable latency spikes under peak load.")
    else:
        risk = ("No single metric is at a critical threshold in this window — continue "
                "periodic monitoring to catch trend degradation early.")

    return {
        "text":            conclusion_text,
        "hotspots":        hotspots,
        "recommendations": recs,   # list of (title, detail) tuples
        "risk":            risk,
    }
