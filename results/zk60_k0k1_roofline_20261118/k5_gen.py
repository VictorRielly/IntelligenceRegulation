#!/usr/bin/env python3
"""K5 generator (third run, 2026-11-18). Parsing, materialization and splitting derive from k3k4_gen.py / gen_k1.py in this
folder (themselves copies of the A27 kbench gen.py). Generalized to: dumped A27 kernels with a second table buffer (xtabs),
base-typed loads (ln_base) and ulong nodes, and the round-0 kernel (k_sc_round0). Nothing outside this folder is edited.

usage: k5_gen.py <dump.metal> <out.metal> <attained degree> [--kernel k_sc_round|k_sc_round0]

writes <out>.metal, <out>.meta (host arm list) and <out>.json (live tables and product counts per kernel).
kernels:
  k_v13        the reference: A26 dumps -> A27's materialized form (as gen.py v13); A27 dumps -> the dumped kernel itself
  k_k1         same loads, body replaced by xors of the loaded words
  k_sG_g       split into G kernels, each its own output buffer (sum on the host)
  k_aG_g       split, accumulate in place: kernel g > 0 adds its partial into the output kernel 0 wrote
  k_g4, k_g4b  G = 4 grouping inside ONE kernel (b: with a scheduling barrier between the groups)
"""
import json
import re
import sys

src = open(sys.argv[1]).read()
out_path = sys.argv[2]
de = int(sys.argv[3])
kname = 'k_sc_round'
if '--kernel' in sys.argv:
    kname = sys.argv[sys.argv.index('--kernel') + 1]
head = src[:src.index('// slot')]
k_at = src.index(f'kernel void {kname}(')
k_end = src.index('\n}\n', k_at) + 2
ktext = src[k_at:k_end]
lines = ktext.split('\n')
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


tinfo, ntype, nodes, outs = {}, {}, [], []
for ln in lines:
    m = re.match(r'\s*(fp2|ulong) (v\d+) = (ln_ext|ln_base)\((tabs|xtabs), \((\d+)UL \* a\.cap \+ i\)', ln)
    if m:
        tinfo[m.group(2)] = (m.group(1), m.group(3), m.group(4), int(m.group(5)))
        continue
    m = re.match(r'\s*(fp2|ulong) (n\d+) = (.*);$', ln)
    if m:
        e, _ = parse(tokenize(m.group(3)))
        nodes.append((m.group(2), e))
        ntype[m.group(2)] = m.group(1)
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


MAT = ('xtabs' not in ktext) and kname == 'k_sc_round'   # A26 dumps: apply A27's materialization (gen.py v3)
new_nodes, extra = [], []
if MAT:
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
    mat = {}
    for n, e in nodes:
        if deg[n] <= 1 and cs(e) >= 3 and any(c == 'out' or deg.get(c, 2) >= 2 for c in consumers[n]):
            t = f't{k + len(extra)}'
            extra.append(t)
            tinfo[t] = ('fp2', 'ln_ext', 'tabs', k + len(extra) - 1)
            mat[n] = t
            new_nodes.append((n, t))
            continue
        if deg[n] >= 2:
            terms = flatten_add(e)
            lin = [x for x in terms if dg(x) <= 1 and not (isinstance(x, str) and x in mat)]
            if len(lin) >= 2 and sum(cs(x) for x in lin) >= 3:
                t = f't{k + len(extra)}'
                extra.append(t)
                tinfo[t] = ('fp2', 'ln_ext', 'tabs', k + len(extra) - 1)
                rest = [x for x in terms if not (dg(x) <= 1 and not (isinstance(x, str) and x in mat))]
                acc = t
                for x in rest:
                    acc = ('f2_add', [acc, x])
                new_nodes.append((n, acc))
                continue
        new_nodes.append((n, e))
else:
    new_nodes = list(nodes)
nd = dict(new_nodes)


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


def load_line(tv):
    ty, fn, buf, ix = tinfo[tv]
    return f'{ty} {tv} = {fn}({buf}, ({ix}UL * a.cap + i) * 2UL, ({ix}UL * a.cap + i + a.nhalf) * 2UL, d, dd);'


