#!/usr/bin/env python3
"""A33 G4: the trained-block CPU/Metal digests of the patched and the unpatched binary, side by side."""
import re
from pathlib import Path

RAW = Path(__file__).resolve().parent / "raw"
PAT = re.compile(r"M4-TRAINED (\S+) cpu [0-9.]+ s metal-(cold|warm) .*?digest cpu ([0-9a-f]{64}) metal ([0-9a-f]{64})")


def read(name):
    out = {}
    for m in PAT.finditer((RAW / name).read_text()):
        out.setdefault(m.group(1), set()).add((m.group(3), m.group(4)))
    return out


import sys

pre = sys.argv[1] if len(sys.argv) > 1 else ""  # "m_": the merged tree's runs
p, u = read(f"{pre}g4_m4_trained_patched.log"), read(f"{pre}g4_m4_trained_unpatched.log")
ok = True
for prof in sorted(p):
    cpu_eq_metal = all(c == m for c, m in p[prof] | u.get(prof, set()))
    same = p[prof] == u.get(prof)
    ok &= cpu_eq_metal and same
    (c, _), = list(p[prof])[:1]
    print(f"{prof:24s} patched digest {c[:16]}  cpu==metal {cpu_eq_metal}  patched==unpatched {same}")
print("ALL EQUAL" if ok and set(p) == set(u) and len(p) == 6 else "MISMATCH")
