#!/usr/bin/env python3
"""D63 lane L31 (2026-11-09): the negative control of BlockInstCheck. Writes copies of the three corpora with EIGHT
single changes, each of which exactly one check of the checker must catch:
  1. L9's corpus, SHAPE: a_rows + 1                                    -> ROWS (W16R2 rung)
  2. L9's corpus, PCS A: the first group's member count + 1            -> CLAIMS-A
  3. L9's corpus, PCS H: the second and third groups swapped           -> H-SCHEDULE
  4. L9's corpus, END: the final squeeze counter + 1                    -> COUNTER-END
  5. L9's corpus, SLOTSHAPE 14: the terminal count + 1                 -> TERMS
  6. L17's block corpus, SHAPE: mask_specs + 1                         -> MASK-SPECS (R13 rung)
  7. L17's block corpus, the last SLOT record: its counter + 1         -> COUNTER-M
  8. L17's shape corpus, the Shieldstral R13 profile: Dom::S helpers+1 -> SHAPE-H-SCHEDULE
Exactly 8 checks must fail.

usage: python3 -I l31_mutate.py <L9 corpus> <L17 block corpus> <L17 shape corpus> <out dir>
"""
import os
import sys

c16, c13, csh, out = sys.argv[1:5]
os.makedirs(out, exist_ok=True)
done = set()


def setkv(w, key, f):
    k = w.index(key)
    w[k + 1] = f(w[k + 1])


res = []
for line in open(c16).read().split("\n"):
    w = line.split(" ")
    if w[0] == "SHAPE":
        setkv(w, "a_rows", lambda v: str(int(v) + 1))
        done.add(1)
    elif w[0] == "PCS" and w[1] == "A":
        def f(v):
            xs = v.split(",")
            xs[0] = str(int(xs[0]) + 1)
            return ",".join(xs)
        setkv(w, "counts", f)
        done.add(2)
    elif w[0] == "PCS" and w[1] == "H":
        def f(v):
            xs = v.split(",")
            assert xs[1] != xs[2]
            xs[1], xs[2] = xs[2], xs[1]
            return ",".join(xs)
        setkv(w, "counts", f)
        done.add(3)
    elif w[0] == "END":
        w[2] = str(int(w[2]) + 1)
        done.add(4)
    elif w[0] == "SLOTSHAPE" and w[1] == "14":
        w[5] = str(int(w[5]) + 1)
        done.add(5)
    res.append(" ".join(w))
open(f"{out}/l31_mut_corpus16.txt", "w").write("\n".join(res))

res = []
lines = open(c13).read().split("\n")
last_slot = max(i for i, l in enumerate(lines) if l.startswith("SLOT "))
for i, line in enumerate(lines):
    w = line.split(" ")
    if w[0] == "SHAPE":
        setkv(w, "mask_specs", lambda v: str(int(v) + 1))
        done.add(6)
    elif i == last_slot:
        w[-1] = str(int(w[-1]) + 1)
        done.add(7)
    res.append(" ".join(w))
open(f"{out}/l31_mut_corpus13.txt", "w").write("\n".join(res))

res = []
inprof = False
for line in open(csh).read().split("\n"):
    w = line.split(" ")
    if w[0] == "PROFILE":
        inprof = w[1] == "hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-blocks/2"
    elif w[0] == "SHAPE" and inprof:
        for j, x in enumerate(w):
            if x.startswith("helpers="):
                hs = x.split("=")[1].split(",")
                hs[6] = str(int(hs[6]) + 1)
                w[j] = "helpers=" + ",".join(hs)
                done.add(8)
    res.append(" ".join(w))
open(f"{out}/l31_mut_shape.txt", "w").write("\n".join(res))
assert done == set(range(1, 9)), done
print("8 changes written")
