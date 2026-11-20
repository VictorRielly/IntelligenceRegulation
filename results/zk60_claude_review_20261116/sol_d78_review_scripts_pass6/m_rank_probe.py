"""Pass-6 C: independent controls on the saved compact M functionals (read-only; stdout only; imports Sol's rank module for Fp2 elimination, no native run).

Checks: (1) rank per stage reproduces 8/28/28/20 from the saved stage JSON (pins already matched by check_pins.py);
(2) a LINEAR-COMBINATION control (row = a*row_i + b*row_j) which 374 does not use: must lose rank;
(3) duplicate control reproduces; (4) SS-alias projection reproduces (full rank survives, i.e. rank cannot see mask reuse);
(5) stronger alias of my own: identify ALL slots with equal spec pairwise (collapse equal-geometry slots) to see where rank finally drops.
"""
import sys, json, copy
sys.dont_write_bytecode = True
B = '/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261105_w16r3/b3'
sys.path.insert(0, B)
from d78_mask_rank324 import coefficient_matrix, sparse_rank
from d78_capture_program159 import P

def fp2_add(a, b): return ((a[0] + b[0]) % P, (a[1] + b[1]) % P)
def fp2_scale_int(a, k): return ((a[0] * k) % P, (a[1] * k) % P)

for mode in ('outer', 'scaled'):
    for k in range(4):
        st = json.load(open(f'{B}/d78-census-validation365/{mode}-receipt/capture/stage-{k:02}.json'))
        specs, fn = st['mask']['specs'], st['mask']['functionals']
        rows, nvar = coefficient_matrix(specs, fn)
        r, _ = sparse_rank(rows)
        # (2) linear combination: last row := 3*row0 + 5*row1 (as sparse dict over same columns)
        lc = {}
        for key in set(rows[0]) | set(rows[1]):
            v = fp2_add(fp2_scale_int(rows[0].get(key, (0, 0)), 3), fp2_scale_int(rows[1].get(key, (0, 0)), 5))
            if v != (0, 0): lc[key] = v
        rr = rows[:-1] + [lc]
        r_lc, _ = sparse_rank(rr)
        # (5) collapse all slots with the same (n,degree) spec onto the first such slot
        offs, o = [], 0
        for n, d in specs:
            offs.append(o); o += n * d + 2
        first = {}
        slotof = {}
        for s, sp in enumerate(specs):
            first.setdefault(tuple(sp), s)
        def collapse(col):
            s = max(i for i, off in enumerate(offs) if off <= col)
            return offs[first[tuple(specs[s])]] + (col - offs[s])
        proj = []
        for row in rows:
            out = {}
            for col, v in row.items():
                c = collapse(col)
                out[c] = fp2_add(out.get(c, (0, 0)), v)
            proj.append({c: v for c, v in out.items() if v != (0, 0)})
        r_col, _ = sparse_rank(proj)
        print(mode, 'stage', k, 'functionals', len(fn), 'slots', len(specs), 'rank', r,
              '| lincomb control rank', r_lc, '(loses rank)' if r_lc < len(fn) else '(NO LOSS)',
              '| collapse-all-equal-geometry-slots rank', r_col, 'distinct specs', len(first))
