#!/usr/bin/env python3
"""D63 step L13 (2026-11-07): the negative control of SlotW16BuildCheck. Seven single changes, each made so that
exactly ONE check fails:
  1. the 8B shape's first `A` plane name (the a-planes check of that shape);
  2. the Shieldstral shape's first `Dom::D` lookup constant (its D lookups);
  3. the rung's `Dom::F` zero-rule planes (one plane dropped);
  4. one constant of slot 14's clause node `c0` (`SC_DZC`'s nodes);
  5. slot 17's `nu[0]` term coefficient (`SC_SZC`'s terms);
  6. one table label of slot 19 (`SC_TAB`'s tables);
  7. slot 15's first draw (`SC_QZC`'s `mu[0]`: its batch node).

usage: python3 -I mutate_l13.py <layout.txt> <corpus.txt> <out_layout.txt> <out_corpus.txt>
"""
import sys

lay, cor, olay, ocor = sys.argv[1:5]
done = set()
out = []
shape = None
for ln in open(lay).read().split("\n"):
    w = ln.split(" ")
    if w[0] == "L13":
        shape = w[1]
    if w[0] == "APLANES" and shape == "W16R2_8B_T128_H24" and 1 not in done:
        parts = w[1].split(",")
        parts[0] = parts[0] + "X"
        w[1] = ",".join(parts)
        done.add(1)
    elif w[0] == "LK" and w[1] == "D" and shape == "W16R2_SHIELD_T128_H24" and 2 not in done:
        parts = w[3].split(";")
        c, rest = parts[0].split(":", 1)
        parts[0] = str(int(c) + 1) + ":" + rest
        w[3] = ";".join(parts)
        done.add(2)
    elif w[0] == "ZERO" and w[1] == "F" and shape == "W16R2_RUNG_H24" and 3 not in done:
        w[2] = ",".join(w[2].split(",")[1:])
        done.add(3)
    out.append(" ".join(w))
open(olay, "w").write("\n".join(out))
out = []
slot = None
for ln in open(cor).read().split("\n"):
    w = ln.split(" ")
    if w[0] == "SLOT":
        slot = int(w[1])
    if w[0] == "NODE" and slot == 14 and w[1] == "4" and 4 not in done:
        subs = w[3].split(";")
        coef, rest = subs[0].split("@", 1)
        c0, c1, prov = coef.split(":", 2)
        subs[0] = f"{int(c0) + 1}:{c1}:{prov}@{rest}"
        w[3] = ";".join(subs)
        done.add(4)
    elif w[0] == "TERM" and slot == 17 and "chal:nu[0]" in w[1] and 5 not in done:
        c0, rest = w[1].split(":", 1)
        w[1] = f"{int(c0) + 1}:{rest}"
        done.add(5)
    elif w[0] == "IRTAB" and slot == 19 and w[1] == "3" and 6 not in done:
        w[3] = w[3] + "_X"
        done.add(6)
    elif w[0] == "DRAWS" and slot == 15 and 7 not in done:
        parts = w[1].split(",")
        parts[0] = str(int(parts[0]) + 1)
        w[1] = ",".join(parts)
        done.add(7)
    out.append(" ".join(w))
open(ocor, "w").write("\n".join(out))
print(f"{len(done)} changes: {sorted(done)}")
