#!/usr/bin/env python3
"""D63 Lean lane L17 (2026-11-07; a copy of results/zk60_lean_l10_20261107/negctl.py): the negative control of
CheckR13Open on the reduced R13 opening corpus. Originally: the negative control of L10's checker. Six single changes to the reduced corpus,
each of which the checker must report (eight failed checks: an M record the crate accepts is compared twice, by the
field and by L9's maskTranscript):
  1. the root of order 2^9 changed;
  2. m-honest: the crate's transcript after M, counter + 1 (2 failures);
  3. m-q0: the crate's verdict turned into an acceptance (2 failures: no transcript after);
  4. a-vec0: the crate's refusal message changed by one character;
  5. chk-a: the crate's verdict on check_opening turned into a refusal;
  6. chk-h-groups: the schedule's declared group count + 1 (the code's message names the old count).

usage: negctl.py <reduced corpus> <out>   (prints the expected failure count)
"""
import sys

src, dst = sys.argv[1], sys.argv[2]
lines = open(src).read().split("\n")
done = set()
cur = None
for i, l in enumerate(lines):
    w = l.split(" ")
    if w[0] in ("L10M", "L10PCS", "L10CHK"):
        cur = w[1]
    if w[0] == "L10ROOT" and w[1] == "9" and 1 not in done:
        lines[i] = f"L10ROOT 9 {int(w[2]) + 1}"
        done.add(1)
    elif w[0] == "L10END" and cur == "m-honest" and 2 not in done:
        lines[i] = " ".join(w[:2] + [str(int(w[2]) + 1)] + w[3:])
        done.add(2)
    elif w[0] == "L10M" and w[1] == "m-q0" and 3 not in done:
        lines[i] = " ".join(w[:-1] + ["1"])
        done.add(3)
    elif w[0] == "L10ERR" and cur == "a-vec0" and 4 not in done:
        lines[i] = l + "x"
        done.add(4)
    elif w[0] == "L10CHK" and w[1] == "chk-a" and 5 not in done:
        lines[i] = " ".join(w[:-1] + ["0"])
        done.add(5)
    elif w[0] == "L10CHK" and w[1] == "chk-h-groups" and 6 not in done:
        w[7] = str(int(w[7]) + 1)
        lines[i] = " ".join(w)
        done.add(6)
open(dst, "w").write("\n".join(lines))
print(f"negctl: {len(done)} of 6 changes written; expected failed checks {len(done) + (2 in done) + (3 in done)}")
