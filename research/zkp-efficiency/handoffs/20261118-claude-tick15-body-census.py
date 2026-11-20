#!/usr/bin/env python3
"""Tick 15 (queue item 32): census of the shipped later-round kernel body (k_v13) at four slot shapes.

Reads (read-only) the generated libraries in results/zk60_k0k1_roofline_20261118/build/k5_*.metal. k_v13 in those files is
the A27 later-round kernel (byte-identical to the shipped generator's per the K1 and K3/K4 checks). Runs nothing on a GPU.

Outputs, per shape:
  - products per point by kind (extension x extension, extension x base-word, base x base), counted from the source text,
    split into 'coefficient' products (one operand a constant CF/cf word) and data products;
  - additions by kind;
  - the longest dependent chain, in ns, using K4's measured dependent-chain latencies (gl_add 29, gl_mul 64, f2_mul 347),
    with memory-load latency left out;
  - the largest number of 32-bit registers held by data values live at once, (a) in the source order as written (all loads
    first, then the nodes), (b) in a depth-first order with each table loaded just before its first use
    (heuristic, not optimal); values held until their last use;
  - the implied concurrency: pair-point evaluations per second needed against the chain length.
"""
import re
import sys

BUILD = '/Users/victorrielly/IntelligenceRegulation/results/zk60_k0k1_roofline_20261118/build/'
SHAPES = {  # name: (file, cap_log2, rounds from cap/4, np, v13 total ms measured)
    'sh14 (Shieldstral slot 14)': ('k5_s14.metal', 19),
    'sh18 (Shieldstral slot 18)': ('k5_s18.metal', 21),
    'b14 (W16R2_8B slot 14)': ('k5_b14.metal', 19),
    'b18 (W16R2_8B slot 18)': ('k5_b18.metal', 21),
}
LAT = {'f2_mul': 347.0, 'f2_mulb': 64.0, 'gl_mul': 64.0, 'f2_add': 29.0, 'f2_sub': 29.0, 'f2_neg': 29.0, 'f2_addb': 29.0,
       'gl_add': 29.0, 'gl_sub': 29.0, 'gl_mul7': 87.0, 'f2': 0.0, 'CF': 0.0, 'idx': 0.0}
K4_PS = {'gl_add': 1.71, 'gl_mul': 4.55, 'f2_mulb': 9.27, 'f2_mul': 23.49}   # ps per op, whole GPU, K4 (16 reps)


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


def kernel_text(path):
    s = open(path).read()
    a = s.index('kernel void k_v13(')
    b = s.index('\n}\n', a) + 2
    return s[a:b]


def load(path):
    lines = kernel_text(path).split('\n')
    tabs, nodes, outs = {}, [], []
    for ln in lines:
        m = re.match(r'\s*(fp2|ulong) ((?:v|t)\d+) = (ln_ext|ln_base)\(', ln)
        if m:
            tabs[m.group(2)] = (m.group(1), m.group(3))
            continue
        m = re.match(r'\s*(fp2|ulong) (n\d+) = (.*);$', ln)
        if m:
            e, _ = parse(tokenize(m.group(3)))
            nodes.append((m.group(2), m.group(1), e))
            continue
        m = re.match(r'\s*out = f2_add\(out, (.*)\);$', ln)
        if m:
            e, _ = parse(tokenize(m.group(1)))
            outs.append(e)
    # keep only what the outputs reach (the Metal compiler drops the rest; K1/K3 loaded only these too)
    nd = {n: e for n, _, e in nodes}
    live, stack = set(), list(outs)
    while stack:
        e = stack.pop()
        if isinstance(e, str):
            if re.fullmatch(r'[vtn]\d+', e) and e not in live:
                live.add(e)
                if e in nd:
                    stack.append(nd[e])
            continue
        stack.extend(e[1])
    tabs = {t: v for t, v in tabs.items() if t in live}
    nodes = [x for x in nodes if x[0] in live]
    return tabs, nodes, outs


def walk(e, fn):
    if isinstance(e, tuple):
        fn(e)
        for x in e[1]:
            walk(x, fn)


def is_const(e):
    """a CF(...) coefficient or a cf[...] word"""
    return isinstance(e, tuple) and e[0] in ('CF', 'idx')


