#!/usr/bin/env python3
"""D63 Lean lane L18 (2026-11-07): the negative control of ProtocolClassifyCheck. Five single changes to the framing
corpus, each a lie the checker must catch:
  1. BINDING: one hex digit of the binding                       -> BINDING fails (1)
  2. SEG 1's end tag: one hex digit                              -> TAG-END seg 1, CONTINUITY 1 -> 2 fail (2)
  3. FRAME 0: the transcript counter after the framing, plus one -> FRAME block 0 fails (1)
  4. CARRY 1: the pending claim count, plus one                  -> CARRY segment 1 pending fails (1)
  5. SEG 0's kind IN-C -> IN-X                                   -> SHAPE kinds fails (1)
Expected: exactly 6 failed checks.

usage: python3 -I mutate_corpus.py <corpus> <out>
"""
import sys


def flip(h):
    return ("1" if h[0] != "1" else "2") + h[1:]


src, out = sys.argv[1], sys.argv[2]
res = []
for line in open(src).read().splitlines():
    t = line.split(" ")
    if t[0] == "BINDING":
        t[1] = flip(t[1])
    elif t[0] == "SEG" and t[1] == "1":
        t[7] = flip(t[7])
    elif t[0] == "FRAME" and t[1] == "0":
        t[7] = str(int(t[7]) + 1)
    elif t[0] == "CARRY" and t[1] == "1":
        t = [("pending=" + str(int(x.split("=")[1]) + 1)) if x.startswith("pending=") else x for x in t]
    elif t[0] == "SEG" and t[1] == "0":
        t[2] = "IN-X"
    res.append(" ".join(t))
open(out, "w").write("\n".join(res) + "\n")
print("mutated 5 records")
