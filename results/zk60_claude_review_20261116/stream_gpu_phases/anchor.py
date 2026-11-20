#!/usr/bin/env python3
"""How well can the log's stream clock be tied to the trace's host clock?   python3 -I anchor.py
Two independent anchors per request:
 (W) first witness buffer begin  minus log 'sealing turn'
 (P) first rows=38 commit begin  minus log 'prover start'   (the call begins with preflight 1-2 ms, then the serial commit phase of 31 rows=38 commits)
If the clock tie is right, P - W is a small constant (the host prelude of the first witness product, 0 to 20 ms) for every request of a pass.
The prove-call window used everywhere is S = first rows=38 commit begin - preflight, E = S + 'prove call' from the log.
Check on E: the last prover buffer (not counting the two rows=37 commits that the sealing side issues at the end of its pass, which fall in the previous
request's window) should end a few ms before E (the host tail of the join)."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *

for arm in ARMS:
    A = windows(load_arm(arm))
    print("\n####", arm)
    pw, ee, fs = [], [], []
    for i, rq in enumerate(A["reqs"]):
        lg = rq["log"]
        w = min(r["b"] for r in rq["wprod"]) - lg["turn"]
        p = min(r["b"] for r in rq["prover"] if r["tag"] == "commit" and r["kv"]["rows"] == "38") - lg["ps"]
        main = [r for r in rq["prover"] if not (r["tag"] == "commit" and r["kv"]["rows"] == "37")]
        pw.append(p - w)
        ee.append(rq["E"] - max(r["d"] for r in main))
        fs.append(min(r["b"] for r in main) - rq["S"])
    print("  P - W (s): median %.4f, range %.4f .. %.4f (n=%d requests incl. cold)" % (med(pw), min(pw), max(pw), len(pw)))
    print("  E - last prover buffer done (s): median %.4f, range %.4f .. %.4f" % (med(ee), min(ee), max(ee)))
    print("  first prover buffer begin - S (s): median %.4f, range %.4f .. %.4f" % (med(fs), min(fs), max(fs)))
    # per pass spread of t0 across the requests of a pass
    R = A["R"]
    sp = []
    for p in range(NPASS):
        t0s = [A["reqs"][1 + p * R + k]["t0"] for k in range(R)]
        sp.append(max(t0s) - min(t0s))
    print("  spread of the stream-clock origin t0 across the requests of one pass (s): max over passes %.4f" % max(sp))
