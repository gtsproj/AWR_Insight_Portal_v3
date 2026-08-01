# sar_watcher/sar_watcher.py
# ============================================================
# SAR File Watcher — monitors sar_drop\ for new SAR files
# and queues them for processing by queue_processor.py
#
# File handling priority:
#   1. .txt files (pre-converted text SAR output) → queue directly
#   2. Binary sa01/sa02 files → convert via WSL sadf -c, then queue
#   3. If WSL unavailable → mark FAILED with clear message
#
# Queue: sar_queues\queue_<HOSTNAME>.json  (separate from AWR queues)
# Hostname extracted from filename or prompted via config
#
# USAGE:
#   python sar_watcher\sar_watcher.py
#   python sar_watcher\sar_watcher.py --watch-dir D:\sar_files
#   python sar_watcher\sar_watcher.py --hostname MYSERVER
# ============================================================

import os
import sys
import time
import json
import shutil
import argparse
import subprocess
from datetime import datetime

# Allow imports from project root common\
_PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(_PROJECT_ROOT, "common"))

from config_loader import load_config
from logger_utils  import get_logger

logger = get_logger("sar_watcher")

# ── paths ────────────────────────────────────────────────────────────
_cfg             = load_config()
_paths           = _cfg.get("paths", {})

WATCH_DIR        = os.path.abspath(_paths.get("sar_drop_directory",
                       os.path.join(_PROJECT_ROOT, "sar_drop")))
SAR_QUEUES_DIR   = os.path.abspath(_paths.get("sar_queues_directory",
                       os.path.join(_PROJECT_ROOT, "sar_queues")))
SAR_ARCHIVE_DIR  = os.path.abspath(_paths.get("sar_archive_directory",
                       os.path.join(_PROJECT_ROOT, "sar_archive")))
CONVERTED_DIR    = os.path.join(WATCH_DIR, "_converted")   # temp for WSL output
POLL_INTERVAL    = int(_cfg.get("queue", {}).get("sar_poll_interval_seconds", 15))

# Binary SAR file extensions / name patterns
BINARY_PREFIXES  = ("sa",)        # sa01, sa02 ... sa31
TEXT_EXTENSIONS  = (".txt", ".sar")
TIMEZONE         = _cfg.get("sar", {}).get("timezone", "Asia/Kolkata")


# ── hostname extraction ───────────────────────────────────────────────
def extract_hostname(filename: str, hostname_override: str = None) -> str:
    """
    Derive hostname from filename.
    Expected patterns:
      TCLFSLPRDDB1_sa01             → TCLFSLPRDDB1
      TCLFSLPRDDB1_sar_20231202.txt → TCLFSLPRDDB1
      sar_TCLFSLPRDDB1_20231202.txt → TCLFSLPRDDB1
    Falls back to hostname_override or 'UNKNOWN'.
    Files named sa01..sa31 with no prefix → UNKNOWN (use subfolder method).
    """
    import re
    if hostname_override:
        return hostname_override.upper()
    name  = os.path.splitext(filename)[0]
    parts = name.split("_")
    for p in parts:
        pu = p.upper()
        # Skip SAR date/time patterns: sa01-sa31, digits, short tokens
        if re.match(r'^SA\d{1,2}$', pu):          # sa01, sa02 ... sa31
            continue
        if re.match(r'^\d+$', pu):                 # pure numbers
            continue
        if re.match(r'^SAR\d*$', pu):              # sar, sar01
            continue
        if len(p) < 5:                             # too short to be a hostname
            continue
        if p.replace("-", "").isalnum():
            return pu
    return "UNKNOWN"


def is_binary_sar(filename: str) -> bool:
    """Return True if file looks like a binary SAR file (sa01..sa31)."""
    name = os.path.splitext(filename)[0].lower()
    basename = os.path.basename(name)
    if basename.startswith("sa") and basename[2:].isdigit():
        return True
    # Also accept files with no extension that start with 'sa'
    ext = os.path.splitext(filename)[1].lower()
    if not ext and os.path.basename(filename).lower().startswith("sa"):
        return True
    return False


def is_text_sar(filename: str) -> bool:
    """Return True if file is a text SAR output."""
    ext = os.path.splitext(filename)[1].lower()
    return ext in TEXT_EXTENSIONS


