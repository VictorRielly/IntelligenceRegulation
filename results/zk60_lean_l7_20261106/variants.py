#!/usr/bin/env python3
"""D63 step L7 Lean lane (2026-11-06): elaborate several Lean files one after another, each under its own RSS
watchdog (killed above CAP_GIB or after LIMIT s), printing each file's verdict, peak RSS and messages. Used to locate a
proof that runs away while the lane's file was being written. Run as ONE job under the zk60 resource guard
(run_guarded.py, class cpu).

usage: python3 -I variants.py <cap GiB> <limit s> <file.lean> [file.lean ...]
"""
import os
import subprocess
import sys
import time

cap, limit = float(sys.argv[1]), float(sys.argv[2])
WT = "/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a5a7d943600e67a25"
LAKE = "/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake"


def tree_rss(root):
    ps = subprocess.run(["ps", "-A", "-o", "pid=,ppid=,rss="], capture_output=True, text=True).stdout
    kids, rss = {}, {}
    for row in ps.split("\n"):
        f = row.split()
        if len(f) == 3:
            kids.setdefault(int(f[1]), []).append(int(f[0]))
            rss[int(f[0])] = int(f[2])
    tot, stack, seen = 0, [root], []
    while stack:
        q = stack.pop()
        seen.append(q)
        tot += rss.get(q, 0)
        stack.extend(kids.get(q, []))
    return tot / 1048576, seen


for path in sys.argv[3:]:
    out = open(path + ".out", "w")
    start = time.time()
    p = subprocess.Popen([LAKE, "-d", WT + "/formal", "env", "lean", path], stdout=out, stderr=subprocess.STDOUT)
    peak, killed = 0.0, ""
    while p.poll() is None:
        time.sleep(0.5)
        gib, procs = tree_rss(p.pid)
        peak = max(peak, gib)
        if gib > cap:
            killed = f"KILLED rss {gib:.2f} GiB"
        elif time.time() - start > limit:
            killed = "KILLED time"
        if killed:
            for q in reversed(procs):
                try:
                    os.kill(q, 15)
                except OSError:
                    pass
            p.wait()
            break
    out.close()
    print(f"== {os.path.basename(path)}: rc {p.returncode} {killed} peak {peak:.2f} GiB {time.time() - start:.0f} s",
          flush=True)
    print(open(path + ".out").read()[-6000:], flush=True)
