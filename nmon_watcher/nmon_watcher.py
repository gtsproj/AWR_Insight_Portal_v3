# nmon_watcher/nmon_watcher.py
# ============================================================
# NMON File Watcher — monitors nmon_drop\ for new NMON files
# and queues them for processing by queue_processor.py
#
# NMON files are always plain-text CSV — no binary conversion
# needed, unlike SAR which requires WSL sadf for binary files.
#
# Drop folder layout (REQUIRED):
#   nmon_drop\<HOSTNAME>\file.nmon   ← preferred (hostname from subfolder)
#   nmon_drop\<HOSTNAME>\file.csv    ← also accepted
#
# Files dropped directly in nmon_drop\ (no subfolder) are also
# handled — hostname extracted from filename, or flagged with
# a clear message if it cannot be determined.
#
# Queue : nmon_queues\queue_<HOSTNAME>.json
# Archive: nmon_archive\<HOSTNAME>\
#
# USAGE:
#   python nmon_watcher\nmon_watcher.py
#   python nmon_watcher\nmon_watcher.py --watch-dir D:\nmon_files
#   python nmon_watcher\nmon_watcher.py --hostname TCLFSLPRDDB1
# ============================================================

import os
import sys
import time
import json
import shutil
import argparse
from datetime import datetime

_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, "common"))

from config_loader import load_config
from logger_utils  import get_logger

logger = get_logger("nmon_watcher")

# ── paths ─────────────────────────────────────────────────────────────
_cfg  = load_config()
_paths = _cfg.get("paths", {})

WATCH_DIR       = os.path.abspath(_paths.get("nmon_drop_directory",
                      os.path.join(_PROJECT_ROOT, "nmon_drop")))
NMON_QUEUES_DIR = os.path.abspath(_paths.get("nmon_queues_directory",
                      os.path.join(_PROJECT_ROOT, "nmon_queues")))
NMON_ARCHIVE_DIR = os.path.abspath(_paths.get("nmon_archive_directory",
                       os.path.join(_PROJECT_ROOT, "nmon_archive")))
POLL_INTERVAL   = int(_cfg.get("queue", {}).get("nmon_poll_interval_seconds",
                      _cfg.get("queue", {}).get("sar_poll_interval_seconds", 15)))

NMON_EXTENSIONS = {".nmon", ".csv"}


# ── hostname extraction ───────────────────────────────────────────────
def extract_hostname(filename: str, hostname_override: str = None) -> str:
    """
    Derive hostname from filename. Mirrors sar_watcher.extract_hostname().

    Expected patterns:
      TCLFSLPRDDB1_20260701_0000.nmon  → TCLFSLPRDDB1
      TCLFSLPRDDB1_nmon.csv            → TCLFSLPRDDB1
    Falls back to hostname_override or 'UNKNOWN'.
    """
    import re
    if hostname_override:
        return hostname_override.upper()
    name  = os.path.splitext(filename)[0]
    parts = name.split("_")
    for p in parts:
        pu = p.upper()
        if re.match(r'^\d+$', pu):          # pure date/number token
            continue
        if re.match(r'^NMON\d*$', pu):      # 'NMON', 'NMON01'
            continue
        if len(p) < 5:
            continue
        if p.replace("-", "").isalnum():
            return pu
    return "UNKNOWN"


def is_nmon_file(filename: str) -> bool:
    ext = os.path.splitext(filename)[1].lower()
    return ext in NMON_EXTENSIONS


# ── queue helpers (mirrors sar_watcher pattern exactly) ───────────────
def _queue_path(hostname: str) -> str:
    return os.path.join(NMON_QUEUES_DIR, f"queue_{hostname}.json")


def _load_queue(hostname: str) -> list:
    path = _queue_path(hostname)
    if not os.path.exists(path):
        return []
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, list) else []
    except Exception:
        return []


def _save_queue(hostname: str, items: list) -> None:
    os.makedirs(NMON_QUEUES_DIR, exist_ok=True)
    path = _queue_path(hostname)
    tmp  = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(items, f, indent=2, default=str)
    os.replace(tmp, path)


def already_queued(hostname: str, filepath: str) -> bool:
    """Check if a file is already in the queue (by path or filename)."""
    queue    = _load_queue(hostname)
    basename = os.path.basename(filepath)
    for item in queue:
        if item.get("status") not in ("PENDING", "PROCESSING", "DONE"):
            continue
        q_path = item.get("filepath", "")
        if q_path == filepath or os.path.basename(q_path) == basename:
            return True
    return False


def archive_original(hostname: str, filepath: str) -> str:
    """Move file to nmon_archive/<hostname>/ — mirrors sar_watcher.archive_original()."""
    host_dir = os.path.join(NMON_ARCHIVE_DIR, hostname)
    os.makedirs(host_dir, exist_ok=True)
    dest = os.path.join(host_dir, os.path.basename(filepath))
    try:
        shutil.move(filepath, dest)
        logger.debug(f"Archived: {os.path.basename(filepath)} → {dest}")
        return dest
    except Exception as e:
        logger.warning(f"Could not archive {filepath}: {e}")
        return filepath


