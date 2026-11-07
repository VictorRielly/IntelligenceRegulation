#!/usr/bin/env python3
"""A27: variants of a dumped slot library's later-round kernel (k_sc_round), for timing only.

v0: as dumped; v1: SC_DE = attained degree (fewer points); v2: line values by additions (small d);
v3: linear nodes materialized as extra tables (their values are loaded, not computed); v13, v123: combined.
Prints the per-point base-product counts of each variant and writes <out>.metal with kernels k_v*.
usage: gen.py <dump.metal> <out.metal> <attained degree>
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
deg, cost = {}, {}


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


def total_cost(name_set):
    # muls per point: line values (2 per used ext table at d >= 2) + every live node
    live = set()
    stack = list(outs)
    nd = dict(name_set)
    while stack:
        e = stack.pop()
        if isinstance(e, str):
            if e in nd and e not in live:
                live.add(e)
                stack.append(nd[e])
            elif re.fullmatch(r'v\d+|t\d+', e) and e not in live:
                live.add(e)
            continue
        stack.extend(e[1])
    body = sum(cs(nd[n]) for n in live if n in nd) + sum(cs(o) for o in outs)
    tabs = sum(1 for x in live if re.fullmatch(r'v\d+|t\d+', x))
    return body, tabs


# v3: materialize linear nodes with a nonlinear consumer, and the linear part of nonlinear sums
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
c0 = total_cost(nodes)
c3 = total_cost(new_nodes)
print(f'tables {k}, nodes {len(nodes)}, materialized {len(extra)}; per point: v0 body {c0[0]} muls + {c0[1]} line values; '
      f'v3 body {c3[0]} muls + {c3[1]} line values (2 muls each for d >= 2 in v0/v1/v3, adds in v2)')


def kernel(name, body_nodes, np_de, small):
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
            tabs_used = sorted(set(re.findall(r'\b(?:v|t)\d+\b', ' '.join(emit(e) for _, e in body_nodes) + ' '.join(emit(o) for o in outs))), key=lambda x: int(x[1:]))
            for tv in tabs_used:
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


prelude = '''
inline fp2 ln_ext_s(device const ulong *tabs, ulong lo, ulong hi, uint d) {
    fp2 l = f2(tabs[lo], tabs[lo + 1]);
    if (d == 0u) { return l; }
    fp2 h = f2(tabs[hi], tabs[hi + 1]);
    if (d == 1u) { return h; }
    fp2 st = f2_sub(h, l);
    fp2 r = f2_add(h, st);
    for (uint e = 2u; e < d; e++) { r = f2_add(r, st); }
    return r;
}
'''
k0_struct = 'struct RoundArgs { ulong nhalf; ulong cap; uint eval_one; uint nthreads; };\n'
body = head + k0_struct + prelude
for name, bn, npd, small in [('k_v0', nodes, None, False), ('k_v1', nodes, de, False), ('k_v2', nodes, None, True), ('k_v3', new_nodes, None, False),
                             ('k_v13', new_nodes, de, False), ('k_v123', new_nodes, de, True)]:
    body += '\n' + kernel(name, bn, npd, small) + '\n'
open(out_path, 'w').write(body)
print(f'kmax {k + len(extra)}')
