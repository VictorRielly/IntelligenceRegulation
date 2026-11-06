#!/usr/bin/env python3
"""D63 step L5 (2026-11-06): the checker's negative control. Writes a copy of the corpus with SIX single changes (one
field result, one keyed BLAKE3 digest, one transcript state, one column index, one PCS final state, and one honest
Merkle opening's verdict flipped to 'refused'); `L5Check.lean` must report exactly 6 failed checks on it.

usage: python3 -I mutate_corpus.py <corpus.txt> <out.txt>
"""
import sys

src, dst = sys.argv[1], sys.argv[2]
done = set()


def flip(h):
    return h[:-1] + ("0" if h[-1] != "0" else "1")


out = []
for line in open(src).read().split("\n"):
    w = line.split(" ")
    if w[0] == "TS" and "TS" not in done:
        w[-1] = flip(w[-1]); done.add("TS")
    elif w[0] == "B3" and len(w) > 1 and w[1] == "keyed" and "B3" not in done:
        w[-1] = flip(w[-1]); done.add("B3")
    elif w[0] == "FP" and len(w) > 1 and w[1] == "mul" and "FP" not in done:
        w[-1] = str(int(w[-1]) + 1); done.add("FP")
    elif w[0] == "MK" and w[-1] == "1" and "MK" not in done:
        w[-1] = "0"; done.add("MK")
    elif w[0] == "PCSEND" and "PCSEND" not in done:
        w[-1] = flip(w[-1]); done.add("PCSEND")
    elif w[0] == "TCI" and len(w) > 3 and w[3] != "-" and "TCI" not in done:
        v = w[3].split(","); v[0] = str(int(v[0]) ^ 1); w[3] = ",".join(v); done.add("TCI")
    out.append(" ".join(w))
assert len(done) == 6, done
open(dst, "w").write("\n".join(out))
print("mutated:", sorted(done))