def is_base(e, base_names):
    """operand is a single 64-bit word (a cf word or a base-typed table / node)"""
    if isinstance(e, str):
        return e in base_names
    return e[0] == 'idx'


def census(tabs, nodes, outs):
    base_names = {n for n, (ty, _) in tabs.items() if ty == 'ulong'} | {n for n, ty, _ in nodes if ty == 'ulong'}
    c = {'ee_data': 0, 'ee_coef': 0, 'eb_data': 0, 'eb_coef': 0, 'bb': 0, 'add': 0, 'neg': 0, 'addb': 0}

    def fn(e):
        f, a = e
        if f == 'f2_mul':
            key = 'ee_coef' if is_const(a[0]) or is_const(a[1]) else 'ee_data'
            c[key] += 1
        elif f == 'f2_mulb':
            key = 'eb_coef' if is_const(a[1]) or (isinstance(a[1], tuple) and a[1][0] == 'idx') else 'eb_data'
            c[key] += 1
        elif f == 'gl_mul':
            c['bb'] += 1
        elif f == 'f2_add':
            c['add'] += 1
        elif f == 'f2_neg':
            c['neg'] += 1
        elif f == 'f2_addb':
            c['addb'] += 1
    for _, _, e in nodes:
        walk(e, fn)
    for o in outs:
        walk(o, fn)
        c['add'] += 1   # the out = f2_add(out, term)
    return c, base_names


def depth(e, dnode, dtab):
    if isinstance(e, str):
        if e in dnode:
            return dnode[e]
        if e in dtab:
            return dtab[e]
        return 0.0
    f, a = e
    if f in ('CF', 'idx'):
        return 0.0
    return max(depth(x, dnode, dtab) for x in a) + LAT.get(f, 0.0)


def chain(tabs, nodes, outs):
    # the line value of a table at point d >= 2: lo + d * (hi - lo): sub (29) + mulb (64) + add (29); the load itself is left out
    dtab = {t: 29.0 + 64.0 + 29.0 for t in tabs}
    dnode = {}
    for n, _, e in nodes:
        dnode[n] = depth(e, dnode, dtab)
    acc = 0.0
    longest_term = 0.0
    for o in outs:
        d = depth(o, dnode, dtab)
        longest_term = max(longest_term, d)
    # out is a serial sum of the terms; the sum itself adds 29 ns per term but the terms are independent of each other
    return longest_term + 29.0 * len(outs), longest_term, dtab, dnode


def refs(e, acc):
    if isinstance(e, str):
        if re.fullmatch(r'[vtn]\d+', e):
            acc.add(e)
        return acc
    for x in e[1]:
        refs(x, acc)
    return acc


def regs(name, tabs, nodes):
    if name in tabs:
        return 4 if tabs[name][0] == 'fp2' else 2
    for n, ty, _ in nodes:
        if n == name:
            return 4 if ty == 'fp2' else 2
    raise KeyError(name)


def live_peak(order, uses_of, size):
    """order: list of defs in execution order (loads and nodes); the out terms are executed at the end, in order.
    uses_of: for each def, the set of defs it reads; out terms add pseudo-defs. A def is live from its position to its last reader."""
    pos = {d: i for i, d in enumerate(order)}
    last = {}
    for d in order:
        for r in uses_of[d]:
            last[r] = max(last.get(r, -1), pos[d])
    peak, cur, live = 0, 0, set()
    for i, d in enumerate(order):
        # d's inputs are read at i; they die after i if i is their last use; d becomes live after i
        cur += size(d)
        live.add(d)
        peak = max(peak, cur)
        for r in list(uses_of[d]):
            if last.get(r, -1) == i and r in live:
                cur -= size(r)
                live.discard(r)
        if last.get(d, -1) < 0 and d in live and not d.startswith('O'):
            cur -= size(d)
            live.discard(d)
    return peak


