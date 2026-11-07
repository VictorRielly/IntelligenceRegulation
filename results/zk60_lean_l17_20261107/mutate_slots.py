#!/usr/bin/env python3
"""D63 Lean lane L17 (2026-11-07): the negative control of CheckR13Slots (a copy of
results/zk60_lean_l11_20261107/mutate_corpus.py: the same seven changes on the R13 slots corpus).
Originally: the negative control of L11Check. Seven single changes to the corpus, each made so that
exactly ONE check fails:
  1. slot 3's first round value (the sumcheck refuses: the verify arm fails);
  2. slot 20's published scalar (`SC_ZS`, hosted by no slot: its verify arm fails);
  3. one terminal value of slot 5 (`SC_QMM`; Lean's own values differ from the corpus's);
  4. one public constant of slot 14's IR (`SC_DZC`; poly(vals) differs from the closure's value);
  5. slot 4's last draw (`SC_RS`'s lam: the draw replay fails, and lam is no checked IR provenance);
  6. LogUp's beta (the head check fails);
  7. slot 0's declared terminal count.

usage: python3 -I mutate_corpus.py <corpus.txt> <out.txt>
"""
import sys

src, out = sys.argv[1], sys.argv[2]
lines = open(src).read().split("\n")
slot = None
done = set()


def bump_first_number(field):
    parts = field.split(",")
    parts[0] = str(int(parts[0]) + 1)
    return ",".join(parts)


res = []
for ln in lines:
    w = ln.split(" ")
    if w[0] == "SLOT":
        slot = int(w[1])
    if w[0] == "ROUND" and slot == 3 and 1 not in done:
        w[2] = bump_first_number(w[2])
        done.add(1)
    elif w[0] == "SCALAR" and slot == 20 and 2 not in done:
        w[1] = bump_first_number(w[1])
        done.add(2)
    elif w[0] == "VALS" and slot == 5 and 3 not in done:
        w[1] = bump_first_number(w[1])
        done.add(3)
    elif w[0] == "NODE" and slot == 14 and 4 not in done and w[2] == "S" and ":kbase:" in w[3]:
        subs = w[3].split(";")
        for i, sub in enumerate(subs):
            coef, rest = sub.split("@", 1)
            c0, c1, prov = coef.split(":", 2)
            if prov.startswith("kbase") and int(c0) > 0:
                subs[i] = f"{int(c0) + 1}:{c1}:{prov}@{rest}"
                break
        else:
            res.append(" ".join(w))
            continue
        w[3] = ";".join(subs)
        done.add(4)
    elif w[0] == "DRAWS" and slot == 4 and 5 not in done:
        parts = w[1].split(",")
        parts[-2] = str(int(parts[-2]) + 1)
        w[1] = ",".join(parts)
        done.add(5)
    elif w[0] == "LOGUP" and 6 not in done:
        w[1] = bump_first_number(w[1])
        done.add(6)
    elif w[0] == "TERMSDECL" and 7 not in done:
        w[1] = bump_first_number(w[1])
        done.add(7)
    res.append(" ".join(w))
assert done == {1, 2, 3, 4, 5, 6, 7}, done
open(out, "w").write("\n".join(res))
print("mutations:", sorted(done))
