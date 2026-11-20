#!/usr/bin/env python3
"""k_v13 in the K3/K4 libraries must be byte-identical to the one the unmodified A27 gen.py writes (build/ref14.metal, ref18.metal)."""
import sys

R = '/Users/victorrielly/IntelligenceRegulation/results/zk60_k0k1_roofline_20261118/build/'


def kern(path, name):
    s = open(path).read()
    i = s.index(f'kernel void {name}(')
    j = s.find('\nkernel void ', i + 10)
    return s[i:j if j >= 0 else len(s)].strip()


ok = True
for a, b in (('k3k4_s14', 'ref14'), ('k3k4_s18', 'ref18')):
    same = kern(R + a + '.metal', 'k_v13') == kern(R + b + '.metal', 'k_v13')
    ok &= same
    print(a, 'k_v13 identical to unmodified gen.py output:', same)
sys.exit(0 if ok else 1)
