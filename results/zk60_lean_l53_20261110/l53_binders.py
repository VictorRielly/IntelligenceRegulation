#!/usr/bin/env python3
"""D63 lane L53 (2026-11-10): list the binder names of the restated top theorem `stg_productionReadyL_epP_exec_lists`
(RunStgTop.lean), in order: every premise the theorem still takes. Read-only.

usage: python3 -I l53_binders.py <WT>
"""
import sys

WT = sys.argv[1] if len(sys.argv) > 1 else "."
src = open(WT + "/formal/ZK60Formal/RunStgTop.lean").read()
th = src.index("theorem stg_productionReadyL_epP_exec_lists ")
end = src.index("(classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :=", th)
t = src[th:end]
i = t.index(" ") + 1
i = t.index(" ", i)
pairs = {"(": ")", "{": "}", "[": "]"}
closers = set(pairs.values())
depth = 0
start = None
op = None
names = []
while i < len(t):
    c = t[i]
    if depth == 0 and c == ":" and op is None:
        break
    if c in pairs:
        if depth == 0:
            start = i
            op = c
        depth += 1
    elif c in closers:
        depth -= 1
        if depth == 0 and op is not None:
            inner = t[start + 1:i]
            if op in "({" and ":" in inner:
                names += inner[:inner.index(":")].split()
            op = None
    i += 1
print(f"{len(names)} named binders")
print(", ".join(names))