def node_line(n, e):
    return f'{ntype.get(n, "fp2")} {n} = {emit(e)};'


def template(name, body_lines, accum=False):
    """the original kernel's text with loads, nodes and out terms replaced by body_lines"""
    s = []
    for ln in lines:
        if ln.startswith('kernel void '):
            s.append(re.sub(r'kernel void \w+\(', f'kernel void {name}(', ln))
            continue
        if 'uint np = ' in ln:
            s.append(ln.replace('SC_DE', f'{de}u'))
            continue
        if re.match(r'\s*(fp2|ulong) v\d+ = (ln_ext|ln_base)', ln) or re.match(r'\s*(fp2|ulong) n\d+ = ', ln) or re.match(r'\s*out = f2_add\(out, ', ln):
            continue
        if re.match(r'\s*fp2 out = f2\(0UL, 0UL\);', ln):
            s.extend(body_lines)
            continue
        if accum and re.match(r'\s*part\[o\] = acc\.c0;', ln):
            s.append('    part[o] = gl_add(part[o], acc.c0);')
            continue
        if accum and re.match(r'\s*part\[o \+ 1\] = acc\.c1;', ln):
            s.append('    part[o + 1] = gl_add(part[o + 1], acc.c1);')
            continue
        s.append(ln)
    return '\n'.join(s)


def ind(l):
    return '            ' + l


def v13_kernel():
    s = []
    for ln in lines:
        if ln.startswith('kernel void '):
            s.append(re.sub(r'kernel void \w+\(', 'kernel void k_v13(', ln))
            continue
        if 'uint np = ' in ln:
            s.append(ln.replace('SC_DE', f'{de}u'))
            continue
        if MAT:
            if re.match(r'\s*fp2 v\d+ = ln_ext', ln) or re.match(r'\s*(fp2|ulong) n\d+ = ', ln):
                continue
            if re.match(r'\s*fp2 out = f2\(0UL, 0UL\);', ln):
                tabs_used = sorted(set(re.findall(r'\b(?:v|t)\d+\b', ' '.join(emit(e) for _, e in new_nodes) + ' '.join(emit(o) for o in outs))), key=lambda x: int(x[1:]))
                for tv in tabs_used:
                    s.append(ind(load_line(tv)))
                for n, e in new_nodes:
                    s.append(ind(f'fp2 {n} = {emit(e)};'))
                s.append(ln)
                continue
        s.append(ln)
    return '\n'.join(s)


def k1_kernel():
    body = ['            ulong x0 = 0UL, x1 = 0UL;']
    _, tl = live_of(outs)
    for tv in tl:
        ty, fn, buf, ix = tinfo[tv]
        f = 'ld_xor' if fn == 'ln_ext' else 'ld_xor_b'
        body.append(f'            {f}({buf}, ({ix}UL * a.cap + i) * 2UL, ({ix}UL * a.cap + i + a.nhalf) * 2UL, d, x0, x1);')
    body.append('            fp2 out = f2(x0, x1);')
    s = template('k_k1', body)
    # the original accumulates with f2_add(acc, out); use xor so the K1 body is only loads and xors
    return s.replace('acc = f2_add(acc, out);', 'acc = f2(acc.c0 ^ out.c0, acc.c1 ^ out.c1);')


# ---------------------------------------------------------------- split structure
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
FINEST = len(items)


def item_cost(it):
    e = it[1]
    nl, tl = live_of([e])
    return cs(e) + sum(cs(x) for _, x in nl), set(tl)


def build_groups(G):
    costs = sorted(((item_cost(it), it) for it in items), key=lambda x: -x[0][0])
    groups = [{'cost': 0, 'tabs': set(), 'items': []} for _ in range(G)]
    for (c, tabs), it in costs:
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


def body_for(o_list, var='out'):
    nl, tl = live_of(o_list)
    b = [ind(load_line(tv)) for tv in tl] + [ind(node_line(n, e)) for n, e in nl]
    return b, [ind(f'{var} = f2_add({var}, {emit(o)});') for o in o_list], len(tl)


