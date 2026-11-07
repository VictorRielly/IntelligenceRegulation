#!/usr/bin/env python3
"""D63 Lean lane L15 (2026-11-07): the negative control of StageCheckOutC. Eight single changes to the corpus, each made
so that exactly ONE check fails:
  1. slot 0's first masked terminal (IO-in: Lean's terminal values differ, the verify arm fails);
  2. slot 5's first round value (DZC: the sumcheck's arithmetic fails);
  3. slot 0's recorded claimed sum (the claimed-sum check fails; Lean's sumcheck check uses its own claimed sum);
  4. slot 6's first batching draw `mu[0]` (TAB: the verify arm fails; `tau`, the eq point, is unchanged);
  5. the margin vector's first word (PD's public table: its verify arm fails);
  6. the verdict (LZC's `G` and `b + c`: its verify arm fails);
  7. slot 2's kind (TZC recorded as standalone: the schedule check fails);
  8. slot 4's eq table point (LZC: the eq-point check fails; Lean's values use the slot's own `tau`).

usage: python3 -I mutate_corpus.py <corpus.txt> <out.txt>
"""
import json
import sys

P = 18446744069414584321
src, out = sys.argv[1], sys.argv[2]
lines = open(src).read().split("\n")


def bump(pair):
    return [(pair[0] + 1) % P, pair[1]]


res = []
for ln in lines:
    if ln.startswith("SLOT "):
        rec = json.loads(ln[5:])
        s = rec["slot"]
        if s == 0:
            rec["terminals"][0] = bump(rec["terminals"][0])
            rec["claimed_sum"] = bump(rec["claimed_sum"])
        elif s == 2:
            rec["kind"] = "Standalone"
        elif s == 4:
            for t in rec["tables"]:
                if t["kind"] == "eq":
                    t["point"][0] = bump(t["point"][0])
                    break
        elif s == 5:
            rec["rounds"][0][0] = bump(rec["rounds"][0][0])
        elif s == 6:
            ltab = rec["main"]
            rec["definition_challenges"][ltab] = bump(rec["definition_challenges"][ltab])
        ln = "SLOT " + json.dumps(rec, separators=(",", ":"))
    elif ln.startswith("WDELTA "):
        ws = ln[7:].split(",")
        ws[0] = str(int(ws[0]) + 1)
        ln = "WDELTA " + ",".join(ws)
    elif ln.startswith("PROFILE "):
        ws = ln.split(" ")
        ws = [("verdict=" + str(1 - int(w.split("=")[1]))) if w.startswith("verdict=") else w for w in ws]
        ln = " ".join(ws)
    res.append(ln)
open(out, "w").write("\n".join(res))
print("eight mutations written to", out)
