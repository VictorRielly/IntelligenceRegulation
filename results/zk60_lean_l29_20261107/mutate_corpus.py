#!/usr/bin/env python3
"""D63 Lean lane L29 (2026-11-09): the negative control of StageVerifyExecCheck. Seven single changes to the stage
corpus, each a lie the checker must catch:
  1. INHEAD: the transcript counter after absorb_root("H"), plus one     -> HEAD   IN-C's transcript after H (1)
  2. INAFTER 2: the transcript counter after slot 2, plus one            -> SLOT   IN-C slot 2's transcript (1)
  3. the first INCLAIM: the claim's value (c0), plus one                 -> CLAIMS IN-C claim 0 (1)
  4. the first OUTFUN: the functional's value (c0), plus one             -> FUNS   OUT-C functional 0 (1)
  5. OUTHEAD: gamma (c0), plus one                                       -> HEAD   OUT-C's head challenges (1)
  6. OUTRESULT: the final transcript counter, plus one                   -> VERIFY OUT-C ... on the code's final
                                                                            transcript (1; needs the segments' bytes)
  7. INTAG: one hex digit of IN-C's end tag                              -> DECODE IN-C decoded: the end tag ...,
                                                                            VERIFY IN-C's end tag ... (2; needs the bytes)
Expected: exactly 8 failed checks with the segments' bytes, exactly 5 without.

usage: python3 -I mutate_corpus.py <corpus> <out>
"""
import sys


def flip(h):
    return ("1" if h[0] != "1" else "2") + h[1:]


def bump_f2(v):
    a, b = v.split(":")
    return f"{int(a) + 1}:{b}"


src, out = sys.argv[1], sys.argv[2]
res = []
seen = set()
n = 0
for line in open(src).read().splitlines():
    t = line.split(" ")
    k = t[0]
    if k == "INHEAD":
        t[2] = str(int(t[2]) + 1)
        n += 1
    elif k == "INAFTER" and t[1] == "2":
        t[3] = str(int(t[3]) + 1)
        n += 1
    elif k == "INCLAIM" and k not in seen:
        t[2] = bump_f2(t[2])
        n += 1
    elif k == "OUTFUN" and k not in seen:
        t[1] = bump_f2(t[1])
        n += 1
    elif k == "OUTHEAD":
        ch = t[3].split(",")
        ch[0] = bump_f2(ch[0])
        t[3] = ",".join(ch)
        n += 1
    elif k == "OUTRESULT":
        t[2] = str(int(t[2]) + 1)
        n += 1
    elif k == "INTAG":
        t[2] = flip(t[2])
        n += 1
    seen.add(k)
    res.append(" ".join(t))
open(out, "w").write("\n".join(res) + "\n")
print(f"mutated {n} records")
