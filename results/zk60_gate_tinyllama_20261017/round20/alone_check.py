#!/usr/bin/env python3
"""[gate round 20] Is the box free for a job that must run ALONE?  Prints every live or WAITING
guarded job (guard status, the FIFO ticket directory, and every `zk60_resource_guard.py run`
process with its --label, which also shows guards still waiting for admission), the hold files,
and exits 0 only when none is present (other than labels starting with the given own prefix).

    python3 alone_check.py [own-label-prefix]
"""
import json
import os
import subprocess
import sys

G = "/home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py"
HOLDS = ["/home/victor/IntelligenceRegulation/results/zk60_guard_fix_20261021/WINDOW_HOLD",
         "/home/victor/IntelligenceRegulation/results/zk60_gate_tinyllama_20261017/HOLD"]


def guard_procs():
    out = []
    for p in os.listdir("/proc"):
        if not p.isdigit():
            continue
        try:
            with open(f"/proc/{p}/cmdline", "rb") as fh:
                argv = fh.read().split(b"\0")
        except OSError:
            continue
        argv = [a.decode(errors="replace") for a in argv if a]
        if len(argv) >= 3 and argv[1].endswith("zk60_resource_guard.py") and argv[2] == "run":
            label = argv[argv.index("--label") + 1] if "--label" in argv else "?"
            out.append({"pid": int(p), "label": label})
    return out


def main(own=""):
    s = json.loads(subprocess.run(["python3", G, "status", "--json"], capture_output=True, text=True).stdout)
    live = [{"label": j.get("label"), "class": j.get("class"), "need_gib": j.get("need_gib")} for j in s["live_guarded_jobs"]]
    qdir = "/tmp/zk-guard/queue"
    tickets = sorted(os.listdir(qdir)) if os.path.isdir(qdir) else []
    procs = guard_procs()
    holds = [h for h in HOLDS if os.path.exists(h)]
    others = [x for x in live + procs if not str(x.get("label", "")).startswith(own)] if own else live + procs
    rec = {"live_guarded_jobs": live, "fifo_tickets": tickets, "guard_processes": procs, "holds": holds,
           "mem_available_gib": s.get("mem_available_gib"), "committed_gib": s.get("committed_gib"),
           "sol_or_astra": [x for x in live + procs if str(x.get("label", "")).startswith(("sol-", "astra-"))],
           "alone": not others and not holds and not tickets}
    print(json.dumps(rec))
    return 0 if rec["alone"] else 1


if __name__ == "__main__":
    raise SystemExit(main(*sys.argv[1:2]))
