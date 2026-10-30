#!/usr/bin/env python3
"""Token round 18: wait for this lane's turn on the heavy slot (one-shot reads, no signals).

usage: wait_turn.py QUEUE_LOG [--need GIB]

CURRENT RULE (coordinator, 2026-10-30 ~08:20 UTC; this file edited 08:2x UTC): returns (exit 0) only when ALL of these
hold, re-checked every 30 s:
  * no hold file exists (r18/HOLD, the coordinator's WINDOW_HOLD);
  * no guard process of ASTRA'S APP (label starting with `astra` or `pm-`; any class) is running or waiting.
Every other lane (Sol `sol-*`, the release prep `irpub-*`, the gate, ...) no longer makes us wait here: the step goes
straight to the guard's normal admission and takes the heavy slot as soon as the heavy lock is free. The lean-memory
rule (a 10.4 GiB proof runs alone) is left to the guard (heavy lock + the 11.89 GiB budget), as the coordinator ruled.
`--need` is still accepted (and logged) so the callers stay unchanged.

OLD RULE (2026-10-29 23:50 - 2026-10-30 08:2x UTC; starved step E behind Sol's back-to-back chain and the release
prep): any other lane's heavy guard process (running or waiting) went first; another lane's light job > 1 GiB blocked
our >= 3 GiB steps; and a >= 3 GiB step also waited while any live guarded job declared > 1 GiB.
Read from `ps -eo comm,args` (the guard's own command line).
"""
import json, os, re, subprocess, sys, time

R = "/home/victor/IntelligenceRegulation"
T = R + "/results/zk60_gpu_classifier_20261030"
HOLDS = [T + "/HOLD", R + "/results/zk60_guard_fix_20261021/WINDOW_HOLD"]
GUARD = R + "/scripts/zk60_resource_guard.py"


def others():
    out = subprocess.run(["ps", "-eo", "comm=,args="], capture_output=True, text=True).stdout.splitlines()
    found = []
    for line in out:
        comm, _, a = line.strip().partition(" ")
        # 01:55 hardening: only a real guard (a python process whose argv runs the guard script); a shell loop whose
        # command line merely mentions the guard (e.g. a watcher's grep) is not a job
        if not comm.startswith("python") or "zk60_resource_guard.py run" not in a or "wait_turn.py" in a:
            continue
        lab = re.search(r"--label (\S+)", a)
        cls = re.search(r"--class (\S+)", a)
        need = re.search(r"--need-gib (\S+)", a)
        label = lab.group(1) if lab else "?"
        if label.startswith("gcl-"):
            continue
        c = cls.group(1) if cls else "?"
        n = float(need.group(1)) if need else {"light": 0.5, "build": 4.0, "cpu": 11.0, "gpu": 5.0}.get(c, 11.0)
        found.append((label, c, n))
    return found


def blocking(need_me):
    """2026-10-30 rule: only Astra's app jobs (labels astra* / pm-*, any class, running or waiting) go first"""
    return [f"{l}({c},{n})" for l, c, n in others() if l.startswith("astra") or l.startswith("pm-")]


def live_big():
    s = json.loads(subprocess.run(["python3", GUARD, "status", "--json"], capture_output=True, text=True).stdout)
    return [f"{j.get('label')}({j.get('need_gib')})" for j in s.get("live_guarded_jobs", []) if j.get("need_gib", 0) > 1.0]


ASTRA_PIPELINE = ("run_durable_app_demo.py", "classifier_pipeline.py", "finish_durable_demo.py")


def astra_pipeline():
    """GPU classifier lane, coordinator 2026-10-30 ~21:18 UTC: Astra's durable demo post is HELD before each native
    prove (its preflight waits until no guarded job at all is live), so a held or waiting Astra job is not yet a
    guard process. Any live process of its pipeline (the demo runner, the classifier pipeline, the finalizer) makes
    this lane wait, covering the gap between its violence and hate categories."""
    out = subprocess.run(["ps", "-eo", "pid=,args="], capture_output=True, text=True).stdout.splitlines()
    found = []
    for line in out:
        pid, _, a = line.strip().partition(" ")
        if "wait_turn.py" in a or " grep " in a:
            continue
        for pat in ASTRA_PIPELINE:
            if pat in a and ("apps/proven-media" in a or "zk60_astra_" in a):
                found.append(f"{pat}[{pid}]")
    return found


def main():
    log = sys.argv[1]
    need = float(sys.argv[sys.argv.index("--need") + 1]) if "--need" in sys.argv else 0.0
    last = 0.0
    while True:
        why = []
        why += [f"hold {h}" for h in HOLDS if os.path.exists(h)]
        why += [f"astra app {o}" for o in blocking(need)]
        why += [f"astra pipeline {o}" for o in astra_pipeline()]
        # 2026-10-30: the waiter's own lean check (live_big) is dropped; the guard's budget enforces it
        if not why:
            return 0
        if time.time() - last > 300:
            with open(log, "a") as f:
                f.write(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()) + " wait: " + "; ".join(why) + "\n")
            last = time.time()
        time.sleep(30)


if __name__ == "__main__":
    sys.exit(main())
