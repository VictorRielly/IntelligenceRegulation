#!/usr/bin/env python3
"""K1 generator (2026-11-18). A copy of results/zk60_a27_app_20261107/kbench/gen.py with the kernel
emission for v13 kept verbatim and two roofline kernels added. Nothing in the original is edited.

kernels written to <out>.metal:
  k_v13  : A27's later-round kernel as shipped (materialized linear nodes, attained degree np 4). Same code
           path as gen.py's ('k_v13', new_nodes, de, False).
  k_k1   : K1. The SAME loads as k_v13 (the same tables, the same lo/hi words, the same index pattern, the same
           d == 0 / d == 1 branches as ln_ext) and a trivial body: every loaded word is xored into the thread's
           accumulator. No line-value arithmetic, no polynomial body.
  k_k1b  : extra, not the pre-stated K1. As k_k1 but the loads go through ln_ext (the line values lo + d (hi - lo)
           are computed) and only the body is dropped; its value is xored. Separates "the loads" from "the line
           values" in the gap between k_k1 and k_v13.
and <out>.tabs : the table indices k_v13 loads (one per line), for the host's CPU check.

usage: gen_k1.py <dump.metal> <out.metal> <attained degree>
"""
import re
import sys

src = open(sys.argv[1]).read()
out_path = sys.argv[2]
de = int(sys.argv[3])
head = src[:src.index('// slot')]
k1_at = src.index('kernel void k_sc_round(')
k1_start = src.rfind('// slot', 0, k1_at)
k1 = src[k1_start:]
k = int(re.search(r'#define SC_K (\d+)', src).group(1))


def tokenize(s):
    return re.findall(r'[A-Za-z_]\w*|\d+[uUL]*|[(),\[\]]', s)


def parse(toks, i=0):
    t = toks[i]
    if i + 1 < len(toks) and toks[i + 1] == '(':
        args, j = [], i + 2
        while toks[j] != ')':
            a, j = parse(toks, j)
            args.append(a)
            if toks[j] == ',':
                j += 1
        return (t, args), j + 1
    if i + 1 < len(toks) and toks[i + 1] == '[':
        return ('idx', [t, toks[i + 2]]), i + 4
    return t, i + 1


def emit(e):
    if isinstance(e, str):
        return e
    f, args = e
    if f == 'idx':
        return f'{args[0]}[{args[1]}]'
    return f'{f}(' + ', '.join(emit(a) for a in args) + ')'


lines = k1.split('\n')
loads, nodes, outs = {}, [], []
for ln in lines:
    m = re.match(r'\s*fp2 (v\d+) = (ln_ext\(.*\));$', ln)
    if m:
        loads[m.group(1)] = m.group(2)
        continue
    m = re.match(r'\s*(fp2|ulong) (n\d+) = (.*);$', ln)
    if m:
        e, _ = parse(tokenize(m.group(3)))
        nodes.append((m.group(2), e))
        continue
    m = re.match(r'\s*out = f2_add\(out, (.*)\);$', ln)
    if m:
        e, _ = parse(tokenize(m.group(1)))
        outs.append(e)
deg = {}


def dg(e):
    if isinstance(e, str):
        if re.fullmatch(r'v\d+', e):
            return 1
        if re.fullmatch(r'n\d+', e):
            return deg[e]
        return 0
    f, a = e
    if f in ('CF', 'idx', 'f2'):
        return 0
    if f in ('f2_mul', 'f2_mulb', 'gl_mul'):
        return dg(a[0]) + dg(a[1])
    return max(dg(x) for x in a)


def cs(e):
    if isinstance(e, str):
        return 0
    f, a = e
    c = {'f2_mul': 3, 'f2_mulb': 2, 'gl_mul': 1}.get(f, 0)
    return c + sum(cs(x) for x in a)


for n, e in nodes:
    deg[n] = dg(e)


def flatten_add(e):
    if isinstance(e, tuple) and e[0] == 'f2_add':
        return flatten_add(e[1][0]) + flatten_add(e[1][1])
    return [e]


# v3 materialization, verbatim from gen.py
consumers = {n: set() for n, _ in nodes}


def refs(e, acc):
    if isinstance(e, str):
        if re.fullmatch(r'n\d+', e):
            acc.add(e)
        return acc
    for x in e[1]:
        refs(x, acc)
    return acc


for n, e in nodes:
    for r in refs(e, set()):
        consumers[r].add(n)
for o in outs:
    for r in refs(o, set()):
        consumers[r].add('out')
new_nodes, extra = [], []
mat = {}
for n, e in nodes:
    if deg[n] <= 1 and cs(e) >= 3 and any(c == 'out' or deg.get(c, 2) >= 2 for c in consumers[n]):
        t = f't{k + len(extra)}'
        extra.append(t)
        mat[n] = t
        new_nodes.append((n, t))
        continue
    if deg[n] >= 2:
        terms = flatten_add(e)
        lin = [x for x in terms if dg(x) <= 1 and not (isinstance(x, str) and x in mat)]
        if len(lin) >= 2 and sum(cs(x) for x in lin) >= 3:
            t = f't{k + len(extra)}'
            extra.append(t)
            rest = [x for x in terms if not (dg(x) <= 1 and not (isinstance(x, str) and x in mat))]
            acc = t
            for x in rest:
                acc = ('f2_add', [acc, x])
            new_nodes.append((n, acc))
            continue
    new_nodes.append((n, e))


