#!/usr/bin/env python3
"""Summarise a macOS `sample` call graph: per thread, a pruned tree (nodes >= min %
of the thread's samples), or with --flat, self-time per leaf-ish symbol summed over
the chosen threads. Usage:
  sample_tree.py FILE tree THREAD_SUBSTR MIN_PCT MAX_DEPTH [ROOT_SUBSTR]
  sample_tree.py FILE flat THREAD_SUBSTR|all TOP"""
import re, sys
from collections import defaultdict

path, mode = sys.argv[1], sys.argv[2]
lines = open(path, errors="replace").read().split("\n")
start = next(i for i, l in enumerate(lines) if l.startswith("Call graph:"))
end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("Total number in stack")), len(lines))
pat = re.compile(r"^(\s*[+!:| ]*)(\d+) (.*)$")

def short(sym):
    sym = re.sub(r"\s+\(in [^)]*\).*$", "", sym)
    sym = re.sub(r"::h[0-9a-f]{16}$", "", sym)
    return sym[:150]

# parse into threads: list of (depth, count, name)
threads = []
for l in lines[start + 1:end]:
    m = pat.match(l)
    if not m:
        continue
    depth = len(m.group(1))
    cnt = int(m.group(2))
    name = m.group(3)
    if depth == 4:
        threads.append((name, []))
    elif threads:
        threads[-1][1].append((depth, cnt, short(name)))

def tree(nodes):
    # nodes: (depth, cnt, name) in preorder; return list of (depth, cnt, name, self)
    out = []
    for i, (d, c, n) in enumerate(nodes):
        kids = 0
        for j in range(i + 1, len(nodes)):
            if nodes[j][0] <= d:
                break
            if nodes[j][0] == d + 2:
                kids += nodes[j][1]
        out.append((d, c, n, c - kids))
    return out

if mode == "tree":
    sub, minpct, maxd = sys.argv[3], float(sys.argv[4]), int(sys.argv[5])
    root = sys.argv[6] if len(sys.argv) > 6 else None
    for tname, nodes in threads:
        if sub not in tname:
            continue
        total = int(tname.split()[0]) if tname.split()[0].isdigit() else max((c for _, c, _ in nodes), default=1)
        total = max(c for d, c, _ in nodes if d == min(x[0] for x in nodes))
        print("==", tname[:120], "samples", total)
        rd = None
        for d, c, n, s in tree(nodes):
            if root:
                if rd is None:
                    if root in n:
                        rd = d
                    else:
                        continue
                elif d <= rd:
                    rd = None
                    if root in n:
                        rd = d
                    else:
                        continue
            base = rd if rd is not None else 0
            if c * 100.0 / total >= minpct and (d - base) // 2 <= maxd:
                print(f"{'  ' * ((d - base) // 2)}{c:5d} {100.0 * c / total:5.1f}% self {s:4d}  {n}")
elif mode == "flat":
    sub, top = sys.argv[3], int(sys.argv[4])
    agg = defaultdict(int)
    tot = 0
    for tname, nodes in threads:
        if sub != "all" and sub not in tname:
            continue
        for d, c, n, s in tree(nodes):
            if s > 0:
                agg[n] += s
                tot += s
    for n, s in sorted(agg.items(), key=lambda x: -x[1])[:top]:
        print(f"{s:6d} {100.0 * s / max(tot, 1):5.1f}%  {n}")

if mode == "callers":
    sym, up = sys.argv[3], int(sys.argv[4])
    agg = defaultdict(int)
    skip = ("rayon", "crossbeam", "core::ops::function", "std::", "_pthread", "objc::", "start_wqthread", "core::iter")
    for tname, nodes in threads:
        stack = []
        for d, c, n in nodes:
            while stack and stack[-1][0] >= d:
                stack.pop()
            if n.startswith(sym):
                chain = [x[1] for x in stack if not x[1].startswith(skip)][-up:]
                agg[" <- ".join(reversed(chain))] += c
            stack.append((d, n))
    for k, v in sorted(agg.items(), key=lambda x: -x[1])[:15]:
        print(f"{v:6d}  {k[:300]}")
