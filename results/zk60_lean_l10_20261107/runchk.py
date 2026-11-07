#!/usr/bin/env python3
"""D63 lane L10 (2026-11-07): run this lane's checker (ExecOpeningCheck.lean, `lean --run`) on a corpus under an RSS
and a wall-clock watchdog (SIGTERM above either), its output to a log; print the run's verdict line, time and peak.
Run inside ONE guarded job (run_guarded.py, class cpu).

usage: runchk.py <limit GiB> <time limit s> <corpus> <log>
"""
import subprocess
import sys
import time

LAKE = "/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake"
WT = "/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a9f0e162e79db6aa4"
CHECK = WT + "/formal/ZK60Formal/ExecOpeningCheck.lean"

limit = float(sys.argv[1]) * 1024 * 1024  # KiB
tlim = float(sys.argv[2])
corpus, logf = sys.argv[3], sys.argv[4]


def tree_rss(pid):
    out = subprocess.run(["ps", "-A", "-o", "pid=,ppid=,rss="], capture_output=True, text=True).stdout
    kids, rss = {}, {}
    for line in out.splitlines():
        p, pp, r = (int(x) for x in line.split())
        kids.setdefault(pp, []).append(p)
        rss[p] = r
    tot, stack = 0, [pid]
    while stack:
        p = stack.pop()
        tot += rss.get(p, 0)
        stack.extend(kids.get(p, []))
    return tot


start = time.time()
with open(logf, "w") as lf:
    p = subprocess.Popen([LAKE, "-d", WT + "/formal", "env", "lean", "--run", CHECK, corpus], stdout=lf,
                         stderr=subprocess.STDOUT)
    peak, why = 0, ""
    while p.poll() is None:
        r = tree_rss(p.pid)
        peak = max(peak, r)
        if r > limit:
            why = "RSS limit"
        elif time.time() - start > tlim:
            why = "time limit"
        if why:
            subprocess.run(["pkill", "-TERM", "-P", str(p.pid)])
            p.terminate()
            p.wait()
            break
        time.sleep(1)
print(f"== checker on {corpus}: rc {p.returncode} {why} {time.time() - start:.1f} s peak {peak / 1048576:.2f} GiB")
lines = open(logf).read().splitlines()
for l in lines:
    if l.startswith("FAIL") or l.startswith("L10Check") or "parse error" in l:
        print(l)
print("last lines:")
print("\n".join(lines[-8:]), flush=True)
sys.exit(p.returncode if p.returncode is not None else 1)
