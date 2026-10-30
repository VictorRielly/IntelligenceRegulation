#!/usr/bin/env python3
"""Read-only watcher for the shared box: prints one line per NEW problem, never kills.

Companion to zk60_resource_guard.py.  The guard protects jobs that go through it;
this reports what it cannot see, so a person or an agent can act before the box
freezes (2026-09-29 17:40 PDT):

  LOWMEM      host MemAvailable under --low-gib (default 3.0)
  UNGUARDED   a process at or over --rss-gib (default 1.5) that is not inside a
              zk60-<run>.scope unit and is not known session infrastructure
  GPUBUSY     VRAM in use over 400 MiB while no guarded gpu job is live
  TWOHEAVY    more than one heavy guarded job live (the guard should prevent it)
  GUARDKILL   a new history.jsonl record where the guard killed or refused a job
              with a reason worth knowing (exit 71/75/76)
  DISKLOW     the host drive (C:, holding the VM disk and the Windows page file)
              under --disk-warn-gib (default 60); the guard holds heavy jobs under
              40 and kills any job under 8
  WINMEM      Windows itself short of memory: free RAM under --win-free-gib
              (default 3) or commit over --win-commit-pct (default 85) of its limit.
              The guard cannot see this (2026-10-29 crash, 2026-10-28 "8 GB left")

Each problem is reported once until it clears; silence means nothing new.
  python3 zk60_resource_watch.py [--interval 10] [--once]

Unattended mode (user cron, every 5 minutes; no session needed):
  python3 zk60_resource_watch.py --once --state FILE --notify --evict-cache
--state keeps what was already reported between runs, --notify sends each new
DISKLOW / WINMEM / LOWMEM / TWOHEAVY line (and a guard kill for disk space) to
Victor through tg-notify, and --evict-cache, while WINMEM holds or Windows has
under --evict-below-gib (default 6) free, at most every 15 min, drops the clean
page cache of large files in the project's data folders (posix_fadvise
DONTNEED: nothing is deleted or written; a later read comes from disk) so the
VM hands that memory back to Windows.  It needs no sudo.
"""
import argparse
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

GUARD = Path(__file__).resolve().parent / "zk60_resource_guard.py"
spec = importlib.util.spec_from_file_location("zk60_guard_for_watch", GUARD)
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)

# processes that are session infrastructure, not jobs (matched on the command line)
INFRA = ("claude", "codex", "ollama", "snapd", "tg-router", "node ")

POWERSHELL = os.environ.get("ZK60_WATCH_POWERSHELL",
                            "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe")
WIN_PROBE = ("$o=Get-CimInstance Win32_OperatingSystem; $v=(Get-Process vmmemWSL -ErrorAction "
             "SilentlyContinue | Measure-Object WorkingSet64 -Sum).Sum; '{0} {1} {2} {3} {4}' -f "
             "$o.TotalVisibleMemorySize,$o.FreePhysicalMemory,$o.TotalVirtualMemorySize,"
             "$o.FreeVirtualMemory,[int64]$v")
WIN_PROBE_SECS = 60.0
_win_cache: dict = {"t": 0.0, "v": None}
TG_NOTIFY = Path.home() / ".local/bin/tg-notify"
NOTIFY_KINDS = ("disklow", "winmem", "lowmem", "twoheavy")
# Where the large proof artifacts, exports and models live (the page cache they fill
# is what Windows counts against the VM).  Build output and git objects are skipped.
EVICT_ROOTS = (Path.home() / "zk60-artifacts", Path.home() / "models",
               g.REPO / "results", g.REPO / "local-models", g.REPO / "ops/zkp-mvp")
EVICT_MIN_BYTES = 64 * 1024 ** 2
EVICT_EVERY_SECS = 900.0


def windows_memory() -> dict | None:
    """Windows host memory in GiB (cached WIN_PROBE_SECS), or None off WSL/unreadable."""
    if time.time() - _win_cache["t"] < WIN_PROBE_SECS:
        return _win_cache["v"]
    v = None
    if os.path.exists(POWERSHELL):
        try:
            out = subprocess.run([POWERSHELL, "-NoProfile", "-NonInteractive", "-Command", WIN_PROBE],
                                 capture_output=True, text=True, timeout=30, cwd="/mnt/c").stdout
            tot, free, limit, vfree, vmmem = (int(x) for x in out.split()[-5:])
            k = 1024 ** 2  # the CIM values are KiB
            v = {"ram_gib": tot / k, "free_gib": free / k, "commit_limit_gib": limit / k,
                 "commit_used_gib": (limit - vfree) / k, "vmmem_gib": vmmem / g.GIB}
        except (OSError, ValueError, subprocess.SubprocessError):
            v = None
    _win_cache.update(t=time.time(), v=v)
    return v