def main():
    print('Census of k_v13 (the shipped later-round body), per pair and point; register units are 32-bit words\n')
    for name, (fname, caplog) in SHAPES.items():
        tabs, nodes, outs = load(BUILD + fname)
        c, base_names = census(tabs, nodes, outs)
        ee, eb = c['ee_data'] + c['ee_coef'], c['eb_data'] + c['eb_coef']
        ntab = len(tabs)
        n_ln = ntab    # one line value (sub, mulb, add) per loaded table at d >= 2
        n_ln_ext = sum(1 for t in tabs.values() if t[0] == 'fp2')
        n_ln_base = ntab - n_ln_ext
        base_mults = 3 * ee + 2 * eb + c['bb'] + 2 * n_ln_ext + 1 * n_ln_base
        print(f'== {name}: {ntab} loaded tables ({n_ln_ext} extension-typed, {n_ln_base} base-typed), {len(nodes)} nodes, {len(outs)} output terms')
        print(f'   ee: {ee} (data x data {c["ee_data"]}, coefficient x data {c["ee_coef"]}); eb: {eb} (coef {c["eb_coef"]}, data {c["eb_data"]}); bb: {c["bb"]}')
        print(f'   line values at d >= 2: {n_ln_ext} extension (2 gl_mul each) + {n_ln_base} base (1 gl_mul each); additions f2_add {c["add"]}, f2_neg {c["neg"]}, f2_addb {c["addb"]}')
        print(f'   base multiplications per point (body + line values): {base_mults}  (K4 cost 3/2/1 per ee/eb/bb; K4 says ee = 5.2 gl_mul)')
        floor_ps = ee * K4_PS['f2_mul'] + (eb + n_ln_ext) * K4_PS['f2_mulb'] + c['bb'] * K4_PS['gl_mul'] + n_ln_base * K4_PS['gl_mul'] \
            + (c['add'] * 2 + c['neg'] * 2 + c['addb'] + 3 * n_ln) * K4_PS['gl_add']
        print(f'   throughput floor (K4 ps/op x counts, whole GPU, additions priced at gl_add, line-value sub/add as 3 gl_add each): {floor_ps/1000:.2f} ns per pair-point')
        L, Lterm, dtab, dnode = chain(tabs, nodes, outs)
        print(f'   longest dependent chain (K4 latencies, loads excluded): one output term {Lterm:.0f} ns; with the serial out sum {L:.0f} ns')
        # liveness
        defs = [t for t in tabs] + [n for n, _, _ in nodes]
        uses = {}
        for t in tabs:
            uses[t] = set()
        for n, _, e in nodes:
            uses[n] = refs(e, set())
        size = lambda d: regs(d, tabs, nodes) if not d.startswith('O') else 4
        # (a) source order
        order_a = [t for t in tabs] + [n for n, _, _ in nodes]
        oa = list(order_a)
        for k, o in enumerate(outs):
            od = f'O{k}'
            uses[od] = refs(o, set())
            oa.append(od)
        pa = live_peak(oa, uses, size)
        # (b) depth-first, loads at first use
        done, order_b = set(), []
        nd = {n: e for n, _, e in nodes}

        def emit(x):
            if x in done:
                return
            for r in sorted(uses[x], key=lambda r: -len(refs_deep(r))):
                emit(r)
            done.add(x)
            order_b.append(x)

        memo = {}

        def refs_deep(x):
            if x in memo:
                return memo[x]
            s = {x}
            for r in uses.get(x, ()):
                s |= refs_deep(r)
            memo[x] = s
            return s
        ob = []
        for k, o in enumerate(outs):
            for r in sorted(refs(o, set()), key=lambda r: -len(refs_deep(r))):
                emit(r)
            order_b_term = f'O{k}'
            order_b.append(order_b_term)
        pb = live_peak(order_b, uses, size)
        # the part of (a) that is only loads (before any node runs)
        loads_regs = sum(regs(t, tabs, nodes) for t in tabs)
        print(f'   live data registers: all loads first (source order) peak {pa}; loads alone {loads_regs}; depth-first with loads at first use, peak {pb}')
        print(f'   (add the loop state, the accumulator (4), index/offset words, and the transient registers of one f2_mul (about 8 to 14); constants CF(cf, n) are loaded from the constant buffer)')
        # per round counts from the measured shapes
        cap = 1 << caplog
        pairs = cap // 2 - 1   # rounds from cap/4 down to 1 (nhalf = cap/4 ... 1): the sum of nhalf
        np_ = 4
        print(f'   pair-points in the timed sequence (rounds with nhalf from cap/4 down to 1): {pairs} pairs x {np_} points = {pairs*np_:,}')
        print()


if __name__ == '__main__':
    main()