def enqueue_and_archive(hostname: str, filepath: str) -> None:
    """Archive the file first, then add the archive path to the queue."""
    archive_path = archive_original(hostname, filepath)

    queue = _load_queue(hostname)
    try:
        mtime     = datetime.fromtimestamp(os.path.getmtime(archive_path))
        queued_at = mtime.isoformat()
    except Exception:
        queued_at = datetime.now().isoformat()

    item = {
        "filepath":    archive_path,
        "hostname":    hostname,
        "file_type":   "nmon",
        "status":      "PENDING",
        "retry_count": 0,
        "queued_at":   queued_at,
        "error":       None,
    }
    queue.append(item)
    _save_queue(hostname, queue)
    logger.info(f"📝 Queued: {os.path.basename(filepath)} → {hostname}")


# ── scan logic ────────────────────────────────────────────────────────
def _scan_watch_dir(watch_dir: str, hostname_override: str = None):
    r"""
    Scan watch_dir for NMON files using two strategies:

    Strategy 1 — Subfolder per hostname (PREFERRED, required for multi-host):
        nmon_drop\TCLFSLPRDDB1\file.nmon
        Hostname = subfolder name

    Strategy 2 — Files directly in nmon_drop with hostname prefix:
        nmon_drop\TCLFSLPRDDB1_20260701.nmon
        Hostname = extracted from filename

    Strategy 3 — hostname_override flag:
        All files in nmon_drop treated as belonging to one hostname.
        Use: py nmon_watcher\nmon_watcher.py --hostname TCLFSLPRDDB1
    """
    try:
        entries = os.listdir(watch_dir)
    except Exception as e:
        logger.error(f"Cannot list watch dir {watch_dir}: {e}")
        return

    for entry in sorted(entries):
        entry_path = os.path.join(watch_dir, entry)

        # ── Strategy 1: subfolder = hostname ────────────────────────
        if os.path.isdir(entry_path):
            hostname = hostname_override or entry.upper()
            _scan_host_folder(entry_path, hostname)

        # ── Strategy 2/3: files directly in nmon_drop ───────────────
        elif os.path.isfile(entry_path):
            if entry.startswith(".") or entry.endswith(".tmp"):
                continue
            if not is_nmon_file(entry):
                continue
            hostname = hostname_override or extract_hostname(entry, None)
            if hostname == "UNKNOWN":
                logger.warning(
                    f"⚠  Cannot determine hostname for: {entry} — SKIPPED\n"
                    f"   Fix option 1 (recommended): create a subfolder named after the server:\n"
                    f"     nmon_drop\\TCLFSLPRDDB1\\{entry}\n"
                    f"   Fix option 2: Run watcher with --hostname flag:\n"
                    f"     py nmon_watcher\\nmon_watcher.py --hostname TCLFSLPRDDB1"
                )
                continue
            _process_nmon_file(entry_path, hostname)


def _scan_host_folder(folder_path: str, hostname: str):
    """Process all NMON files in a hostname subfolder."""
    try:
        files = sorted(os.listdir(folder_path))
    except Exception as e:
        logger.error(f"Cannot list folder {folder_path}: {e}")
        return

    for filename in files:
        filepath = os.path.join(folder_path, filename)
        if os.path.isdir(filepath):
            continue
        if filename.startswith(".") or filename.endswith(".tmp"):
            continue
        if not is_nmon_file(filename):
            continue
        _process_nmon_file(filepath, hostname)


def _process_nmon_file(filepath: str, hostname: str):
    """Queue a single NMON file if not already queued."""
    if not already_queued(hostname, filepath):
        enqueue_and_archive(hostname, filepath)
    else:
        logger.debug(f"Already queued: {os.path.basename(filepath)} ({hostname}) — skipping")


# ── main watch loop ───────────────────────────────────────────────────
def watch(hostname_override: str = None):
    os.makedirs(WATCH_DIR,        exist_ok=True)
    os.makedirs(NMON_QUEUES_DIR,  exist_ok=True)
    os.makedirs(NMON_ARCHIVE_DIR, exist_ok=True)

    logger.info(f"🔍 NMON Watcher started. Monitoring: {WATCH_DIR}")
    logger.info(f"   Drop layout  : {WATCH_DIR}\\<HOSTNAME>\\file.nmon")
    logger.info(f"   NMON queues  : {NMON_QUEUES_DIR}")
    logger.info(f"   Archive      : {NMON_ARCHIVE_DIR}")
    logger.info(f"   Poll interval: {POLL_INTERVAL}s")

    while True:
        try:
            _scan_watch_dir(WATCH_DIR, hostname_override)
        except Exception as e:
            logger.error(f"❌ NMON Watcher error: {e}", exc_info=True)
        time.sleep(POLL_INTERVAL)


# ── entry point ───────────────────────────────────────────────────────
def main():
    p = argparse.ArgumentParser(description="NMON File Watcher")
    p.add_argument("--watch-dir", default=None,
                   help="Override NMON drop folder path")
    p.add_argument("--hostname",  default=None,
                   help="Override hostname for all files in watch dir")
    args = p.parse_args()

    global WATCH_DIR
    if args.watch_dir:
        WATCH_DIR = os.path.abspath(args.watch_dir)

    watch(hostname_override=args.hostname)


if __name__ == "__main__":
    main()
