#!/usr/bin/env python3
"""Replication check on two unsampled Batch 8 serve1 traces (a1_default, a2_default; no log kept, so the prove-call window is taken from the trace:
S = first rows=38 commit begin - 0.002, E = last non-rows=37 prover buffer done + 0.007, the offsets seen in anchor.py).
python3 -I batch8_check.py"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import *
from labels import group_of, eq_attribution

for nm in ("a1_default", "a2_default"):
    rows = load_trace(T8 / (nm + ".trace.tsv.gz"))
    nonw = sorted([r for r in rows if r["tag"] != "wprod"], key=lambda r: r["b"])
    c38 = [i for i, r in enumerate(nonw) if r["tag"] == "commit" and r["kv"]["rows"] == "38"]
    nreq = len(c38) // 31
    print("\n%s: %d rows, %d non-witness, %d prove calls (31 rows=38 commits each: %d)" % (nm, len(rows), len(nonw), nreq, len(c38)))
    cuts = [0] + [c38[31 * k] for k in range(1, nreq)] + [len(nonw)]
    res = []
    for k in range(nreq):
        ch = [r for r in nonw[cuts[k]:cuts[k + 1]] if valid(r) and not (r["tag"] == "commit" and r["kv"]["rows"] == "37")]
        S = min(r["b"] for r in ch if r["tag"] == "commit" and r["kv"]["rows"] == "38") - 0.002
        E = max(r["d"] for r in ch) + 0.007
        P = ch
        U = union_len(ivs(P), S, E)
        eq = eq_attribution(P, S, E)
        res.append((E - S, U, sum(span(r) for r in P), eq))
    for k, (pc, U, ss, eq) in enumerate(res):
        print("   call %d: P %.3f  prover busy %.3f (%.1f %%)  idle %.3f  sum of spans %.3f (x%.2f of union)  H commit eq %.0f ms (%.1f %%)  A commit eq %.0f ms (%.1f %%)" % (
            k, pc, U, 100 * U / pc, pc - U, ss, ss / U, 1000 * eq.get("commit H (2606 rows)", 0), 100 * eq.get("commit H (2606 rows)", 0) / U,
            1000 * eq.get("commit A (2504 rows)", 0), 100 * eq.get("commit A (2504 rows)", 0) / U))
    print("   medians (calls 1..%d, first excluded as cold): P %.3f  busy %.3f  idle %.3f" % (nreq - 1, med([x[0] for x in res[1:]]), med([x[1] for x in res[1:]]), med([x[0] - x[1] for x in res[1:]])))