def tabs_used_of(body_nodes):
    """tables referenced by v13's source (gen.py loads all of them; the Metal compiler drops a load nothing uses)"""
    return sorted(set(re.findall(r'\b(?:v|t)\d+\b', ' '.join(emit(e) for _, e in body_nodes) + ' '.join(emit(o) for o in outs))),
                  key=lambda x: int(x[1:]))


def live_tabs_of(body_nodes):
    """tables reachable from the outputs through live nodes: what v13 really loads after dead-code removal.
    The K1 kernels load exactly these, so K1 does not load a table v13's compiled kernel never touches."""
    nd = dict(body_nodes)
    live, tabs, stack = set(), set(), list(outs)
    while stack:
        e = stack.pop()
        if isinstance(e, str):
            if e in nd and e not in live:
                live.add(e)
                stack.append(nd[e])
            elif re.fullmatch(r'[vt]\d+', e):
                tabs.add(e)
            continue
        stack.extend(e[1])
    return sorted(tabs, key=lambda x: int(x[1:]))


def kernel(name, body_nodes, np_de, small):
    """verbatim from gen.py (small is always False here)"""
    s = []
    for ln in lines:
        if ln.startswith('kernel void k_sc_round('):
            s.append(ln.replace('k_sc_round(', f'{name}('))
            continue
        if 'uint np = ' in ln:
            s.append(ln.replace('SC_DE', f'{np_de}u') if np_de else ln)
            continue
        if re.match(r'\s*fp2 v\d+ = ln_ext', ln):
            continue
        if re.match(r'\s*(fp2|ulong) n\d+ = ', ln):
            continue
        if re.match(r'\s*fp2 out = f2\(0UL, 0UL\);', ln):
            for tv in tabs_used_of(body_nodes):
                ix = int(tv[1:])
                f = 'ln_ext_s' if small else 'ln_ext'
                tail = 'd' if small else 'd, dd'
                s.append(f'            fp2 {tv} = {f}(tabs, ({ix}UL * a.cap + i) * 2UL, ({ix}UL * a.cap + i + a.nhalf) * 2UL, {tail});')
            for n, e in body_nodes:
                s.append(f'            fp2 {n} = {emit(e)};')
            s.append(ln)
            continue
        s.append(ln)
    return '\n'.join(s)


def k1kernel(name, body_nodes, np_de, mode):
    """K1 kernels: the loads of `kernel(...)`, the body replaced by xors of what was loaded."""
    s = []
    for ln in lines:
        if ln.startswith('kernel void k_sc_round('):
            s.append(ln.replace('k_sc_round(', f'{name}('))
            continue
        if 'uint np = ' in ln:
            s.append(ln.replace('SC_DE', f'{np_de}u'))
            continue
        if re.match(r'\s*fp2 v\d+ = ln_ext', ln):
            continue
        if re.match(r'\s*(fp2|ulong) n\d+ = ', ln):
            continue
        if re.match(r'\s*out = f2_add\(out, ', ln):
            continue
        if re.match(r'\s*acc = f2_add\(acc, out\);', ln):
            continue
        if re.match(r'\s*fp2 out = f2\(0UL, 0UL\);', ln):
            s.append('            ulong x0 = 0UL, x1 = 0UL;')
            for tv in live_tabs_of(body_nodes):
                ix = int(tv[1:])
                lo = f'({ix}UL * a.cap + i) * 2UL'
                hi = f'({ix}UL * a.cap + i + a.nhalf) * 2UL'
                if mode == 'ld':
                    s.append(f'            ld_xor(tabs, {lo}, {hi}, d, x0, x1);')
                else:
                    s.append(f'            {{ fp2 q = ln_ext(tabs, {lo}, {hi}, d, dd); x0 ^= q.c0; x1 ^= q.c1; }}')
            s.append('            acc = f2(acc.c0 ^ x0, acc.c1 ^ x1);')
            continue
        s.append(ln)
    return '\n'.join(s)


prelude = '''
// K1: the loads of ln_ext (same branches on d), xored into x0, x1 instead of combined
inline void ld_xor(device const ulong *tabs, ulong lo, ulong hi, uint d, thread ulong &x0, thread ulong &x1) {
    ulong l0 = tabs[lo], l1 = tabs[lo + 1];
    if (d == 0u) { x0 ^= l0; x1 ^= l1; return; }
    ulong h0 = tabs[hi], h1 = tabs[hi + 1];
    if (d == 1u) { x0 ^= h0; x1 ^= h1; return; }
    x0 ^= l0 ^ h0; x1 ^= l1 ^ h1;
}
'''
k0_struct = 'struct RoundArgs { ulong nhalf; ulong cap; uint eval_one; uint nthreads; };\n'
body = head + k0_struct + prelude
body += '\n' + kernel('k_v13', new_nodes, de, False) + '\n'
body += '\n' + k1kernel('k_k1', new_nodes, de, 'ld') + '\n'
body += '\n' + k1kernel('k_k1b', new_nodes, de, 'ln') + '\n'
open(out_path, 'w').write(body)
used = live_tabs_of(new_nodes)
open(out_path.replace('.metal', '.tabs'), 'w').write('\n'.join(x[1:] for x in used) + '\n')
print(f'tables {k}, nodes {len(nodes)}, materialized {len(extra)}; kmax {k + len(extra)}; tables referenced by v13 source: '
      f'{len(tabs_used_of(new_nodes))}, live (loaded by v13 after dead-code removal, and by k1): {len(used)}')
