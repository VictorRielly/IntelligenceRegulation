#!/usr/bin/env python3
"""Resource guard for heavy zk60 jobs on the shared 15.4 GiB / 8 GiB-VRAM box.

Why this exists.  On 2026-09-29 the WSL box froze hard at 17:40 PDT (journal
ends mid-run, no OOM line, no shutdown) while a 12-block GPU stack proof,
a 1B calibration run, a Rust build/test, the Python suite and several agent
sessions were all live.  A one-block CPU proof alone peaks near 10.5 GiB of
host RAM (2026-09-27 dense A/B), so heavy jobs cannot overlap on this box.
The old rule ("one heavy job under /tmp/zk-heavy.lock") was voluntary and did
not cover builds, calibration scripts or the "CPU-light" exemption.

INTERFACE (guard the leaf command, never a wrapper that guards its own steps):

  zk60_resource_guard.py run --class {light,build,cpu,gpu} [--label L]
        [--need-gib N] [--cap-gib N] [--wait-secs S] [--max-secs S]
        [--log PATH] [--done PATH] [--result-json PATH] [--no-cgroup]
        -- command args...
  zk60_resource_guard.py status [--json]      memory, budget, locks, GPU, top RSS
  zk60_resource_guard.py check --class C      dry run: would this start now?

What `run` does for one command:
  1. takes the flock files the detached-run protocol already uses, so guarded
     jobs and old-style `flock /tmp/zk-heavy.lock cmd` wrappers serialize
     together.  cpu, gpu AND build jobs all hold /tmp/zk-heavy.lock (a build
     never overlaps a proof); builds then also hold /tmp/zk-build.lock.  Lock
     order is always heavy -> build.  Only `light` jobs (cap 1.5 GiB) run beside
     a heavy job;
  2. admission: waits until the declared memory of all live guarded jobs plus
     this one fits the budget, live MemAvailable covers the job plus a margin,
     swap is unused, and (gpu) the card reads idle and readable;
  3. runs the command in its own systemd scope (kernel MemoryMax, no swap,
     nested in zk60.slice, a 12 GiB group cap) when `systemd-run --user` works,
     so a runaway job is OOM-killed inside its cgroup instead of freezing the
     VM.  The job is tracked by cgroup membership, so children that call
     setsid or double-fork are still counted, capped and killed.  Without
     cgroups it follows the parent chain plus process group instead;
  4. watchdog (0.5 s): kills the whole job if host MemAvailable falls under the
     floor, its RSS passes the cap, VRAM passes the cap or GPU telemetry is
     lost, or --max-secs passes.  A watchdog exception also kills the job;
  5. SIGTERM/SIGINT/SIGHUP to the guard = terminate the job (SIGTERM, grace,
     then SIGKILL), publish the terminal record, then release the locks.  The
     caller should send SIGTERM and WAIT, never SIGKILL the guard;
  6. after the command exits, stragglers still in the job's cgroup are killed
     and counted; for gpu jobs the heavy lock is kept until VRAM has drained;
  7. the lock and registry descriptors are inherited by the job, so if the guard
     itself is SIGKILLed the locks stay held until the job's processes are gone;
  8. EVERY path (refused, launch failed, killed, done) writes one terminal
     record to --result-json (atomic), --done and results/zk60_resource_guard/
     history.jsonl, which survives reboots unlike /tmp.

Terminal record fields callers rely on: exit, child_rc, guard_killed,
child_wall_seconds (Popen to command exit; excludes queue, setup and drain),
peak_rss_gib, peak_cgroup_gib, peak_vram_mib, enforcement, refused.

Exit codes: the command's own code; 70 refused; 71 guard error (job killed);
75 killed by the guard watchdog/signal; 76 command succeeded but the GPU did
not drain (do not start another GPU job until nvidia-smi reads idle); 127
launch failed; 137 from the kernel memory cap.

Nested calls: a guarded job that runs the guard again is refused (its parent
already holds the locks and the budget).  Environment strings are never
trusted as proof of inheritance: a stale ZK60_GUARD_JOB is ignored and the
call is treated as top level with full admission.  Code running inside a
guarded job that must take a lock itself should read ZK60_GUARD_HELD_LOCKS
(informational) and skip the ones listed.
"""
from __future__ import annotations

import argparse
import fcntl
import json
import math
import os
import signal
import subprocess
import sys
import time
import uuid
from pathlib import Path

GIB = 1024 ** 3
MIB = 1024 ** 2
REPO = Path(__file__).resolve().parents[1]