# ── WSL binary conversion ─────────────────────────────────────────────
def wsl_available() -> bool:
    """
    Check if WSL is available and working on this Windows machine.

    Two known failure modes when running as a Windows service (NSSM):

    1. SysWOW64 redirect: 32-bit processes and some service contexts
       that access C:/Windows/System32 get silently redirected to
       C:/Windows/SysWOW64 which does NOT contain wsl.exe.
       Fix: also try Sysnative (the 64-bit alias visible to 32-bit callers).

    2. wsl echo ok fails under service accounts even when WSL works.
       Fix: test with `wsl --status` or `wsl -l` which are more reliable
       in non-interactive service sessions, and fall back to attempting
       an actual `wsl bash -c "echo ok"` as a final check.
    """
    import shutil

    # Candidate paths in priority order:
    #   System32   — works for 64-bit processes
    #   Sysnative  — 64-bit alias accessible from 32-bit service processes
    #   PATH       — fallback
    candidates = [
        r"C:\Windows\System32\wsl.exe",
        r"C:\Windows\Sysnative\wsl.exe",   # 32-bit process → 64-bit System32
    ]
    path_wsl = shutil.which("wsl")
    if path_wsl:
        candidates.append(path_wsl)

    wsl_exe = None
    for c in candidates:
        if os.path.exists(c):
            wsl_exe = c
            logger.debug(f"Found wsl.exe at: {c}")
            break

    if not wsl_exe:
        logger.debug("wsl.exe not found in any candidate path — WSL not installed")
        return False

    # ── Test 1: wsl --status (works in service context, no distro needed) ──
    # This succeeds as long as WSL is installed, even under a service account.
    for attempt, timeout in enumerate([10, 20, 30], 1):
        try:
            result = subprocess.run(
                [wsl_exe, "--status"],
                capture_output=True, text=True,
                timeout=timeout,
                creationflags=0x08000000 if os.name == "nt" else 0  # CREATE_NO_WINDOW
            )
            # --status exits 0 and prints version info when WSL is working
            if result.returncode == 0:
                logger.debug(f"WSL --status OK (attempt {attempt})")
                # ── Test 2: confirm a distro can actually run ──────────────
                # wsl --status working doesn't guarantee a distro is runnable
                try:
                    r2 = subprocess.run(
                        [wsl_exe, "bash", "-c", "echo ok"],
                        capture_output=True, text=True,
                        timeout=30,
                        creationflags=0x08000000 if os.name == "nt" else 0
                    )
                    if r2.returncode == 0 and "ok" in r2.stdout:
                        logger.debug("WSL bash echo test passed — WSL fully operational")
                        return True
                    else:
                        # bash failed but WSL installed — try default shell
                        r3 = subprocess.run(
                            [wsl_exe, "-e", "sh", "-c", "echo ok"],
                            capture_output=True, text=True,
                            timeout=30,
                            creationflags=0x08000000 if os.name == "nt" else 0
                        )
                        if r3.returncode == 0 and "ok" in r3.stdout:
                            logger.debug("WSL sh echo test passed — WSL fully operational")
                            return True
                        logger.warning(
                            f"WSL is installed and --status passes but shell test failed. "
                            f"bash rc={r2.returncode} stderr={r2.stderr[:200]!r}"
                        )
                        # Still return True — WSL is present, conversion will be attempted
                        return True
                except Exception as e2:
                    logger.warning(f"WSL shell test error: {e2} — treating WSL as available")
                    return True   # --status passed; attempt conversion anyway

            logger.debug(
                f"WSL --status attempt {attempt}: rc={result.returncode} "
                f"stderr={result.stderr[:150]!r}"
            )
        except subprocess.TimeoutExpired:
            logger.debug(f"WSL --status attempt {attempt}: timed out after {timeout}s")
            if attempt < 3:
                time.sleep(3)
            continue
        except Exception as e:
            logger.debug(f"WSL check attempt {attempt}: {e}")

    logger.debug("WSL not available after 3 attempts")
    return False


