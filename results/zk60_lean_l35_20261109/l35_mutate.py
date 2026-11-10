#!/usr/bin/env python3
"""D63 lane L35 (2026-11-09): the negative control of BlockDefineCheck. Writes copies of the L11 and L9 corpora with
TEN single changes, each of which one check of BlockDefineCheck must catch (so the run must report exactly 10 failed):
  1. slot 2: the first NODE line's first coefficient + 1        (ir-nodes, slot 2)
  2. slot 0: the first TERM line's coefficient + 1               (ir-terms, slot 0)
  3. slot 3: the first `priv` table becomes `pub`                (tables, slot 3)
  4. slot 4: the first `eq` table's start + 1                    (tables, slot 4)
  5. slot 21: the first `eq` table's first point word + 1        (tables, slot 21)
  6. the first nonempty HOSTED line's first coefficient + 1      (hosted)
  7. SITES a: the first row + 1                                  (sites-a)
  8. SITES h: the last row + 1                                   (sites-h)
  9. SITES hu: the first row - 1                                 (sites-hu)
 10. slot 0: the first `A[p]` plane label becomes `A[p+1]`       (planes, slot 0)
usage: l35_mutate.py <L11 corpus> <L9 corpus> <out dir outside the repository>
"""
import os
import sys

c11, c9, out = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(out, exist_ok=True)
L = open(c11).read().split("\n")
done = set()
slot = None
for i, l in enumerate(L):
    w = l.split(" ")
    if w[0] == "SLOT":
        slot = int(w[1])
        continue
    if w[0] == "NODE" and slot == 2 and 1 not in done and len(w) >= 4:
        # NODE i A k ts  or  NODE i S c@f;...
        if w[2] == "A":
            parts = w[3].split(":")
        else:
            parts = w[3].split(";")[0].split("@")[0].split(":")
        old = parts[0] + ":" + parts[1]
        new = str(int(parts[0]) + 1) + ":" + parts[1]
        L[i] = l.replace(old, new, 1)
        done.add(1)
    elif w[0] == "TERM" and slot == 0 and 2 not in done:
        parts = w[1].split(":")
        w[1] = str(int(parts[0]) + 1) + ":" + ":".join(parts[1:])
        L[i] = " ".join(w)
        done.add(2)
    elif w[0] == "TAB" and slot == 3 and 3 not in done and w[2] == "priv":
        w[2] = "pub"
        L[i] = " ".join(w)
        done.add(3)
    elif w[0] == "TAB" and slot == 4 and 4 not in done and w[2] == "eq":
        w[3] = str(int(w[3]) + 1)
        L[i] = " ".join(w)
        done.add(4)
    elif w[0] == "TAB" and slot == 21 and 5 not in done and w[2] == "eq":
        pt = w[4].split(",")
        pt[0] = str(int(pt[0]) + 1)
        w[4] = ",".join(pt)
        L[i] = " ".join(w)
        done.add(5)
    elif w[0] == "IRTAB" and slot == 0 and 10 not in done and w[3].startswith("A["):
        p, rest = w[3][2:].split("]", 1)
        w[3] = "A[" + str(int(p) + 1) + "]" + rest
        L[i] = " ".join(w)
        done.add(10)
    elif w[0] == "HOSTED" and w[1] != "-" and 6 not in done:
        e = w[1].split(";")
        f = e[0].split(":")
        f[1] = str(int(f[1]) + 1)
        e[0] = ":".join(f)
        w[1] = ";".join(e)
        L[i] = " ".join(w)
        done.add(6)
if done != {1, 2, 3, 4, 5, 6, 10}:
    raise SystemExit("not every L11 change was applied: %s" % sorted(done))
open(os.path.join(out, "l35_mut_corpus11.txt"), "w").write("\n".join(L))
M = open(c9).read().split("\n")
for i, l in enumerate(M):
    w = l.split(" ")
    if w[0] == "SITES":
        a = w[2].split(",")
        a[0] = str(int(a[0]) + 1)
        w[2] = ",".join(a)
        h = w[4].split(",")
        h[-1] = str(int(h[-1]) + 1)
        w[4] = ",".join(h)
        w[6] = str(int(w[6]) - 1)
        M[i] = " ".join(w)
        done.update({7, 8, 9})
if done != set(range(1, 11)):
    raise SystemExit("not every change was applied: %s" % sorted(done))
open(os.path.join(out, "l35_mut_corpus9.txt"), "w").write("\n".join(M))
print("wrote 10 changes to", out)