STATE_DIR = Path(os.environ.get("ZK60_GUARD_DIR", "/tmp/zk-guard"))
HEAVY_LOCK = Path(os.environ.get("ZK60_HEAVY_LOCK", "/tmp/zk-heavy.lock"))
BUILD_LOCK = Path(os.environ.get("ZK60_BUILD_LOCK", "/tmp/zk-build.lock"))
LOCKS = {"heavy": HEAVY_LOCK, "build": BUILD_LOCK}
HISTORY = Path(os.environ.get(
    "ZK60_GUARD_HISTORY", str(REPO / "results/zk60_resource_guard/history.jsonl")))
MEMINFO = os.environ.get("ZK60_GUARD_MEMINFO", "/proc/meminfo")
NVIDIA_SMI = os.environ.get("ZK60_GUARD_NVIDIA_SMI", "nvidia-smi")
SLICE_UNIT = Path.home() / ".config/systemd/user/zk60.slice"

# Declared memory (need, for admission) and hard cap, in GiB, per job class.
# cpu/gpu numbers are the 2026-09-27 dense one-block A/B host high-water marks
# (10,524 / 4,411.5 MiB) with headroom; replace with history.jsonl peaks once
# 12-block and trained-stack runs have been measured.  Locks are taken in the
# listed order (heavy before build) and never reversed, so waiters cannot
# deadlock against legacy wrappers that nest build inside heavy.
CLASSES = {
    "light": {"need": 0.5, "cap": 1.5, "locks": []},
    "build": {"need": 4.0, "cap": 5.5, "locks": ["heavy", "build"]},
    "cpu": {"need": 11.0, "cap": 11.5, "locks": ["heavy"]},
    "gpu": {"need": 5.0, "cap": 6.5, "locks": ["heavy"]},
}
RESERVE_GIB = 3.5          # left for the OS, page cache, agent sessions
ADMIT_MARGIN_GIB = 1.0     # live MemAvailable must cover need + this
FLOOR_GIB = 1.2            # watchdog kills the job under this MemAvailable
VRAM_IDLE_MIB = 400        # card counts as idle at or below this
VRAM_CAP_MIB = 7400        # of 8,188: above this WSL starts thrashing the host
GPU_BLIND_LIMIT = 5        # consecutive unreadable GPU samples (2 s apart) = kill
VRAM_DRAIN_SECS = float(os.environ.get("ZK60_GUARD_DRAIN_SECS", "180"))
TERM_GRACE_SECS = float(os.environ.get("ZK60_GUARD_TERM_GRACE_SECS", "15"))

EXIT_REFUSED = 70
EXIT_GUARD_ERROR = 71
EXIT_KILLED = 75
EXIT_GPU_DRAIN = 76
EXIT_LAUNCH_FAILED = 127


def now() -> float:
    return time.time()


def iso(t: float | None = None) -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(t if t else now()))


def log(msg: str) -> None:
    print(f"[zk60-guard {time.strftime('%H:%M:%S')}] {msg}", file=sys.stderr, flush=True)


def write_atomic(path: str | Path, text: str) -> None:
    tmp = Path(str(path) + f".tmp{os.getpid()}")
    tmp.write_text(text)
    os.replace(tmp, path)


def append_history(rec: dict) -> None:
    try:
        HISTORY.parent.mkdir(parents=True, exist_ok=True)
        with open(HISTORY, "a") as h:
            h.write(json.dumps(rec) + "\n")
    except OSError as e:
        log(f"history not written: {e}")


def identity() -> dict:
    """Evidence that survives reboots and pid namespaces (a bare pid does not)."""
    out: dict = {"guard_pid": os.getpid()}
    for key, path in (("boot_id", "/proc/sys/kernel/random/boot_id"),):
        try:
            out[key] = Path(path).read_text().strip()
        except OSError:
            out[key] = None
    try:
        out["pid_ns"] = os.readlink("/proc/self/ns/pid")
    except OSError:
        out["pid_ns"] = None
    try:
        stat = Path("/proc/self/stat").read_text()
        out["guard_starttime_ticks"] = int(stat[stat.rindex(")") + 2:].split()[19])
    except (OSError, ValueError, IndexError):
        out["guard_starttime_ticks"] = None
    ids = {}
    for name, p in LOCKS.items():
        try:
            st = os.stat(p)
            ids[name] = f"{st.st_dev}:{st.st_ino}"
        except OSError:
            ids[name] = None
    out["lock_ids"] = ids
    return out


# ---------------------------------------------------------------- probes ----

def meminfo() -> dict[str, int]:
    out: dict[str, int] = {}
    with open(MEMINFO) as f:
        for line in f:
            k, _, v = line.partition(":")
            parts = v.split()
            if parts:
                out[k] = int(parts[0]) * 1024
    return out


