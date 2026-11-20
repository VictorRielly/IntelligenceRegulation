#!/usr/bin/env python3
"""k_v13 in the K5 libraries: for the A26 dumps byte-identical to the unmodified A27 gen.py's k_v13 (build/ref14.metal, ref18.metal);
for the A27 dumps (8B profile) the dumped kernel itself, renamed, with SC_DE replaced by its attained degree 4u."""
import re
import sys

R = '/Users/victorrielly/IntelligenceRegulation/results/zk60_k0k1_roofline_20261118/build/'
D = '/Users/victorrielly/zk60-artifacts/a27_shader_dumps_20261117/w16r2_8b/'


def kern(path, name):
    s = open(path).read()
    i = s.index(f'kernel void {name}(')
    j = s.index('\n}\n', i) + 2   # the kernel's closing brace (gen.py's text also carries trailing preprocessor lines of the dump)
    return s[i:j].strip()


def dumped(path, name, newname):
    s = open(path).read()
    i = s.index(f'kernel void {name}(')
    j = s.index('\n}\n', i) + 2
    t = s[i:j]
    t = t.replace(f'kernel void {name}(', f'kernel void {newname}(', 1)
    return '\n'.join(l.replace('SC_DE', '4u') if 'uint np = ' in l else l for l in t.split('\n')).strip()


ok = True
for a, b in (('k5_s14', 'ref14'), ('k5_s18', 'ref18')):
    same = kern(R + a + '.metal', 'k_v13') == kern(R + b + '.metal', 'k_v13')
    ok &= same
    print(a, 'k_v13 identical to unmodified gen.py output:', same)
for a, dump, kn in (('k5_b14', 'slot_k36_d4_00000005e420705d.metal', 'k_sc_round'), ('k5_b18', 'slot_k19_d5_000000038f804b13.metal', 'k_sc_round'),
                    ('k5_b18r0', 'slot_k19_d5_000000038f804b13.metal', 'k_sc_round0')):
    same = kern(R + a + '.metal', 'k_v13') == dumped(D + dump, kn, 'k_v13')
    ok &= same
    print(a, f'k_v13 is the dumped {kn} (renamed, SC_DE -> 4u):', same)
sys.exit(0 if ok else 1)
