#!/usr/bin/env python3
"""[gate round 24] May a gate job declaring `need` GiB start now under the lean-memory rule (D44 / D46
addenda: at most one job declaring >= 3 GiB box-wide, with only light jobs of <= 1 GiB beside it)?

    python3 lean_check.py <need_gib> <class> [own-label-prefix]

Exit 0 when: no hold file; and EITHER this job is light with need <= 1 GiB, OR no OTHER live or waiting
guarded job (guard status plus every `zk60_resource_guard.py run` process, which also shows guards still
waiting for admission) declares >= 3 GiB -- and, when this job itself declares >= 3 GiB, no other
non-light job or light job over 1 GiB is live or waiting.  Prints what it saw as one JSON line.
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
                argv = [a.decode(errors="replace") for a in fh.read().split(b"\0") if a]
        except OSError:
            continue
        if len(argv) >= 3 and argv[1].endswith("zk60_resource_guard.py") and argv[2] == "run":
            def opt(k, default=None):
                return argv[argv.index(k) + 1] if k in argv else default
            out.append({"pid": int(p), "label": opt("--label", "?"), "class": opt("--class", "?"),
                        "need_gib": float(opt("--need-gib", "11"))})
    return out


def main(need, cls, own=""):
    need = float(need)
    s = json.loads(subprocess.run(["python3", G, "status", "--json"], capture_output=True, text=True).stdout)
    live = [{"label": j.get("label"), "class": j.get("class"), "need_gib": float(j.get("need_gib") or 0)}
            for j in s["live_guarded_jobs"]]
    procs = guard_procs()
    seen = {}
    for x in live + procs:
        seen.setdefault(x["label"], x)
    others = [x for x in seen.values() if not (own and str(x["label"]).startswith(own))]
    holds = [h for h in HOLDS if os.path.exists(h)]
    big = [x for x in others if x["need_gib"] >= 3.0]
    beside_big = [x for x in others if not (x["class"] == "light" and x["need_gib"] <= 1.0)]
    small_light = cls == "light" and need <= 1.0
    ok = not holds and (small_light or (not big and (need < 3.0 or not beside_big)))
    print(json.dumps({"need_gib": need, "class": cls, "others": others, "holds": holds, "big_others": big,
                      "mem_available_gib": s.get("mem_available_gib"), "committed_gib": s.get("committed_gib"),
                      "ok": ok}))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(*sys.argv[1:4]))