def gpu_used_mib() -> tuple[int, int] | None:
    """(used, total) MiB from nvidia-smi, or None if it cannot be read."""
    try:
        r = subprocess.run(
            [NVIDIA_SMI, "--query-gpu=memory.used,memory.total",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=8)
        if r.returncode != 0:
            return None
        used, total = (int(x) for x in r.stdout.strip().splitlines()[0].split(","))
        return used, total
    except (OSError, ValueError, IndexError, subprocess.TimeoutExpired):
        return None


def proc_table() -> dict[int, tuple[int, int, int]]:
    """pid -> (ppid, pgrp, rss_bytes) for every visible process."""
    table: dict[int, tuple[int, int, int]] = {}
    page = os.sysconf("SC_PAGE_SIZE")
    try:
        names = [p for p in os.listdir("/proc") if p.isdigit()]
    except OSError:
        return table
    for p in names:
        try:
            with open(f"/proc/{p}/stat") as f:
                stat = f.read()
            # comm may contain spaces/parens: split after the last ')'
            fields = stat[stat.rindex(")") + 2:].split()  # [state, ppid, pgrp, ...]
            with open(f"/proc/{p}/statm") as f:
                rss = int(f.read().split()[1]) * page
            table[int(p)] = (int(fields[1]), int(fields[2]), rss)
        except (OSError, ValueError, IndexError):
            continue
    return table


def top_processes(n: int = 6) -> list[dict]:
    rows = []
    for pid, (_pp, _pg, rss) in proc_table().items():
        if rss < 200 * MIB:
            continue
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                cmd = f.read().replace(b"\0", b" ").decode("utf-8", "replace")[:110]
        except OSError:
            continue
        rows.append({"pid": pid, "rss_mib": rss // MIB, "cmd": cmd})
    rows.sort(key=lambda r: -r["rss_mib"])
    return rows[:n]


def systemd_scope_ok() -> bool:
    try:
        r = subprocess.run(
            ["systemd-run", "--user", "--scope", "--quiet", "-p", "MemoryMax=64M", "true"],
            capture_output=True, timeout=10)
        return r.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def _alive(pid: int) -> bool:
    """Exists and is not a zombie."""
    try:
        with open(f"/proc/{pid}/stat") as f:
            stat = f.read()
        return stat[stat.rindex(")") + 2] != "Z"
    except (OSError, ValueError, IndexError):
        return False


class Tracker:
    """Everything the job has started, however it detached.

    In cgroup mode the source of truth is the scope's cgroup.procs, which
    setsid, double forks and reparenting cannot escape.  Otherwise it is the
    union of the parent-chain descendants and the process group of the root."""

    def __init__(self, root_pid: int, expect_cgroup: bool, expected_unit: str | None = None):
        self.root = root_pid
        self.expect_cgroup = expect_cgroup
        if expect_cgroup and (not expected_unit or not expected_unit.startswith("zk60-")
                              or not expected_unit.endswith(".scope") or "/" in expected_unit):
            raise ValueError("cgroup tracking requires this job's explicit zk60 scope unit")
        self.expected_unit = expected_unit
        self.cg: Path | None = None
        self.peak_cgroup = 0

    def _discover_cgroup(self) -> None:
        if self.cg or not self.expect_cgroup:
            return
        candidates = []
        try:
            with open(f"/proc/{self.root}/cgroup") as f:
                candidates.append(f.read().strip().split(":", 2)[2])
        except (OSError, IndexError):
            pass
        # An early Popen process can still inhabit the caller's session
        # scope. Adopt only the exact UUID-named scope created for this job.
        for path in candidates:
            if Path(path).name == self.expected_unit and Path(path).is_absolute():
                cand = Path("/sys/fs/cgroup") / path.lstrip("/")
                if (cand / "cgroup.procs").exists():
                    self.cg = cand
                    return
        # The immediate process may already have exited while descendants
        # remain in the scope. Resolve by unit identity, never by a guessed
        # parent scope or by another process's current session membership.
        try:
            result = subprocess.run(
                ["systemctl", "--user", "show", "--property=ControlGroup", "--value", self.expected_unit],
                capture_output=True, text=True, timeout=5)
            path = result.stdout.strip()
            if result.returncode == 0 and Path(path).is_absolute() and Path(path).name == self.expected_unit:
                cand = Path("/sys/fs/cgroup") / path.lstrip("/")
                if (cand / "cgroup.procs").exists():
                    self.cg = cand
        except (OSError, subprocess.TimeoutExpired):
            pass

    def pids(self, table: dict) -> set[int]:
        self._discover_cgroup()
        if self.cg:
            try:
                return {int(x) for x in (self.cg / "cgroup.procs").read_text().split()}
            except (OSError, ValueError):
                pass
        found = {self.root}
        frontier = [self.root]
        kids: dict[int, list[int]] = {}
        for pid, (ppid, _pg, _r) in table.items():
            kids.setdefault(ppid, []).append(pid)
        while frontier:
            for c in kids.get(frontier.pop(), []):
                if c not in found:
                    found.add(c)
                    frontier.append(c)
        found |= {pid for pid, (_pp, pg, _r) in table.items() if pg == self.root}
        return found

    def sample(self) -> tuple[int, set[int]]:
        table = proc_table()
        pids = self.pids(table)
        if self.cg:
            try:
                self.peak_cgroup = max(self.peak_cgroup, int((self.cg / "memory.peak").read_text()))
            except (OSError, ValueError):
                pass
        return sum(table[p][2] for p in pids if p in table), pids

    def live(self) -> set[int]:
        return {p for p in self.pids(proc_table()) if _alive(p)}

    def _signal_all(self, sig: int) -> None:
        for pid in self.live():
            try:
                os.kill(pid, sig)
            except (ProcessLookupError, PermissionError):
                pass

    def kill(self) -> int:
        """SIGTERM the tree, wait a grace period, then SIGKILL what is left.
        Returns how many processes needed the hard kill."""
        self._signal_all(signal.SIGTERM)
        t = now()
        while now() - t < TERM_GRACE_SECS:
            if not self.live():
                return 0
            time.sleep(0.2)
        left = self.live()
        if not left:
            return 0
        if self.cg:
            try:
                (self.cg / "cgroup.kill").write_text("1")
            except OSError:
                self._signal_all(signal.SIGKILL)
        else:
            self._signal_all(signal.SIGKILL)
            try:
                os.killpg(self.root, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
        t = now()
        while now() - t < 5 and self.live():
            time.sleep(0.1)
        return len(left)


# --------------------------------------------------------------- registry ---

class Stopped(Exception):
    """The guard received a termination signal while still waiting."""


def _ensure_dirs() -> Path:
    jobs = STATE_DIR / "jobs"
    jobs.mkdir(parents=True, exist_ok=True)
    try:
        os.chmod(STATE_DIR, 0o1777)
        os.chmod(jobs, 0o1777)
    except OSError:
        pass
    return jobs


def _file_held(path: Path) -> bool:
    """True if some process holds an flock on `path` (i.e. the job is live)."""
    try:
        fd = os.open(path, os.O_RDONLY)
    except OSError:
        return False
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        fcntl.flock(fd, fcntl.LOCK_UN)
        return False
    except BlockingIOError:
        return True
    finally:
        os.close(fd)


def _live_jobs(jobs_dir: Path) -> list[dict]:
    """Jobs whose guard (or job process) is alive.  A job file is held under
    LOCK_EX for the job's lifetime, so a file that can be locked is stale."""
    live = []
    for p in sorted(jobs_dir.glob("*.json")):
        try:
            fd = os.open(p, os.O_RDONLY)
        except OSError:
            continue
        try:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                try:
                    live.append(json.loads(p.read_text()))
                except (OSError, ValueError):
                    pass
                continue
            try:
                p.unlink()
            except OSError:
                pass
        finally:
            os.close(fd)
    return live


def budget_gib(mem: dict[str, int]) -> float:
    return max(1.0, mem["MemTotal"] / GIB - RESERVE_GIB)


def admission_verdict(cls: str, need_gib: float, jobs_dir: Path) -> list[str]:
    """Reasons the job cannot start right now (empty list = admit)."""
    mem = meminfo()
    reasons = []
    live = _live_jobs(jobs_dir)
    committed = sum(j["need_gib"] for j in live)
    budget = budget_gib(mem)
    if committed + need_gib > budget + 1e-9:
        who = ", ".join(f"{j['label']}({j['class']},{j['need_gib']:g}G)" for j in live)
        reasons.append(f"budget: {committed:g}+{need_gib:g} GiB > {budget:.1f} GiB "
                       f"with live [{who}]")
    avail = mem["MemAvailable"] / GIB
    if avail < need_gib + ADMIT_MARGIN_GIB:
        reasons.append(f"MemAvailable {avail:.1f} GiB < need {need_gib:g} + "
                       f"margin {ADMIT_MARGIN_GIB:g}")
    if mem.get("SwapTotal", 0) - mem.get("SwapFree", 0) > 1 * GIB:
        reasons.append("swap in use > 1 GiB (box is already under pressure)")
    if cls == "gpu":
        g = gpu_used_mib()
        if g is None:
            reasons.append("nvidia-smi unreadable: cannot verify the card is idle")
        elif g[0] > VRAM_IDLE_MIB:
            reasons.append(f"VRAM {g[0]} MiB in use > idle {VRAM_IDLE_MIB} MiB")
        if any(j["class"] == "gpu" for j in live):
            reasons.append("another guarded gpu job is live")
    if cls != "light" and any(j["class"] in ("cpu", "gpu", "build") for j in live):
        reasons.append("another heavy guarded job is live (one heavy job at a time)")
    return reasons


def _flock_wait(path: Path, deadline: float | None, what: str, stop: dict):
    """Acquire an exclusive flock on `path`, polling so a timeout or a
    termination signal can interrupt the wait.  Returns the fd, or None on
    timeout; raises Stopped on a signal."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(path, os.O_RDWR | os.O_CREAT, 0o666)
    try:
        os.chmod(path, 0o666)
    except OSError:
        pass
    t0, last = now(), 0.0
    while True:
        if stop["sig"]:
            os.close(fd)
            raise Stopped()
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return fd
        except BlockingIOError:
            if deadline and now() >= deadline:
                os.close(fd)
                return None
            if now() - last > 60:
                log(f"waiting for {what} ({now() - t0:.0f}s)")
                last = now()
            time.sleep(min(1.0, max(0.05, deadline - now())) if deadline else 1.0)


def _bad_number(name: str, v: float | None, allow_zero: bool) -> str | None:
    if v is None:
        return None
    if not math.isfinite(v) or v < 0 or (v == 0 and not allow_zero):
        return f"--{name} must be a finite {'non-negative' if allow_zero else 'positive'} number, got {v!r}"
    return None


# --------------------------------------------------------------------- run --

def cmd_run(args: argparse.Namespace) -> int:
    cls = args.cls
    spec = CLASSES[cls]
    command = list(args.command)
    if command and command[0] == "--":
        command = command[1:]
    label = args.label or (Path(command[0]).name if command else "none")
    run_id = uuid.uuid4().hex[:12]
    need = args.need_gib if args.need_gib is not None else spec["need"]
    cap = args.cap_gib if args.cap_gib is not None else max(spec["cap"], need)
    if args.need_gib is None and args.cap_gib is not None and math.isfinite(cap) and 0 < cap < need:
        need = cap  # a caller that only tightens the cap is asking for a smaller job
    ident = identity()
    stop = {"sig": None}

    def terminal(exit_code: int, **fields) -> int:
        rec = {"ts_end": iso(), "run_id": run_id, "label": label, "class": cls,
               "cmd": command[:8], "need_gib": need, "cap_gib": cap, "exit": exit_code,
               "child_rc": None, "guard_killed": None, "child_wall_seconds": None,
               "refused": None, "guard_error": None, **ident, **fields}
        append_history(rec)
        try:
            if args.result_json:
                write_atomic(args.result_json, json.dumps(rec, indent=1) + "\n")
            if args.done:
                write_atomic(args.done, f"{exit_code}\n")
        except OSError as e:
            log(f"terminal record not written to caller paths: {e}")
        return exit_code

    def refuse(why: str) -> int:
        log(f"REFUSED: {why}")
        return terminal(EXIT_REFUSED, refused=why)

    if not command:
        return refuse("no command given")
    for name, v, zero_ok in (("need-gib", args.need_gib, False), ("cap-gib", args.cap_gib, False),
                             ("wait-secs", args.wait_secs, True), ("max-secs", args.max_secs, True)):
        bad = _bad_number(name, v, zero_ok)
        if bad:
            return refuse(bad)
    if cap < need:
        return refuse(f"--cap-gib {cap:g} is below --need-gib {need:g}")

    parent_job = os.environ.get("ZK60_GUARD_JOB")
    if parent_job and _file_held(Path(parent_job)):
        return refuse("nested guard call: this process is inside a live guarded job "
                      f"({parent_job}), which already holds the locks and the budget; "
                      "guard the leaf command from the outside instead")

    try:
        jobs_dir = _ensure_dirs()
        mem0 = meminfo()
    except OSError as e:
        return refuse(f"guard state unavailable: {e}")
    inherited = {x for x in os.environ.get("ZK60_GUARD_HELD_LOCKS", "").split(",") if x}
    deadline = now() + args.wait_secs if args.wait_secs else None
    if need > budget_gib(mem0):
        return refuse(f"need {need:g} GiB exceeds the whole job budget "
                      f"{budget_gib(mem0):.1f} GiB (MemTotal {mem0['MemTotal'] / GIB:.1f} - "
                      f"reserve {RESERVE_GIB:g}); this job cannot run on this box")

    def on_signal(signum, _frame):
        stop["sig"] = signum
    old_handlers = {s: signal.signal(s, on_signal)
                    for s in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP)}

    lock_fds: list[int] = []
    job_fd = None
    job_path = jobs_dir / f"{run_id}.json"
    tracker: Tracker | None = None
    proc = None
    terminal_written = False
    t_queue = now()
    try:
        # ---- locks, then admission (re-checked every 5 s) ----
        try:
            for name in spec["locks"]:
                if name in inherited:  # env strings are not proof: the lock is taken for real
                    log(f"ignoring ZK60_GUARD_HELD_LOCKS entry {name!r} (no live parent job)")
                fd = _flock_wait(LOCKS[name], deadline, str(LOCKS[name]), stop)
                if fd is None:
                    return refuse(f"could not take {LOCKS[name]} within {args.wait_secs:g}s")
                lock_fds.append(fd)
            last = 0.0
            while True:
                adm_fd = _flock_wait(STATE_DIR / "admit.lock", None, "admission lock", stop)
                try:
                    reasons = admission_verdict(cls, need, jobs_dir)
                    if not reasons:
                        rec = {"run_id": run_id, "label": label, "class": cls, "need_gib": need,
                               "cap_gib": cap, "pid": os.getpid(), "started": iso(),
                               "boot_id": ident["boot_id"], "pid_ns": ident["pid_ns"],
                               "cmd": command[:6]}
                        job_fd = os.open(job_path, os.O_RDWR | os.O_CREAT, 0o666)
                        fcntl.flock(job_fd, fcntl.LOCK_EX)
                        os.write(job_fd, json.dumps(rec).encode())
                        break
                finally:
                    fcntl.flock(adm_fd, fcntl.LOCK_UN)
                    os.close(adm_fd)
                if deadline and now() >= deadline:
                    return refuse("after waiting: " + "; ".join(reasons))
                if now() - last > 60:
                    log("admission waiting: " + "; ".join(reasons))
                    last = now()
                t = now()
                while now() - t < (min(5.0, max(0.1, deadline - now())) if deadline else 5.0):
                    if stop["sig"]:
                        raise Stopped()
                    time.sleep(0.1)
        except Stopped:
            return refuse(f"terminated by signal {stop['sig']} while waiting to start")
        waited = now() - t_queue

        # ---- launch ----
        use_cgroup = (not args.no_cgroup) and systemd_scope_ok()
        argv = command
        scope_unit = f"zk60-{run_id}.scope" if use_cgroup else None
        if use_cgroup:
            pre = ["systemd-run", "--user", "--scope", "--quiet", "--unit=" + scope_unit]
            if SLICE_UNIT.exists():
                pre.append("--slice=zk60.slice")
            pre += ["-p", f"MemoryMax={int(cap * GIB)}", "-p", "MemorySwapMax=0", "--"]
            argv = pre + command
        enforcement = "cgroup+watchdog" if use_cgroup else "watchdog-only"
        log(f"START {label} class={cls} need={need:g}G cap={cap:g}G "
            f"enforce={enforcement} waited={waited:.0f}s run={run_id}")
        out = None
        if args.log:
            Path(args.log).parent.mkdir(parents=True, exist_ok=True)
            out = open(args.log, "ab")
        # The job inherits the lock/registry descriptors (same open file descriptions):
        # if this guard is killed, they stay held until the job's own processes are gone.
        held = tuple(lock_fds) + ((job_fd,) if job_fd is not None else ())
        child_env = dict(os.environ)
        child_env["ZK60_GUARD_HELD_LOCKS"] = ",".join(sorted(inherited | set(spec["locks"])))
        child_env["ZK60_GUARD_JOB"] = str(job_path)
        child_env["ZK60_GUARD_RUN_ID"] = run_id
        t0 = now()
        try:
            proc = subprocess.Popen(argv, stdout=out or None,
                                    stderr=subprocess.STDOUT if out else None,
                                    start_new_session=True, pass_fds=held, env=child_env)
        except OSError as e:
            if out:
                out.close()
            log(f"LAUNCH FAILED: {e}")
            terminal_written = True
            return terminal(EXIT_LAUNCH_FAILED, guard_error=f"launch failed: {e}",
                            enforcement=enforcement, waited_s=round(waited, 1))
        tracker = Tracker(proc.pid, use_cgroup, scope_unit)

        peak_rss = 0
        peak_vram = None  # None = never sampled; 0 = sampled and idle
        min_avail = mem0["MemAvailable"]
        killed_reason = None
        guard_error = None
        gpu_blind = 0
        gpu_lost = False
        hard_killed = 0
        last_gpu = 0.0
        try:
            while proc.poll() is None:
                time.sleep(0.5)
                if proc.poll() is not None:
                    break
                reason = None
                if stop["sig"]:
                    reason = f"guard received signal {stop['sig']}"
                mem = meminfo()
                min_avail = min(min_avail, mem["MemAvailable"])
                rss, _pids = tracker.sample()
                peak_rss = max(peak_rss, rss)
                if not reason and mem["MemAvailable"] < FLOOR_GIB * GIB:
                    reason = (f"host MemAvailable {mem['MemAvailable'] / GIB:.2f} GiB "
                              f"< floor {FLOOR_GIB:g} GiB")
                elif not reason and rss > cap * GIB * 1.02:
                    reason = f"job RSS {rss / GIB:.2f} GiB > cap {cap:g} GiB"
                if cls == "gpu" and now() - last_gpu >= 2:
                    last_gpu = now()
                    g = gpu_used_mib()
                    if g:
                        gpu_blind = 0
                        peak_vram = max(peak_vram or 0, g[0])
                        if g[0] > VRAM_CAP_MIB and not reason:
                            reason = f"VRAM {g[0]} MiB > cap {VRAM_CAP_MIB} MiB"
                    else:
                        gpu_blind += 1
                        if gpu_blind >= GPU_BLIND_LIMIT and not reason:
                            gpu_lost = True
                            reason = f"GPU telemetry lost ({gpu_blind} unreadable samples)"
                if not reason and args.max_secs and now() - t0 > args.max_secs:
                    reason = f"exceeded --max-secs {args.max_secs:g}"
                if reason:
                    killed_reason = reason
                    log(f"KILL {label}: {reason}")
                    hard_killed += tracker.kill()
                    break
        except Exception as e:  # the watchdog must never leave a job running unobserved
            guard_error = f"watchdog failed: {type(e).__name__}: {e}"
            log(f"KILL {label}: {guard_error}")
            hard_killed += tracker.kill()
        rc = proc.wait()
        child_wall = now() - t0
        # The command has exited; whatever it left running (setsid daemons, orphans)
        # is still ours to clean up before the locks are released.
        stragglers = 0
        try:
            leftover = {p for p in tracker.sample()[1] if p != proc.pid and _alive(p)}
            if leftover:
                stragglers = len(leftover)
                log(f"{label}: {stragglers} straggler process(es) outlived the command; killing")
                hard_killed += tracker.kill()
        except Exception as e:
            guard_error = guard_error or f"straggler sweep failed: {type(e).__name__}: {e}"
        if out:
            out.close()
        if rc < 0:  # died from a signal: report it the way a shell does (128+N)
            rc = 128 - rc

        # ---- GPU drain: hold the heavy lock until the card is idle again ----
        drained = None
        drain_failed = False
        if cls == "gpu":
            t = now()
            while now() - t < VRAM_DRAIN_SECS:
                g = gpu_used_mib()
                if g and g[0] <= VRAM_IDLE_MIB:
                    drained = round(now() - t, 1)
                    break
                time.sleep(2 if VRAM_DRAIN_SECS > 10 else 0.5)
            if drained is None:
                drain_failed = True
                log(f"WARNING: VRAM not idle/readable {VRAM_DRAIN_SECS:g}s after exit; "
                    "do not start another GPU job until nvidia-smi reads idle")

        if guard_error:
            exit_code = EXIT_GUARD_ERROR
        elif killed_reason:
            exit_code = EXIT_KILLED
        elif drain_failed and rc == 0:
            exit_code = EXIT_GPU_DRAIN
        else:
            exit_code = rc
        terminal_written = True
        code = terminal(
            exit_code, child_rc=rc, guard_killed=killed_reason, guard_error=guard_error,
            enforcement=enforcement, waited_s=round(waited, 1),
            guard_wall_s=round(now() - t0, 1), child_wall_seconds=child_wall,
            stragglers_killed=stragglers, hard_killed=hard_killed,
            peak_rss_gib=round(peak_rss / GIB, 2),
            peak_cgroup_gib=round(tracker.peak_cgroup / GIB, 2) if tracker.peak_cgroup else None,
            peak_vram_mib=peak_vram, min_mem_available_gib=round(min_avail / GIB, 2),
            vram_drain_s=drained, gpu_drain_failed=drain_failed, gpu_telemetry_lost=gpu_lost,
            note=("exit 137 with no guard reason = kernel memory cap or an outside kill. "
                  "peak_rss is the sum of process RSS sampled at 0.5 s (can under-read a "
                  "fast spike); peak_cgroup is the kernel high-water mark and includes "
                  "reclaimable page cache"))
        log(f"END {label} exit={exit_code} child_wall={child_wall:.0f}s "
            f"peak_rss={peak_rss / GIB:.2f}G min_avail={min_avail / GIB:.2f}G"
            + (f" peak_vram={peak_vram}MiB" if peak_vram is not None else ""))
        return code
    except BaseException as e:
        # Anything unexpected between launch and the terminal record: kill the job,
        # say so, and only then let the locks go.
        if proc is not None and tracker is not None:
            try:
                tracker.kill()
            except Exception:
                pass
        if not terminal_written:
            terminal_written = True
            return terminal(EXIT_GUARD_ERROR,
                            guard_error=f"unexpected {type(e).__name__}: {e}")
        raise
    finally:
        for s, h in old_handlers.items():
            signal.signal(s, h)
        if proc is not None and tracker is not None and tracker.live():
            try:
                tracker.kill()
            except Exception:
                pass
        if job_fd is not None:
            try:
                job_path.unlink()
            except OSError:
                pass
            os.close(job_fd)
        for fd in lock_fds:
            os.close(fd)


# ------------------------------------------------------------ status/check --

def _lock_free(p: Path) -> bool | None:
    try:
        fd = os.open(p, os.O_RDWR | os.O_CREAT, 0o666)
    except OSError:
        return None
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        fcntl.flock(fd, fcntl.LOCK_UN)
        return True
    except BlockingIOError:
        return False
    finally:
        os.close(fd)


def snapshot() -> dict:
    jobs_dir = _ensure_dirs()
    mem = meminfo()
    live = _live_jobs(jobs_dir)
    g = gpu_used_mib()
    return {
        "mem_total_gib": round(mem["MemTotal"] / GIB, 2),
        "mem_available_gib": round(mem["MemAvailable"] / GIB, 2),
        "swap_used_gib": round((mem.get("SwapTotal", 0) - mem.get("SwapFree", 0)) / GIB, 2),
        "job_budget_gib": round(budget_gib(mem), 2),
        "committed_gib": round(sum(j["need_gib"] for j in live), 2),
        "live_guarded_jobs": live,
        "heavy_lock_free": _lock_free(HEAVY_LOCK),
        "build_lock_free": _lock_free(BUILD_LOCK),
        "gpu_used_mib": g[0] if g else None,
        "gpu_total_mib": g[1] if g else None,
        "top_processes": top_processes(),
        "kernel_memory_cap_available": systemd_scope_ok(),
    }


def cmd_status(args: argparse.Namespace) -> int:
    s = snapshot()
    if args.json:
        print(json.dumps(s, indent=1))
        return 0
    print(f"RAM   {s['mem_available_gib']} GiB available of {s['mem_total_gib']}; "
          f"swap used {s['swap_used_gib']} GiB")
    print(f"BUDGET {s['committed_gib']} of {s['job_budget_gib']} GiB committed by guarded jobs")
    for j in s["live_guarded_jobs"]:
        print(f"  job  {j['label']:<28} {j['class']:<5} need {j['need_gib']:g}G "
              f"since {j['started']}")
    print(f"LOCKS heavy {'free' if s['heavy_lock_free'] else 'HELD'}, "
          f"build {'free' if s['build_lock_free'] else 'HELD'}")
    print(f"GPU   {s['gpu_used_mib']} of {s['gpu_total_mib']} MiB used"
          if s["gpu_used_mib"] is not None else "GPU   unreadable")
    print(f"kernel memory cap available: {s['kernel_memory_cap_available']}")
    for p in s["top_processes"]:
        print(f"  rss {p['rss_mib']:>6} MiB  pid {p['pid']:<7} {p['cmd']}")
    return 0


def cmd_check(args: argparse.Namespace) -> int:
    spec = CLASSES[args.cls]
    need = args.need_gib if args.need_gib is not None else spec["need"]
    if _bad_number("need-gib", need, False):
        print("REFUSE: " + _bad_number("need-gib", need, False))
        return 1
    reasons = admission_verdict(args.cls, need, _ensure_dirs())
    for name in spec["locks"]:
        if _lock_free(LOCKS[name]) is False:
            reasons.append(f"{LOCKS[name]} is held")
    if reasons:
        print("WOULD WAIT/REFUSE: " + "; ".join(reasons))
        return 1
    print("OK to start now")
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="sub", required=True)

    r = sub.add_parser("run", help="run a command under admission control and caps")
    r.add_argument("--class", dest="cls", choices=sorted(CLASSES), required=True)
    r.add_argument("--label")
    r.add_argument("--need-gib", type=float, help="declared host RAM for admission")
    r.add_argument("--cap-gib", type=float, help="hard cap (kernel + watchdog)")
    r.add_argument("--wait-secs", type=float, default=0,
                   help="give up (exit 70) after this long; 0 = wait indefinitely")
    r.add_argument("--max-secs", type=float, default=0, help="kill the job after this long")
    r.add_argument("--log", help="append the job's stdout+stderr here")
    r.add_argument("--done", help="write the exit code here when finished (also on refusal)")
    r.add_argument("--result-json", help="write the terminal record here (also on refusal)")
    r.add_argument("--no-cgroup", action="store_true",
                   help="watchdog only (also used by the unit tests)")
    r.add_argument("command", nargs=argparse.REMAINDER)
    r.set_defaults(fn=cmd_run)

    s = sub.add_parser("status", help="memory, budget, locks, GPU and top processes")
    s.add_argument("--json", action="store_true")
    s.set_defaults(fn=cmd_status)

    c = sub.add_parser("check", help="dry run: would a job of this class start now?")
    c.add_argument("--class", dest="cls", choices=sorted(CLASSES), required=True)
    c.add_argument("--need-gib", type=float)
    c.set_defaults(fn=cmd_check)

    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
