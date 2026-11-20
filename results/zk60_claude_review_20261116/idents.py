#!/usr/bin/env python3
"""List the distinct qualified/lemma-like identifiers used in a theorem body (excluding its own binder names).
Usage: idents.py FILE NAME"""
import re
import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from binders import load  # noqa: E402

d = load(sys.argv[1], sys.argv[2])
names = {b['name'] for b in d['binders']}
ids = re.findall(r"[A-Za-z_][A-Za-z_0-9'.Φ]*", d['body'])
skip = {'by', 'exact', 'have', 'fun', 'intro', 'rw', 'show', 'simp', 'only', 'at', 'with', 'obtain', 'refine', 'rfl',
        'A', 'G', 'k', 'j', 'hk', 'hacc', 'true', 'Lq', 'omega', 'this', 'calc', 'h', 'then', 'else', 'if', 'match'}
seen = {}
for i in ids:
    if i in names or i in skip or len(i) < 3:
        continue
    seen[i] = seen.get(i, 0) + 1
for k in sorted(seen):
    if any(c in k for c in '._') or k[0].islower():
        print(seen[k], k)
