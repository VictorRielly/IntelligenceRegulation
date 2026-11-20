#!/usr/bin/env python3
"""Confirm the k_v13 text in our s14/s18.metal is byte-identical to the one the unmodified A27 gen.py writes."""
import re
import sys

R = '/Users/victorrielly/IntelligenceRegulation/results/zk60_k0k1_roofline_20261118/build/'


def kern(path, name):
    s = open(path).read()
    i = s.index(f'kernel void {name}(')
    j = s.index('\nkernel void ', i + 10) if '\nkernel void ' in s[i + 10:] else len(s)
    return s[i:j].strip()


ok = True
for a, b in (('s14', 'ref14'), ('s18', 'ref18')):
    x, y = kern(R + a + '.metal', 'k_v13'), kern(R + b + '.metal', 'k_v13')
    same = x == y
    ok &= same
    print(a, 'k_v13 identical to unmodified gen.py output:', same, f'({len(x)} chars)')
sys.exit(0 if ok else 1)