def convert_binary_sar(binary_path: str, hostname: str) -> str | None:
    """
    Convert binary SAR file to text using WSL sadf + sar.
    Returns path to converted .txt file, or None on failure.
    """
    os.makedirs(CONVERTED_DIR, exist_ok=True)
    basename    = os.path.basename(binary_path)
    # Strip .processing suffix if present
    clean_name  = basename.replace('.processing', '')
    output_name = f"{hostname}_{clean_name}_{datetime.now().strftime('%Y%m%d%H%M%S')}.txt"
    output_path = os.path.join(CONVERTED_DIR, output_name)

    # Convert Windows path to WSL path
    wsl_input  = binary_path.replace("\\", "/").replace("C:", "/mnt/c").replace("D:", "/mnt/d")
    wsl_output = output_path.replace("\\", "/").replace("C:", "/mnt/c").replace("D:", "/mnt/d")
    wsl_tmp    = f"/tmp/sar_conv_{basename}"

    cmd = (
        f"TZ={TIMEZONE} sadf -c {wsl_input} > {wsl_tmp} && "
        f"TZ={TIMEZONE} sar -A -f {wsl_tmp} > {wsl_output}"
    )

    logger.info(f"Converting binary SAR via WSL: {basename}")
    # Same candidate search as wsl_available() — handles Sysnative for 32-bit service
    import shutil as _shutil
    _candidates = [
        r"C:\Windows\System32\wsl.exe",
        r"C:\Windows\Sysnative\wsl.exe",
    ]
    _path_wsl = _shutil.which("wsl")
    if _path_wsl:
        _candidates.append(_path_wsl)
    wsl_exe = next((c for c in _candidates if os.path.exists(c)),
                   r"C:\Windows\System32\wsl.exe")
    try:
        result = subprocess.run(
            [wsl_exe, "bash", "-c", cmd],
            capture_output=True, text=True, timeout=120,
            creationflags=0x08000000 if os.name == 'nt' else 0  # CREATE_NO_WINDOW
        )
        if result.returncode == 0 and os.path.exists(output_path):
            size = os.path.getsize(output_path)
            if size > 100:
                logger.info(f"  Converted → {output_name} ({size:,} bytes)")
                return output_path
            else:
                logger.warning(f"  Conversion produced empty file: {output_name}")
                return None
        else:
            logger.error(f"  WSL conversion failed: {result.stderr[:300]}")
            return None
    except subprocess.TimeoutExpired:
        logger.error(f"  WSL conversion timed out for {basename}")
        return None
    except Exception as e:
        logger.error(f"  WSL conversion error: {e}", exc_info=True)
        return None


# ── queue helpers ─────────────────────────────────────────────────────
def queue_path(hostname: str) -> str:
    return os.path.join(SAR_QUEUES_DIR, f"queue_{hostname}.json")


def load_queue(hostname: str) -> list:
    path = queue_path(hostname)
    if not os.path.exists(path):
        return []
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, list) else []
    except Exception:
        return []


def save_queue(hostname: str, items: list) -> None:
    os.makedirs(SAR_QUEUES_DIR, exist_ok=True)
    path = queue_path(hostname)
    tmp  = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(items, f, indent=2, default=str)
    os.replace(tmp, path)


def already_queued(hostname: str, filepath: str) -> bool:
    """
    Check if a file is already in the queue.
    Checks filepath, original_file, and filename stem
    to catch binary sa01 → sa01.txt conversions.
    """
    queue    = load_queue(hostname)
    basename = os.path.basename(filepath)
    stem     = os.path.splitext(basename)[0]   # sa01.txt → sa01, sa01 → sa01

    for item in queue:
        status = item.get("status", "")
        if status not in ("PENDING", "PROCESSING", "DONE"):
            continue
        q_path  = item.get("filepath", "")
        q_orig  = item.get("original_file", "")
        q_base  = os.path.basename(q_path)
        q_stem  = os.path.splitext(q_base)[0]
        o_base  = os.path.basename(q_orig)
        o_stem  = os.path.splitext(o_base)[0]

        if (q_path == filepath
                or q_orig == filepath
                or q_base == basename
                or o_base == basename
                or q_stem == stem          # sa01.txt matches sa01
                or o_stem == stem):
            return True
    return False


def archive_original(hostname: str, filepath: str) -> str:
    """Move original file to sar_archive/<hostname>/ after queuing.
    Returns the destination path so it can be stored in the queue."""
    db_archive = os.path.join(SAR_ARCHIVE_DIR, hostname)
    os.makedirs(db_archive, exist_ok=True)
    dest = os.path.join(db_archive, os.path.basename(filepath))
    try:
        shutil.move(filepath, dest)
        logger.debug(f"Archived: {os.path.basename(filepath)} → {dest}")
        return dest
    except Exception as e:
        logger.warning(f"Could not archive {filepath}: {e}")
        return filepath   # fallback — return original path if move failed


