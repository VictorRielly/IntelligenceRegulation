#!/usr/bin/env python3
"""D63 step L6 (2026-11-06): the checker's negative control. Writes a copy of the corpus with EIGHT single changes, one
record each of: an interpolate_eval result, an eq_table_msb entry, a CFS sum-weight vector, a CFS round message, a
masked terminal, an extension round, an accepted sumcheck's final transcript state, and a refused sumcheck's error
message; `L6Check.lean` must report exactly 8 failed checks on it.

usage: python3 -I mutate_corpus.py <corpus.txt> <out.txt>
"""
import sys

src, dst = sys.argv[1], sys.argv[2]
done = set()


def flip(h):
    return h[:-1] + ("0" if h[-1] != "0" else "1")


def bump_first(csv):
    v = csv.split(",")
    v[0] = str(int(v[0]) + 1)
    return ",".join(v)


out = []
for line in open(src).read().split("\n"):
    w = line.split(" ")
    k = w[0]
    if k == "IE" and "IE" not in done:
        w[-1] = bump_first(w[-1]); done.add("IE")
    elif k == "EQT" and len(w[1]) > 1 and "EQT" not in done:
        w[3] = bump_first(w[3]); done.add("EQT")
    elif k == "CFSW" and "CFSW" not in done:
        w[3] = bump_first(w[3]); done.add("CFSW")
    elif k == "CFSR" and "CFSR" not in done:
        w[3] = bump_first(w[3]); done.add("CFSR")
    elif k == "MT" and "MT" not in done:
        w[-1] = bump_first(w[-1]); done.add("MT")
    elif k == "EXR" and "EXR" not in done:
        w[-1] = bump_first(w[-1]); done.add("EXR")
    elif k == "SCEND" and w[1] == "ok" and "SCOK" not in done:
        w[-1] = flip(w[-1]); done.add("SCOK")
    elif k == "SCEND" and w[1] == "err" and "SCERR" not in done:
        w[2] = flip(w[2]); done.add("SCERR")
    out.append(" ".join(w))
assert len(done) == 8, done
open(dst, "w").write("\n".join(out))
print("mutated:", sorted(done))