meta = {'kernel': kname, 'tables_in_kernel_source': len(tinfo), 'v13_live_tabs': len(live_of(outs)[1]), 'v13_counts': products(outs),
        'v13_base_mults': base_mults(products(outs)), 'n_items': FINEST, 'n_subterms': len(subterms), 'arms': {}}
kernels = [v13_kernel(), k1_kernel()]
mlines = ['ARM v13 k_v13', 'ARM k1 k_k1']
for t in live_of(outs)[1]:
    ty, fn, buf, ix = tinfo[t]
    mlines.append(f'K1TAB {buf} {ix} {"ext" if fn == "ln_ext" else "base"}')
Gs = sorted(set([2, 4, 8, FINEST]) if FINEST > 8 else set([2, 4, FINEST, 8]))
Gs = [g for g in Gs if g <= FINEST]
for G in Gs:
    groups = build_groups(G)
    for kind, pre in (('SPLIT', 's'), ('ACCUM', 'a')):
        names, info = [], []
        for gi, g in enumerate(groups):
            name = f'k_{pre}{G}_{gi}'
            o_list = group_outs(g)
            b, outl, ntab = body_for(o_list)
            body = b + [ind('fp2 out = f2(0UL, 0UL);')] + outl
            kernels.append(template(name, body, accum=(pre == 'a' and gi > 0)))
            c = products(o_list)
            names.append(name)
            info.append({'name': name, 'live_tabs': ntab, 'base_mults': base_mults(c), 'items': len(g['items'])})
        mlines.append(f'{kind} {pre}{G} ' + ' '.join(names))
        meta['arms'][f'{pre}{G}'] = info
# one kernel, G = 4 groups in scoped blocks
groups4 = build_groups(4)
for name, barrier in (('k_g4', False), ('k_g4b', True)):
    body = [ind('fp2 out = f2(0UL, 0UL);')]
    for g in groups4:
        o_list = group_outs(g)
        b, outl, ntab = body_for(o_list, var='gout')
        body += [ind('{')] + b + [ind('fp2 gout = f2(0UL, 0UL);')] + outl + [ind('out = f2_add(out, gout);')]
        if barrier:
            body.append(ind('simdgroup_barrier(mem_flags::mem_none);'))
        body.append(ind('}'))
    kernels.append(template(name, body))
    mlines.append(f'ARM {name[2:]} {name}')

prelude = '''
// K1: the loads of ln_ext / ln_base (same branches on d), xored into x0, x1 instead of combined
inline void ld_xor(device const ulong *tabs, ulong lo, ulong hi, uint d, thread ulong &x0, thread ulong &x1) {
    ulong l0 = tabs[lo], l1 = tabs[lo + 1];
    if (d == 0u) { x0 ^= l0; x1 ^= l1; return; }
    ulong h0 = tabs[hi], h1 = tabs[hi + 1];
    if (d == 1u) { x0 ^= h0; x1 ^= h1; return; }
    x0 ^= l0 ^ h0; x1 ^= l1 ^ h1;
}
inline void ld_xor_b(device const ulong *tabs, ulong lo, ulong hi, uint d, thread ulong &x0, thread ulong &x1) {
    ulong l = tabs[lo];
    if (d == 0u) { x0 ^= l; return; }
    ulong h = tabs[hi];
    if (d == 1u) { x0 ^= h; return; }
    x0 ^= l ^ h;
}
'''
structs = 'struct RoundArgs { ulong nhalf; ulong cap; uint eval_one; uint nthreads; };\n'
open(out_path, 'w').write(head + structs + prelude + '\n' + '\n\n'.join(kernels) + '\n')
open(out_path.replace('.metal', '.meta'), 'w').write('\n'.join(mlines) + '\n')
open(out_path.replace('.metal', '.json'), 'w').write(json.dumps(meta, indent=1) + '\n')
print(f'{kname}: tables in source {len(tinfo)}; v13 live tabs {meta["v13_live_tabs"]}; counts {meta["v13_counts"]} (base mults {meta["v13_base_mults"]}); '
      f'items {FINEST} (subterms {len(subterms)}); G sweep {Gs}; materialized {len(extra)}')
for a, info in meta['arms'].items():
    print(f'  {a}: live tabs {[i["live_tabs"] for i in info]}  base mults {[i["base_mults"] for i in info]}')