def enqueue_and_archive(hostname: str, filepath: str,
                        original_file: str = None,
                        file_type: str = "text") -> None:
    """
    Archive the file first, then enqueue with the ARCHIVE path.
    This ensures the queue processor can always find the file
    at the path stored in the queue.
    """
    # Archive first — get the final resting path
    archive_path = archive_original(hostname, filepath)

    queue = load_queue(hostname)
    try:
        mtime     = datetime.fromtimestamp(os.path.getmtime(archive_path))
        queued_at = mtime.isoformat()
    except Exception:
        queued_at = datetime.now().isoformat()

    item = {
        "filepath":      archive_path,     # ← archive path, always accessible
        "original_file": original_file or filepath,
        "hostname":      hostname,
        "file_type":     file_type,
        "status":        "PENDING",
        "retry_count":   0,
        "queued_at":     queued_at,
        "error":         None,
    }
    queue.append(item)
    save_queue(hostname, queue)
    logger.info(f"📝 Queued [{file_type}]: {os.path.basename(filepath)} → {hostname}")


# ── main watch loop ───────────────────────────────────────────────────
def watch(hostname_override: str = None):
    os.makedirs(WATCH_DIR, exist_ok=True)
    os.makedirs(SAR_QUEUES_DIR, exist_ok=True)
    os.makedirs(SAR_ARCHIVE_DIR, exist_ok=True)
    os.makedirs(CONVERTED_DIR, exist_ok=True)

    _wsl_ok = wsl_available()
    if _wsl_ok:
        logger.info("✅ WSL available — binary SAR files will be auto-converted")
    else:
        logger.warning("⚠  WSL not available — binary SAR files will be skipped")

    logger.info(f"🔍 SAR Watcher started. Monitoring: {WATCH_DIR}")
    logger.info(f"   Drop layout : {WATCH_DIR}\\<HOSTNAME>\\sa01  OR  {WATCH_DIR}\\<HOSTNAME>_filename.txt")
    logger.info(f"   SAR queues  : {SAR_QUEUES_DIR}")
    logger.info(f"   Archive     : {SAR_ARCHIVE_DIR}")

    _wsl_last_check = 0   # epoch — force recheck on first scan

    while True:
        try:
            import time as _time
            # Re-check WSL every 5 minutes so a transient startup
            # failure doesn't permanently disable binary SAR processing
            now = _time.time()
            if now - _wsl_last_check > 300:
                new_wsl_ok = wsl_available()
                if new_wsl_ok != _wsl_ok:
                    if new_wsl_ok:
                        logger.info("✅ WSL now available — binary SAR auto-conversion re-enabled")
                    else:
                        logger.warning("⚠  WSL no longer available — binary SAR files will be skipped")
                _wsl_ok = new_wsl_ok
                _wsl_last_check = now

            _scan_watch_dir(WATCH_DIR, _wsl_ok, hostname_override)
        except Exception as e:
            logger.error(f"❌ SAR Watcher error: {e}", exc_info=True)
        time.sleep(POLL_INTERVAL)


