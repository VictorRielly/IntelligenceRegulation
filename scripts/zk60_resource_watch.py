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

Each problem is reported once until it clears; silence means nothing new.
  python3 zk60_resource_watch.py [--interval 10] [--once]
"""
import argparse
import importlib.util
import json
import os
import sys
import time
from pathlib import Path

GUARD = Path(__file__).resolve().parent / "zk60_resource_guard.py"
spec = importlib.util.spec_from_file_location("zk60_guard_for_watch", GUARD)
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)

# processes that are session infrastructure, not jobs (matched on the command line)
INFRA = ("claude", "codex", "ollama", "snapd", "tg-router", "node ")


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


def problems(rss_gib: float, low_gib: float) -> dict[str, str]:
    out: dict[str, str] = {}
    mem = g.meminfo()
    if mem["MemAvailable"] / g.GIB < low_gib:
        out["lowmem"] = f"LOWMEM MemAvailable {mem['MemAvailable'] / g.GIB:.1f} GiB < {low_gib:g} GiB"
    for pid, (_pp, _pg, rss) in g.proc_table().items():
        if rss < rss_gib * g.GIB:
            continue
        cg = cgroup_of(pid)
        cmd = cmdline(pid)
        if "zk60-" in cg or any(k in cmd[:80] for k in INFRA):
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


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--interval", type=float, default=10.0)
    ap.add_argument("--rss-gib", type=float, default=1.5)
    ap.add_argument("--low-gib", type=float, default=3.0)
    ap.add_argument("--once", action="store_true")
    args = ap.parse_args()
    seen: set[str] = set()
    try:
        offset = os.path.getsize(g.HISTORY)
    except OSError:
        offset = 0
    while True:
        try:
            now = problems(args.rss_gib, args.low_gib)
            for key, msg in now.items():
                if key not in seen:
                    print(f"[{time.strftime('%H:%M:%S', time.gmtime())}Z] {msg}", flush=True)
            seen = set(now)
            offset, lines = new_history(offset)
            for ln in lines:
                print(f"[{time.strftime('%H:%M:%S', time.gmtime())}Z] {ln}", flush=True)
        except Exception as e:  # a watcher that dies silently looks like "all clear"
            print(f"WATCHER-ERROR {type(e).__name__}: {e}", flush=True)
        if args.once:
            return 0
        time.sleep(args.interval)


if __name__ == "__main__":
    sys.exit(main())
