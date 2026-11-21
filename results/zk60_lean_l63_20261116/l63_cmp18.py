#!/usr/bin/env python3
"""D63 lane L63 leg 18: compare the elaborated types dumped by probeTY18b (before ruling L63-10) and probeTY18a
(after): every top byte for byte, and the 15 declarations / 3 contracts by hash, printing a unified diff of the
pretty-printed text where they differ. usage: l63_cmp18.py <OUT dir>"""
import difflib
import re
import sys

OUT = sys.argv[1]


def blocks(path):
    out, cur, buf = {}, None, []
    for line in open(path, encoding="utf-8"):
        m = re.match(r"^### (\S+) (.*)$", line)
        if m:
            if cur:
                out[cur] = (hdr, "".join(buf))
            cur, hdr, buf = m.group(1), m.group(2), []
        else:
            buf.append(line)
    if cur:
        out[cur] = (hdr, "".join(buf))
    return out


tb, ta = blocks(f"{OUT}/tops_types_before18.txt"), blocks(f"{OUT}/tops_types_after18.txt")
same = 0
for n in tb:
    ok = n in ta and tb[n][1] == ta[n][1]
    same += ok
    print(f"top {n}: {'byte-identical' if ok else 'CHANGED'} ({tb[n][0]})")
print(f"tops byte-identical: {same} of {len(tb)}")
db, da = blocks(f"{OUT}/decls15_before18.txt"), blocks(f"{OUT}/decls15_after18.txt")
for n in db:
    hb, ha = db[n][0], da.get(n, ("MISSING", ""))[0]
    print(f"decl {n}: before [{hb}] after [{ha}] {'same' if hb == ha else 'differs'}")
    if db[n][1] != da.get(n, ("", ""))[1]:
        for d in difflib.unified_diff(db[n][1].splitlines(), da[n][1].splitlines(), "before", "after", n=1,
                                      lineterm=""):
            print("    " + d)