def _scan_watch_dir(watch_dir: str, wsl_ok: bool, hostname_override: str = None):
    r"""
    Scan watch_dir for SAR files using two strategies:

    Strategy 1 — Subfolder per hostname (PREFERRED):
        sar_drop\TCLFSLPRDDB1\sa01
        sar_drop\TCLFSLPRDDB1\sa02.txt
        Hostname = subfolder name

    Strategy 2 — Files directly in sar_drop with hostname prefix:
        sar_drop\TCLFSLPRDDB1_sa01.txt
        sar_drop\TCLFSLPRDDB1_sar_20231202.txt
        Hostname = extracted from filename

    Strategy 3 — hostname_override flag:
        All files in sar_drop treated as belonging to one hostname.
        Use: py sar_watcher.py --hostname TCLFSLPRDDB1
    """
    entries = os.listdir(watch_dir)

    for entry in sorted(entries):
        entry_path = os.path.join(watch_dir, entry)

        # ── Strategy 1: subfolder = hostname ────────────────────────
        if os.path.isdir(entry_path) and entry != "_converted":
            hostname = hostname_override or entry.upper()
            _scan_host_folder(entry_path, hostname, wsl_ok)

        # ── Strategy 2/3: files directly in sar_drop ────────────────
        elif os.path.isfile(entry_path):
            if entry.startswith(".") or entry.endswith(".tmp"):
                continue
            hostname = hostname_override or extract_hostname(entry, None)
            if hostname == "UNKNOWN":
                logger.warning(
                    f"⚠  Cannot determine hostname for: {entry} — SKIPPED\n"
                    f"   SAR files named sa01/sa02 have no hostname in the filename.\n"
                    f"   Fix option 1 (recommended): Create a subfolder named after the server:\n"
                    f"     sar_drop\\TCLFSLPRDDB1\\{entry}\n"
                    f"   Fix option 2: Run watcher with --hostname flag:\n"
                    f"     py sar_watcher\\sar_watcher.py --hostname TCLFSLPRDDB1"
                )
                continue
            _process_sar_file(entry_path, hostname, wsl_ok)


def _scan_host_folder(folder_path: str, hostname: str, wsl_ok: bool):
    """Process all SAR files found in a hostname subfolder."""
    for filename in sorted(os.listdir(folder_path)):
        filepath = os.path.join(folder_path, filename)
        if os.path.isdir(filepath):
            continue
        if filename.startswith(".") or filename.endswith(".tmp"):
            continue
        _process_sar_file(filepath, hostname, wsl_ok)


def _process_sar_file(filepath: str, hostname: str, wsl_ok: bool):
    """Queue a single SAR file — text directly, binary via WSL conversion."""
    filename = os.path.basename(filepath)

    if is_text_sar(filename):
        if not already_queued(hostname, filepath):
            enqueue_and_archive(hostname, filepath, file_type="text")

    elif is_binary_sar(filename) or _looks_like_binary_sar(filepath):
        if not wsl_ok:
            logger.warning(
                f"⚠  Skipping binary SAR (WSL unavailable): {filename}\n"
                f"   Convert manually on the Linux server:\n"
                f"   sar -A -f {filename} > {filename}.txt\n"
                f"   Then drop the .txt into sar_drop\\{hostname}\\"
            )
            return

        # Check if already queued before doing anything
        if already_queued(hostname, filepath):
            logger.debug(f"Already queued (binary): {filename} — skipping")
            return

        # Rename to .processing to prevent re-scanning during WSL conversion
        processing_path = filepath + ".processing"
        try:
            os.rename(filepath, processing_path)
        except Exception as e:
            logger.warning(f"Could not mark {filename} as processing: {e}")
            processing_path = filepath  # fallback — proceed anyway

        converted = convert_binary_sar(processing_path, hostname)
        if converted:
            # Archive the original binary
            archive_original(hostname, processing_path)
            # Queue and archive the converted text file
            if not already_queued(hostname, converted):
                enqueue_and_archive(hostname, converted,
                                    original_file=filepath,
                                    file_type="binary_converted")
        else:
            # Conversion failed — rename back so it can be retried
            try:
                if os.path.exists(processing_path):
                    os.rename(processing_path, filepath)
            except Exception:
                pass
            logger.error(f"❌ Binary conversion failed for {filename}")


def _looks_like_binary_sar(filepath: str) -> bool:
    """
    Peek at first bytes to detect binary SAR format.
    Binary SAR files start with a magic header (not printable text).
    """
    try:
        with open(filepath, "rb") as f:
            header = f.read(16)
        # If first bytes are not printable ASCII/UTF-8, assume binary
        printable = sum(1 for b in header if 32 <= b < 127 or b in (9, 10, 13))
        return printable < len(header) // 2
    except Exception:
        return False


# ── entry point ───────────────────────────────────────────────────────
def main():
    p = argparse.ArgumentParser(description="SAR File Watcher")
    p.add_argument("--watch-dir", default=None,
                   help="Override SAR drop folder path")
    p.add_argument("--hostname",  default=None,
                   help="Override hostname for all files in watch dir")
    args = p.parse_args()

    global WATCH_DIR
    if args.watch_dir:
        WATCH_DIR = os.path.abspath(args.watch_dir)

    watch(hostname_override=args.hostname)


if __name__ == "__main__":
    main()
