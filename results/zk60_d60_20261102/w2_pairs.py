#!/usr/bin/env python3
"""D60: from s25's W-2 printout (`--nocapture`), list every equal-length pair of DIFFERENT kinds inside one hash
function for each REGISTERED D55 run profile's tables (the census passes only if each is a DECLARED pair), and
whether the same pair (same function, same two kinds, ignoring the constructor's profile name) already occurs
in the base run profile's own table. Also the constructor's nearest absorb, and every pair within one byte of
the D55 constructor. Usage: w2_pairs.py <printout log>"""
import re, sys
from collections import defaultdict

MARK = "hashline-zk-mr1/d55-commit-fork-join-run/registered-opt-in-d60/v1/"
text = open(sys.argv[1], errors="replace").read().split("\n")
tables = []
cur = None
for ln in text:
    m = re.match(r"^--- (\S+) \((.*?)\), (\d+) kinds, rule (\w+) ---", ln)
    if m:
        cur = {"name": m.group(1), "shape": m.group(2), "kinds": []}
        tables.append(cur)
        continue
    if cur is None:
        continue
    m = re.match(r"^\s+(\d+) B\s+(\S+)\s+(.*)$", ln)
    if m:
        cur["kinds"].append((int(m.group(1)), m.group(2), m.group(3)))
    else:
        cur = None


def norm(w, name):
    return w.replace(name, "<profile>")


def pairs(t):
    by = defaultdict(set)
    for n, f, w in t["kinds"]:
        by[(f, n)].add(norm(w, t["name"]))
    out = set()
    for (f, n), ws in by.items():
        ws = sorted(ws)
        for i in range(len(ws)):
            for j in range(i + 1, len(ws)):
                out.add((f, n, ws[i], ws[j]))
    return out


base_pairs = defaultdict(set)
for t in tables:
    if not t["name"].startswith(MARK) and not t["name"].startswith("d55-"):
        base_pairs[t["name"]] |= pairs(t)
seen = set()
for t in tables:
    if not t["name"].startswith(MARK):
        continue
    base = "hashline-zk-mr1/" + t["name"][len(MARK):]
    ctor = [n for n, f, w in t["kinds"] if w.startswith("the transcript constructor at")][0]
    ft = sorted((abs(n - ctor), n, w) for n, f, w in t["kinds"] if f == "F_T" and not w.startswith("the transcript constructor"))
    near = ft[0]
    key = (t["name"], len(t["kinds"]))
    if key in seen:
        continue
    seen.add(key)
    print(f"{t['name']} ({len(t['kinds'])} kinds): constructor {ctor} B, nearest F_T absorb {near[1]} B ({near[0]} bytes away: {near[2]})")
    for f, n, a, b in sorted(pairs(t)):
        inbase = (f, n, a, b) in base_pairs[base]
        print(f"    {f} {n} B: `{a}` = `{b}`  [{'also in the base table' if inbase else 'NOT in the base table'}]")
