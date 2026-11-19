#!/usr/bin/env python3
"""D63 lane L63: compare two theorems' binder lists and conclusions, text for text (whitespace normalized).
usage: l63_cmp_binders.py <file A> <theorem A> <file B> <theorem B>
Prints each binder of A missing in B, each binder of B missing in A, whether the order of the common ones and the
conclusions agree. Read-only."""
import re
import sys


def stmt(path, name):
    t = open(path).read()
    m = re.search(r"^(?:private )?theorem " + re.escape(name) + r"\s", t, re.M)
    assert m, name
    i = m.end()
    d, j = 0, i
    binders, cur = [], None
    while True:
        c = t[j]
        if d == 0 and c in "({[⦃":
            cur = j
        if c in "({[⦃":
            d += 1
        elif c in ")}]⦄":
            d -= 1
            if d == 0:
                binders.append(t[cur:j + 1])
        elif d == 0 and c == ":" and t[j + 1] in " \n":
            k = t.find(":= by", j)
            concl = t[j + 1:k]
            break
        j += 1
    norm = lambda s: " ".join(s.split())
    return [norm(b) for b in binders], norm(concl)


def name_of(b):
    m = re.match(r"[({\[⦃]\s*([^:]*?)\s*:", b)
    return m.group(1) if m else b[:30]


ba, ca = stmt(sys.argv[1], sys.argv[2])
bb, cb = stmt(sys.argv[3], sys.argv[4])
print("binders: A %d, B %d" % (len(ba), len(bb)))
onlyA = [b for b in ba if b not in bb]
onlyB = [b for b in bb if b not in ba]
print("only in A:", [name_of(b) for b in onlyA] or "none")
print("only in B:", [name_of(b) for b in onlyB] or "none")
common_a = [b for b in ba if b in bb]
common_b = [b for b in bb if b in ba]
print("common binders in the same order:", common_a == common_b)
print("conclusions identical:", ca == cb)
