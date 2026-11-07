#!/usr/bin/env python3
"""D63 lane L10 (2026-11-07): elaborate truncated copies of a Lean file one after another, each under its own RSS
watchdog (SIGTERM above the limit), to locate an elaboration runaway (the method of results/zk60_lean_l7_20261106's
bisection). Run inside ONE guarded job (run_guarded.py, class cpu).

usage: bisect.py <limit GiB> <time limit s> <file.lean> [more files]
"""
import subprocess
import sys
import time

LAKE = "/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake"
FORMAL = "/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a9f0e162e79db6aa4/formal"

limit = float(sys.argv[1]) * 1024 * 1024  # KiB
tlim = float(sys.argv[2])


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


for f in sys.argv[3:]:
    start = time.time()
    p = subprocess.Popen([LAKE, "-d", FORMAL, "env", "lean", f], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         text=True)
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
        time.sleep(0.5)
    out = p.stdout.read() if p.stdout else ""
    print(f"== {f}: rc {p.returncode} {why} {time.time() - start:.1f} s peak {peak / 1048576:.2f} GiB")
    # the whole message stream, warnings' bodies dropped (a warning runs until the next line naming the file)
    keep, shown = True, []
    for l in out.splitlines():
        if f in l or l.startswith(".lake") or l.startswith("/"):
            keep = ": warning:" not in l
        if keep:
            shown.append(l)
    print("\n".join(shown[:600]), flush=True)
