"""Tick 21 (item 37): split commit_A / commit_H into inverse NTT, forward NTT and hash, from the diag records of the
slot-breakdown traces. Reads only the externalized trace TSVs (standard library). Run: python3 -I <this file>.
Passes are split at each A commit (rows=2504 at W16R2_8B, rows=4577 at Shieldstral); the first pass is dropped (warm-up),
as the analyzer does. Each commit is followed in the trace by three 'diag' records: inverse transform (MODE_COPY,
scaled), forward transform (MODE_PLAIN, not the keyed coset), hash (old k_hash_cols form), re-run on scratch buffers."""
import gzip, statistics as st
T = '/Users/victorrielly/zk60-artifacts/slot18_14_traces_20261117/'
FILES = {
    '8B armA': 'w16r2_8b_armA_prod_batched.17444.tsv.gz',
    '8B armB': 'w16r2_8b_armB_unbatched_sync_lin1.17548.tsv.gz',
    '8B armC': 'w16r2_8b_armC_unbatched_sync_lin0.17646.tsv.gz',
    'Shield armA': 'r13_shield_armA_prod_batched.17767.tsv.gz',
    'Shield armB': 'r13_shield_armB_unbatched_sync_lin1.17921.tsv.gz',
    'Shield armC': 'r13_shield_armC_unbatched_sync_lin0.18055.tsv.gz',
}
def recs(f):
    L = gzip.open(T + f, 'rt').read().splitlines()[1:]
    out = []
    for l in L:
        p = l.split('\t')
        gs, ge = float(p[6]), float(p[7])
        ms = (ge - gs) * 1000 if ge > gs > 0 else (float(p[8]) - float(p[5])) * 1000
        out.append((p[0], p[1], ms))
    return out
def isA(d): return d.startswith('rows=2504 ') or d.startswith('rows=4577 ')
def med(x): return st.median(x)
res = {}
for nm, f in FILES.items():
    R = [r for r in recs(f) if r[0] != 'wprod']
    idx = [i for i, r in enumerate(R) if r[0] == 'commit' and isA(r[1])]
    passes = [R[a:(idx[k + 1] if k + 1 < len(idx) else len(R))] for k, a in enumerate(idx)]
    warm = passes[1:]
    rows = {k: [] for k in ['cA', 'cH', 'A_inv', 'A_fwd', 'A_hash', 'H_inv', 'H_fwd', 'H_hash', 'diag_all', 'total', 'tot_nodiag']}
    for p in warm:
        # find commits and the 3 diag that follow
        cs = [i for i, r in enumerate(p) if r[0] == 'commit']
        assert len(cs) == 2, (nm, len(cs))
        a, h = cs
        da = [r[2] for r in p[a + 1:a + 4]]; dh = [r[2] for r in p[h + 1:h + 4]]
        assert all(r[0] == 'diag' for r in p[a + 1:a + 4]) and all(r[0] == 'diag' for r in p[h + 1:h + 4]), nm
        rows['cA'].append(p[a][2]); rows['cH'].append(p[h][2])
        rows['A_inv'].append(da[0]); rows['A_fwd'].append(da[1]); rows['A_hash'].append(da[2])
        rows['H_inv'].append(dh[0]); rows['H_fwd'].append(dh[1]); rows['H_hash'].append(dh[2])
        dg = sum(r[2] for r in p if r[0] == 'diag'); rows['diag_all'].append(dg)
        tot = sum(r[2] for r in p); rows['total'].append(tot); rows['tot_nodiag'].append(tot - dg)
    m = {k: med(v) for k, v in rows.items()}
    res[nm] = m
    sA = m['A_inv'] + m['A_fwd'] + m['A_hash']; sH = m['H_inv'] + m['H_fwd'] + m['H_hash']
    print(f"== {nm}: warm passes {len(warm)}; total (analyzer) {m['total']:.3f} ms; diag records {m['diag_all']:.3f} ms ({100*m['diag_all']/m['total']:.1f}%); total without diag {m['tot_nodiag']:.3f}")
    print(f"   commit_A {m['cA']:.3f} | diag parts inv {m['A_inv']:.3f} fwd {m['A_fwd']:.3f} hash {m['A_hash']:.3f} sum {sA:.3f} ({sA/m['cA']:.2f} of commit)")
    print(f"   commit_H {m['cH']:.3f} | diag parts inv {m['H_inv']:.3f} fwd {m['H_fwd']:.3f} hash {m['H_hash']:.3f} sum {sH:.3f} ({sH/m['cH']:.2f} of commit)")
    ntt = m['A_inv'] + m['A_fwd'] + m['H_inv'] + m['H_fwd']; hs = m['A_hash'] + m['H_hash']
    f_ntt = ntt / (ntt + hs)
    cc = m['cA'] + m['cH']
    print(f"   NTT share of diag sum f_ntt = {f_ntt:.3f} (fwd only {(m['A_fwd']+m['H_fwd'])/(ntt+hs):.3f}); commit_A+H {cc:.3f} ms = {100*cc/m['total']:.1f}% of analyzer total, {100*cc/m['tot_nodiag']:.1f}% of total without diag")
    for lab, base in [('NTT-all', f_ntt), ('forward-only', (m['A_fwd'] + m['H_fwd']) / (ntt + hs))]:
        for den, dn in [(m['total'], 'analyzer total'), (m['tot_nodiag'], 'total w/o diag')]:
            g = cc * base / den
            print(f"   ceiling if {lab} free: saves {cc*base:.3f} ms = {100*g:.1f}% of {dn}; x{1/(1-g):.3f}")
    # inverse transform is the one a G3 dense-GEMM encoder would not touch (data are coefficients? see handoff)