def cgroup_of(pid: int) -> str:
    try:
        return Path(f"/proc/{pid}/cgroup").read_text().strip().split(":", 2)[2]
    except (OSError, IndexError):
        return ""


def cmdline(pid: int) -> str:
    try:
        return Path(f"/proc/{pid}/cmdline").read_bytes().replace(b"\0", b" ").decode("utf-8", "replace")
    except OSError:
        return ""


def under_guard(pid: int, table: dict) -> bool:
    """A guard process among the ancestors: a watchdog-only job (no systemd scope, as in
    a Codex sandbox) is still guarded even though its cgroup carries no zk60- name."""
    seen = set()
    while pid in table and pid not in seen and pid > 1:
        seen.add(pid)
        pid = table[pid][0]
        if "zk60_resource_guard.py run" in cmdline(pid):
            return True
    return False


def problems(rss_gib: float, low_gib: float, disk_warn_gib: float = 60.0,
             win_free_gib: float = 3.0, win_commit_pct: float = 85.0) -> dict[str, str]:
    out: dict[str, str] = {}
    mem = g.meminfo()
    if mem["MemAvailable"] / g.GIB < low_gib:
        out["lowmem"] = f"LOWMEM MemAvailable {mem['MemAvailable'] / g.GIB:.1f} GiB < {low_gib:g} GiB"
    free = g.host_drive_free_gib()
    if free is not None and free < disk_warn_gib:
        out["disklow"] = (f"DISKLOW host drive {g.HOST_DRIVE} {free:.1f} GiB free < {disk_warn_gib:g} GiB "
                          f"(heavy jobs wait under {g.DISK_FLOOR_GIB:g}, any job is killed under "
                          f"{g.DISK_KILL_GIB:g}); prune regenerable outputs or compact the VM disk")
    w = windows_memory()
    if w and (w["free_gib"] < win_free_gib
              or w["commit_used_gib"] > w["commit_limit_gib"] * win_commit_pct / 100):
        out["winmem"] = (f"WINMEM Windows free RAM {w['free_gib']:.1f} of {w['ram_gib']:.1f} GiB, "
                         f"commit {w['commit_used_gib']:.1f} of {w['commit_limit_gib']:.1f} GiB, "
                         f"WSL VM (vmmem) {w['vmmem_gib']:.1f} GiB, guest page cache "
                         f"{mem.get('Cached', 0) / g.GIB:.1f} GiB")
    table = g.proc_table()
    for pid, (_pp, _pg, rss) in table.items():
        if rss < rss_gib * g.GIB:
            continue
        cg = cgroup_of(pid)
        cmd = cmdline(pid)
        if "zk60-" in cg or any(k in cmd[:80] for k in INFRA) or under_guard(pid, table):
            continue
        out[f"unguarded:{pid}"] = (f"UNGUARDED pid {pid} rss {rss / g.GIB:.1f} GiB not in a guard scope: "
                                   f"{cmd[:120]}")
    live = g._live_jobs(g._ensure_dirs())
    heavy = [j for j in live if j["class"] in ("cpu", "gpu", "build")]
    if len(heavy) > 1:
        out["twoheavy"] = "TWOHEAVY " + ", ".join(f"{j['label']}({j['class']})" for j in heavy)
    gpu = g.gpu_used_mib()
    if gpu and gpu[0] > g.VRAM_IDLE_MIB and not any(j["class"] == "gpu" for j in live):
        out["gpubusy"] = f"GPUBUSY {gpu[0]} MiB in use with no guarded gpu job live"
    return out


def new_history(offset: int) -> tuple[int, list[str]]:
    lines = []
    try:
        size = os.path.getsize(g.HISTORY)
        if size <= offset:
            return size, lines
        with open(g.HISTORY) as f:
            f.seek(offset)
            for raw in f:
                try:
                    r = json.loads(raw)
                except ValueError:
                    continue
                if r.get("exit") in (71, 75, 76) or r.get("gpu_drain_failed"):
                    why = r.get("guard_killed") or r.get("guard_error") or "GPU did not drain"
                    lines.append(f"GUARDKILL {r.get('label')} ({r.get('class')}) exit {r.get('exit')}: {why}")
        return size, lines
    except OSError:
        return offset, lines


