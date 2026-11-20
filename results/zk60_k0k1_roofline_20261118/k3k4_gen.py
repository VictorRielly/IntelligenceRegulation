#!/usr/bin/env python3
"""K3a / K3b / K4 generator (second run, 2026-11-18). Parsing and materialization are copied from gen_k1.py (itself a copy
of the A27 kbench/gen.py); nothing outside this folder is edited.

writes, for one dumped slot (usage: k3k4_gen.py <dump.metal> <out.metal> <attained degree>):
  <out>.metal : k_v13 (verbatim, = gen.py), k_k3a, and the split kernels k_b2_0..1, k_b4_0..3
  <out>.prog  : the K3a program (read by the host's CPU reference)
  <out>.meta  : kernel groups for the host (plain text)
  <out>.json  : product counts and live-table counts (for the README)
and, with the extra argument --k4 <k4.metal>, the K4 operation-cost kernels using the dump's own field helpers.
"""
import json
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
nodes, outs = [], []
for ln in lines:
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
new_nodes, extra, mat = [], [], {}
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
nd = dict(new_nodes)


# ---------------------------------------------------------------- liveness and counts
def live_of(outs_list):
    live, tabs, stack = set(), set(), list(outs_list)
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
    return [(n, e) for n, e in new_nodes if n in live], sorted(tabs, key=lambda x: int(x[1:]))


def products(outs_list):
    nodes_live, _ = live_of(outs_list)
    c = {'f2_mul': 0, 'f2_mulb': 0, 'gl_mul': 0}

    def walk(e):
        if isinstance(e, tuple):
            if e[0] in c:
                c[e[0]] += 1
            for x in e[1]:
                walk(x)
    for _, e in nodes_live:
        walk(e)
    for o in outs_list:
        walk(o)
    return c


def base_mults(c):
    return 3 * c['f2_mul'] + 2 * c['f2_mulb'] + c['gl_mul']


# ---------------------------------------------------------------- kernel template
def template(name, np_de, body_lines):
    """the original kernel's text with its loads, nodes and out terms replaced by body_lines (a list of strings)"""
    s = []
    for ln in lines:
        if ln.startswith('kernel void k_sc_round('):
            s.append(ln.replace('k_sc_round(', f'{name}('))
            continue
        if 'uint np = ' in ln:
            s.append(ln.replace('SC_DE', f'{np_de}u'))
            continue
        if re.match(r'\s*fp2 v\d+ = ln_ext', ln) or re.match(r'\s*(fp2|ulong) n\d+ = ', ln) or re.match(r'\s*out = f2_add\(out, ', ln):
            continue
        if re.match(r'\s*fp2 out = f2\(0UL, 0UL\);', ln):
            s.extend(body_lines)
            continue
        s.append(ln)
    return '\n'.join(s)


def load_line(tv):
    ix = int(tv[1:])
    return f'            fp2 {tv} = ln_ext(tabs, ({ix}UL * a.cap + i) * 2UL, ({ix}UL * a.cap + i + a.nhalf) * 2UL, d, dd);'


def v13_kernel():
    """verbatim as gen.py's ('k_v13', new_nodes, de, False): all tables referenced, then all nodes, then the outs"""
    s = []
    for ln in lines:
        if ln.startswith('kernel void k_sc_round('):
            s.append(ln.replace('k_sc_round(', 'k_v13('))
            continue
        if 'uint np = ' in ln:
            s.append(ln.replace('SC_DE', f'{de}u'))
            continue
        if re.match(r'\s*fp2 v\d+ = ln_ext', ln) or re.match(r'\s*(fp2|ulong) n\d+ = ', ln):
            continue
        if re.match(r'\s*fp2 out = f2\(0UL, 0UL\);', ln):
            tabs_used = sorted(set(re.findall(r'\b(?:v|t)\d+\b', ' '.join(emit(e) for _, e in new_nodes) + ' '.join(emit(o) for o in outs))), key=lambda x: int(x[1:]))
            for tv in tabs_used:
                s.append(load_line(tv))
            for n, e in new_nodes:
                s.append(f'            fp2 {n} = {emit(e)};')
            s.append(ln)
            continue
        s.append(ln)
    return '\n'.join(s)


