#!/usr/bin/env python3
"""D63 step L7 Lean lane (2026-11-06): elaborate truncated copies of one Lean file (an `#exit` inserted before each
given line), each under its own RSS watchdog (killed above CAP_GIB or after LIMIT s), to find the declaration that
runs away. Run as ONE job under the zk60 resource guard (run_guarded.py, class cpu).

usage: python3 -I bisect.py <file.lean> <workdir> <cap GiB> <limit s> <line> [line ...]   (line 0 = the whole file)
"""
import os
import subprocess
import sys
import time

src, work, cap, limit = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
cuts = [int(a) for a in sys.argv[5:]]
WT = "/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a5a7d943600e67a25"
LAKE = "/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake"
lines = open(src).read().split("\n")
os.makedirs(work, exist_ok=True)
for cut in cuts:
    body = lines if cut == 0 else lines[: cut - 1] + ["#exit"] + lines[cut - 1:]
    path = os.path.join(work, f"cut{cut}.lean")
    open(path, "w").write("\n".join(body))
    out = open(path + ".out", "w")
    start = time.time()
    p = subprocess.Popen([LAKE, "-d", WT + "/formal", "env", "lean", path], stdout=out, stderr=subprocess.STDOUT)
    peak, killed = 0.0, ""
    while p.poll() is None:
        time.sleep(0.5)
        try:
            # the lean child of lake env: sum the RSS of the process tree rooted at p
            ps = subprocess.run(["ps", "-A", "-o", "pid=,ppid=,rss="], capture_output=True, text=True).stdout
            kids, rss = {}, {}
            for row in ps.split("\n"):
                f = row.split()
                if len(f) == 3:
                    kids.setdefault(int(f[1]), []).append(int(f[0]))
                    rss[int(f[0])] = int(f[2])
            tot, stack = 0, [p.pid]
            while stack:
                q = stack.pop()
                tot += rss.get(q, 0)
                stack.extend(kids.get(q, []))
            gib = tot / 1048576
            peak = max(peak, gib)
            if gib > cap:
                killed = f"KILLED rss {gib:.2f} GiB"
            elif time.time() - start > limit:
                killed = "KILLED time"
            if killed:
                for q in [p.pid] + kids.get(p.pid, []):
                    try:
                        os.kill(q, 15)
                    except OSError:
                        pass
                p.wait()
                break
        except Exception as ex:  # noqa: BLE001
            print("watch error", ex, flush=True)
    out.close()
    print(f"cut {cut}: rc {p.returncode} {killed} peak {peak:.2f} GiB {time.time() - start:.0f} s", flush=True)
    print(open(path + ".out").read()[-3000:], flush=True)