def evict_page_cache(roots=EVICT_ROOTS, min_bytes=EVICT_MIN_BYTES) -> tuple[int, float]:
    """Drop the clean page cache of large files under `roots` (no data is touched).
    Returns (files advised, GiB of guest page cache released)."""
    before = g.meminfo().get("Cached", 0)
    n = 0
    for root in roots:
        for d, dirs, files in os.walk(root):
            dirs[:] = [x for x in dirs if not (x == "target" or x.startswith("target-") or x == ".git")]
            for name in files:
                p = os.path.join(d, name)
                try:
                    if os.path.islink(p) or os.path.getsize(p) < min_bytes:
                        continue
                    fd = os.open(p, os.O_RDONLY | os.O_NOATIME) if os.access(p, os.R_OK) else None
                except OSError:
                    continue
                if fd is None:
                    continue
                try:
                    os.posix_fadvise(fd, 0, 0, os.POSIX_FADV_DONTNEED)
                    n += 1
                except OSError:
                    pass
                finally:
                    os.close(fd)
    return n, max(0, before - g.meminfo().get("Cached", 0)) / g.GIB


def notify(text: str) -> None:
    if TG_NOTIFY.exists():
        try:
            subprocess.run([str(TG_NOTIFY), text], timeout=30, capture_output=True)
        except (OSError, subprocess.SubprocessError):
            pass


def load_state(path: Path | None) -> dict:
    if path:
        try:
            return json.loads(path.read_text())
        except (OSError, ValueError):
            pass
    return {}


def save_state(path: Path | None, state: dict) -> None:
    if path:
        path.parent.mkdir(parents=True, exist_ok=True)
        g.write_atomic(path, json.dumps(state) + "\n")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--interval", type=float, default=10.0)
    ap.add_argument("--rss-gib", type=float, default=1.5)
    ap.add_argument("--low-gib", type=float, default=3.0)
    ap.add_argument("--disk-warn-gib", type=float, default=60.0)
    ap.add_argument("--win-free-gib", type=float, default=3.0)
    ap.add_argument("--win-commit-pct", type=float, default=85.0)
    ap.add_argument("--once", action="store_true")
    ap.add_argument("--state", type=Path, help="remember reported problems between --once runs")
    ap.add_argument("--notify", action="store_true", help="send new problems through tg-notify")
    ap.add_argument("--evict-cache", action="store_true",
                    help="while WINMEM holds or Windows free RAM is under --evict-below-gib, "
                         "drop the page cache of large data files (at most every 15 min)")
    ap.add_argument("--evict-below-gib", type=float, default=6.0)
    args = ap.parse_args()
    state = load_state(args.state)
    seen: set[str] = set(state.get("seen", []))
    offset = state.get("history_offset")
    if offset is None:
        try:
            offset = os.path.getsize(g.HISTORY)
        except OSError:
            offset = 0
    while True:
        stamp = time.strftime('%H:%M:%S', time.gmtime())
        try:
            now = problems(args.rss_gib, args.low_gib, args.disk_warn_gib,
                           args.win_free_gib, args.win_commit_pct)
            for key, msg in now.items():
                if key not in seen:
                    print(f"[{stamp}Z] {msg}", flush=True)
                    if args.notify and key in NOTIFY_KINDS:
                        notify(f"Box watch: {msg}")
            for key in seen - set(now):
                if args.notify and key in NOTIFY_KINDS:
                    notify(f"Box watch: cleared {key.upper()}")
            seen = set(now)
            offset, lines = new_history(offset)
            for ln in lines:
                print(f"[{stamp}Z] {ln}", flush=True)
                if args.notify and "host drive" in ln:
                    notify(f"Box watch: {ln}")
            w = windows_memory()
            tight = "winmem" in now or (w is not None and w["free_gib"] < args.evict_below_gib)
            if args.evict_cache and tight and g.meminfo().get("Cached", 0) > 2 * g.GIB and \
                    time.time() - state.get("last_evict", 0) > EVICT_EVERY_SECS:
                state["last_evict"] = time.time()
                n, gib = evict_page_cache()
                print(f"[{stamp}Z] EVICT dropped the page cache of {n} large files "
                      f"({gib:.1f} GiB released)", flush=True)
        except Exception as e:  # a watcher that dies silently looks like "all clear"
            print(f"WATCHER-ERROR {type(e).__name__}: {e}", flush=True)
        if args.state:
            state.update(seen=sorted(seen), history_offset=offset, checked_utc=g.iso())
            save_state(args.state, state)
        if args.once:
            return 0
        time.sleep(args.interval)


if __name__ == "__main__":
    sys.exit(main())