# ---------------------------------------------------------------- K3a
_, v13_tabs = live_of(outs)
cnt = products(outs)
Nee, Neb, Nbb = cnt['f2_mul'], cnt['f2_mulb'], cnt['gl_mul']
T = len(v13_tabs)
prog, k3a_body = [], []
ccf, cbf = 0, 0   # fresh constant indices (distinct operands so no product is a common subexpression of another)
used_pairs = set()
acc_k = 0
k3a_body.append('            fp2 a0 = f2(0UL, 0UL); fp2 a1 = a0; fp2 a2 = a0; fp2 a3 = a0; ulong bacc = 0UL;')
for m, tv in enumerate(v13_tabs):
    ix = int(tv[1:])
    k3a_body.append(load_line(tv).replace(f'fp2 {tv} =', f'fp2 w{m} ='))
    prog.append(f'LD {m} {ix}')
    n_ee = (m + 1) * Nee // T - m * Nee // T
    n_eb = (m + 1) * Neb // T - m * Neb // T
    n_bb = (m + 1) * Nbb // T - m * Nbb // T
    for j in range(n_ee):
        s = (j // 2) % 3
        if j % 2 == 0 and m - 1 - s >= 0 and (m, s) not in used_pairs:
            used_pairs.add((m, s))
            k3a_body.append(f'            a{acc_k % 4} = f2_add(a{acc_k % 4}, f2_mul(w{m}, w{m - 1 - s}));')
            prog.append(f'EE {acc_k % 4} {m} v {m - 1 - s}')
        else:
            k3a_body.append(f'            a{acc_k % 4} = f2_add(a{acc_k % 4}, f2_mul(w{m}, CF(cf, {ccf}u)));')
            prog.append(f'EE {acc_k % 4} {m} c {ccf}')
            ccf += 1
        acc_k += 1
    for j in range(n_eb):
        k3a_body.append(f'            a{acc_k % 4} = f2_add(a{acc_k % 4}, f2_mulb(w{m}, cf[{2 * cbf + 1}u]));')
        prog.append(f'EB {acc_k % 4} {m} {2 * cbf + 1}')
        cbf += 1
        acc_k += 1
    for j in range(n_bb):
        k3a_body.append(f'            bacc = gl_add(bacc, gl_mul(w{m}.c0, cf[{2 * cbf + 1}u]));')
        prog.append(f'BB {m} {2 * cbf + 1}')
        cbf += 1
k3a_body.append('            fp2 out = f2_addb(f2_add(f2_add(a0, a1), f2_add(a2, a3)), bacc);')
assert ccf < 4000 and 2 * cbf + 1 < 8000, (ccf, cbf)
k3a = template('k_k3a', de, k3a_body)

# ---------------------------------------------------------------- K3b
big = None
for o in outs:
    if isinstance(o, tuple) and o[0] == 'f2_mul' and isinstance(o[1][1], str) and o[1][1] in nd:
        sub = flatten_add(nd[o[1][1]])
        if len(sub) > 2 and (big is None or len(sub) > len(big[2])):
            big = (o[1][0], o[1][1], sub, o)
assert big is not None
factor, bignode, subterms, bigout = big
small_outs = [o for o in outs if o is not bigout]
items = [('sub', t) for t in subterms] + [('out', o) for o in small_outs]


def item_cost(it):
    e = it[1]
    nl, _ = live_of([e])
    return cs(e) + sum(cs(x) for _, x in nl), set(live_of([e])[1])


def build_groups(G):
    costs = [(item_cost(it), it) for it in items]
    costs.sort(key=lambda x: -x[0][0])
    groups = [{'cost': 0, 'tabs': set(), 'items': []} for _ in range(G)]
    for (c, tabs), it in costs:
        # least added cost; tie: fewest tables newly needed
        g = min(groups, key=lambda g: (g['cost'], len(tabs - g['tabs'])))
        g['cost'] += c
        g['tabs'] |= tabs
        g['items'].append(it)
    return groups


def group_outs(g):
    subs = [it[1] for it in g['items'] if it[0] == 'sub']
    res = [it[1] for it in g['items'] if it[0] == 'out']
    if subs:
        acc = subs[0]
        for x in subs[1:]:
            acc = ('f2_add', [acc, x])
        res.insert(0, ('f2_mul', [factor, acc]))
    return res


def split_kernel(name, o_list):
    nl, tl = live_of(o_list)
    body = [load_line(tv) for tv in tl]
    body += [f'            fp2 {n} = {emit(e)};' for n, e in nl]
    body.append('            fp2 out = f2(0UL, 0UL);')
    body += [f'            out = f2_add(out, {emit(o)});' for o in o_list]
    return template(name, de, body), len(tl), products(o_list)


meta = {'v13_live_tabs': T, 'v13_counts': cnt, 'v13_base_mults': base_mults(cnt), 'big_out': emit(bigout)[:80],
        'n_subterms': len(subterms), 'splits': {}}
kernels = [v13_kernel(), k3a]
mlines = []
for G in (2, 4):
    groups = build_groups(G)
    names, info = [], []
    for gi, g in enumerate(groups):
        name = f'k_b{G}_{gi}'
        kt, ntab, c = split_kernel(name, group_outs(g))
        kernels.append(kt)
        names.append(name)
        info.append({'name': name, 'live_tabs': ntab, 'counts': c, 'base_mults': base_mults(c), 'items': len(g['items'])})
    meta['splits'][str(G)] = info
    mlines.append(f'SPLIT {G} ' + ' '.join(names))

k0_struct = 'struct RoundArgs { ulong nhalf; ulong cap; uint eval_one; uint nthreads; };\n'
open(out_path, 'w').write(head + k0_struct + '\n' + '\n\n'.join(kernels) + '\n')
open(out_path.replace('.metal', '.prog'), 'w').write('\n'.join(prog) + '\n')
open(out_path.replace('.metal', '.meta'), 'w').write('\n'.join(mlines) + '\n')
open(out_path.replace('.metal', '.json'), 'w').write(json.dumps(meta, indent=1) + '\n')
print(f'tables {k}, kmax {k + len(extra)}; v13 live tabs {T}; products ee {Nee} eb {Neb} bb {Nbb} (base mults {base_mults(cnt)}); '
      f'K3a program {len(prog)} lines')
for G in ('2', '4'):
    print(f'  split {G}:', [(i["name"], i["live_tabs"], i["base_mults"]) for i in meta['splits'][G]])

# ---------------------------------------------------------------- K4
if len(sys.argv) > 5 and sys.argv[4] == '--k4':
    INIT = '''
inline ulong k4_u(uint tid, ulong c, ulong a, ulong b, ulong z) { return gl_canon(ulong(tid) * a + c * b + z); }
'''
    A, B, C2, D = '0x9E3779B97F4A7C15UL', '0xD1B54A32D192ED03UL', '0xBF58476D1CE4E5B9UL', '0x94D049BB133111EBUL'
    E, F = '0xA24BAED4963EE407UL', '0x9FB21C651E98DF25UL'
    kk = [INIT]

    def thr(name, kind, opx):
        """eight independent chains per thread, 8 steps per iteration, `rep` iterations"""
        L = [f'kernel void {name}(device ulong *out [[buffer(0)]], constant uint &rep [[buffer(1)]], uint tid [[thread_position_in_grid]]) {{']
        for c in range(8):
            if kind == 'b':
                L.append(f'    ulong x{c} = k4_u(tid, {c}UL, {A}, {B}, 0UL), y{c} = k4_u(tid, {c}UL, {C2}, {D}, 1UL);')
            else:
                L.append(f'    fp2 x{c} = f2(k4_u(tid, {c}UL, {A}, {B}, 0UL), k4_u(tid, {c}UL, {E}, {F}, 7UL)); '
                         f'fp2 y{c} = f2(k4_u(tid, {c}UL, {C2}, {D}, 1UL), k4_u(tid, {c}UL, {F}, {A}, 3UL));')
        L.append('    for (uint r = 0u; r < rep; r++) {')
        L.append('        for (uint s = 0u; s < 8u; s++) {')
        for c in range(8):
            L.append(f'            x{c} = {opx(c)};')
        L.append('        }')
        L.append('    }')
        if kind == 'b':
            L.append('    out[tid] = ' + ' ^ '.join(f'x{c}' for c in range(8)) + ';')
        else:
            L.append('    out[tid] = ' + ' ^ '.join(f'x{c}.c0 ^ x{c}.c1' for c in range(8)) + ';')
        L.append('}')
        return '\n'.join(L)

    kk.append(thr('k4_gl_add', 'b', lambda c: f'gl_add(x{c}, y{c})'))
    kk.append(thr('k4_gl_mul', 'b', lambda c: f'gl_mul(x{c}, y{c})'))
    kk.append(thr('k4_f2_mul', 'e', lambda c: f'f2_mul(x{c}, y{c})'))
    kk.append(thr('k4_f2_mulb', 'e', lambda c: f'f2_mulb(x{c}, y{c}.c0)'))

    def dep(name, kind, opx):
        L = [f'kernel void {name}(device ulong *out [[buffer(0)]], constant uint &n [[buffer(1)]], uint tid [[thread_position_in_grid]]) {{']
        if kind == 'b':
            L.append(f'    ulong x = k4_u(tid, 0UL, {A}, {B}, 0UL), y = k4_u(tid, 0UL, {C2}, {D}, 1UL);')
        else:
            L.append(f'    fp2 x = f2(k4_u(tid, 0UL, {A}, {B}, 0UL), k4_u(tid, 0UL, {E}, {F}, 7UL)); '
                     f'fp2 y = f2(k4_u(tid, 0UL, {C2}, {D}, 1UL), k4_u(tid, 0UL, {F}, {A}, 3UL));')
        L.append('    for (uint i = 0u; i < n; i++) { x = ' + opx + '; }')
        L.append('    out[tid] = ' + ('x;' if kind == 'b' else 'x.c0 ^ x.c1;'))
        L.append('}')
        return '\n'.join(L)

    kk.append(dep('k4d_gl_add', 'b', 'gl_add(x, y)'))
    kk.append(dep('k4d_gl_mul', 'b', 'gl_mul(x, y)'))
    kk.append(dep('k4d_f2_mul', 'e', 'f2_mul(x, y)'))
    open(sys.argv[5], 'w').write(head + '\n'.join(kk) + '\n')
    print('K4 source written', sys.argv[5])
