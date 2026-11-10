#!/usr/bin/env python3
"""D63 lane L55: dry run of l55_negative.py's cases (every change applies to its file; no Lean run)."""
import importlib.util
import os

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("neg", os.path.join(HERE, "l55_negative.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
texts = {"c29": open(m.C29).read(), "c49": open(m.C49).read()}
files = {p: open(os.path.join(m.ROOT, p)).read() for p in m.SRC}
bad = 0
for name, mut in m.CASES:
    if mut is None:
        continue
    w, f = mut
    try:
        if w in texts:
            f(texts[w])
        else:
            f(files[w])
    except AssertionError as e:
        print("MISSING", name, e)
        bad += 1
print("l55_neg_dry:", len(m.CASES), "cases,", bad, "missing")
