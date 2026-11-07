#!/usr/bin/env python3
"""D63 Lean lane L17 (2026-11-07; L9's mutate_corpus.py with two segment changes): the negative control of
CheckR13Block. Writes a copy of corpus.txt with SIX single
changes, each of which one check of the checker must catch:
  1. one of slot 5's define draws (c0 + 1)            -> SLOT-DRAWS
  2. one of slot 9's round challenges (c1 + 1)        -> SLOT-RHO
  3. the transcript state after slot 12 (a byte)      -> SLOT-STATE
  4. one of A's column indices (+ 1)                   -> PCS
  5. M's opening digest in FIELDS (a hex digit)        -> FIELDS
  6. the round-sum tamper's verdict (the slot number)  -> TAMPER
and on the D12a segment corpus:
  7. the input endpoint opening's digest in FIELDS (a hex digit) -> SEG-FIELDS
  8. the input-column-index tamper's verdict (its message)       -> SEG-TAMPER
Exactly 8 checks must fail.

usage: python3 -I mutate_block.py <block_corpus.txt> <out.txt> <segment_corpus.txt> <out2.txt>
"""
import sys

src, out = sys.argv[1], sys.argv[2]
lines = open(src).read().split("\n")


def bump_word(field, idx, delta=1):
    ws = field.split(",")
    ws[idx] = str((int(ws[idx]) + delta) % (2 ** 64 - 2 ** 32 + 1))
    return ",".join(ws)


def flip_hex(h, i=0):
    c = h[i]
    return h[:i] + ("1" if c != "1" else "2") + h[i + 1:]


done = set()
res = []
for line in lines:
    w = line.split(" ")
    if w[0] == "SLOT" and w[1] == "5" and 1 not in done:
        k = w.index("draws")
        w[k + 1] = bump_word(w[k + 1], 0)
        done.add(1)
    elif w[0] == "SLOT" and w[1] == "9" and 2 not in done:
        k = w.index("rho")
        w[k + 1] = bump_word(w[k + 1], 1)
        done.add(2)
    elif w[0] == "SLOT" and w[1] == "12" and 3 not in done:
        w[-2] = flip_hex(w[-2], 5)
        done.add(3)
    elif w[0] == "PCS" and w[1] == "A" and 4 not in done:
        k = w.index("idx")
        ws = w[k + 1].split(",")
        ws[0] = str(int(ws[0]) + 1)
        w[k + 1] = ",".join(ws)
        done.add(4)
    elif w[0] == "FIELDS" and 5 not in done:
        k = w.index("mask")
        w[k + 2] = flip_hex(w[k + 2], 0)
        done.add(5)
    elif w[0] == "TAMPER" and w[1] == "round-sum" and 6 not in done:
        line2 = " ".join(w).replace("slot 3 [", "slot 4 [")
        w = line2.split(" ")
        done.add(6)
    res.append(" ".join(w))
assert done == {1, 2, 3, 4, 5, 6}, done
open(out, "w").write("\n".join(res))
slines = open(sys.argv[3]).read().split("\n")
sres = []
for line in slines:
    w = line.split(" ")
    if w[0] == "FIELDS" and 7 not in done:
        k = w.index("in")
        w[k + 2] = flip_hex(w[k + 2], 0)
        done.add(7)
    elif w[0] == "TAMPER" and w[1] == "input-column-index" and 8 not in done:
        w[-1] = w[-1] + "x"
        done.add(8)
    sres.append(" ".join(w))
assert done == {1, 2, 3, 4, 5, 6, 7, 8}, done
open(sys.argv[4], "w").write("\n".join(sres))
print("8 changes written")
