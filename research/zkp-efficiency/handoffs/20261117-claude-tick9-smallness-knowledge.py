"""Tick 9 toy: the 'neighbouring values' step of the smallness test (rng.h, rng_theta comment).

Claim under test (authors' comment, restated): fix a column pair (M, U) in F^2 (a packed entry and one read) and any
other column. If the first column is NOT explained (no integers y0, y1 in (-2D, 2D) with M = y0 + r y1 and
U = w0 y0 + w1 y1 mod p), then over Theta in {-1,0,1} with probabilities (1/4, 1/2, 1/4), a single combination
passes (exists psi0, psi1 in [-D, D) with combo_M = psi0 + r psi1 and combo_U = w0 psi0 + w1 psi1) with probability at
most 1/2. With (1/3, 1/3, 1/3) the bound is 2/3, which is why 0 gets probability 1/2.

Toy sizes: D = 2, lanes = 2, r = 8 (4D-2 = 6 < r), p = 59 ((4D-2)(1+r) = 54 < p). Exhaustive over all pairs of
columns (the unexplained one and one arbitrary other), for several read weights. Standard library plus numpy-free
pure python with bit tricks would be slow, so this uses numpy if present. Memory: a few tens of MB.
"""
import itertools
import numpy as np

D, R, P = 2, 8, 59
assert 4 * D - 2 < R and (4 * D - 2) * (1 + R) < P


def run(w0, w1):
    # explained set: y0, y1 in (-2D, 2D)
    def img(lo, hi):
        s = np.zeros((P, P), dtype=bool)
        for y0 in range(lo, hi):
            for y1 in range(lo, hi):
                s[(y0 + R * y1) % P, (w0 * y0 + w1 * y1) % P] = True
        return s
    explained = img(-2 * D + 1, 2 * D)      # (-2D, 2D)
    window = img(-D, D)                     # [-D, D)
    # check uniqueness of unpacking inside (-2D, 2D) for the packing alone
    seen = {}
    for y0 in range(-2 * D + 1, 2 * D):
        for y1 in range(-2 * D + 1, 2 * D):
            seen.setdefault((y0 + R * y1) % P, set()).add((y0, y1))
    assert all(len(v) == 1 for v in seen.values()), "packing not unique"
    ms, us = np.meshgrid(np.arange(P), np.arange(P), indexing="ij")
    ms, us = ms.ravel(), us.ravel()
    unexpl = ~explained[ms, us]
    cols = np.arange(P * P)
    out = {}
    for name, probs in (("(1/4,1/2,1/4)", {-1: .25, 0: .5, 1: .25}), ("(1/3,1/3,1/3)", {-1: 1 / 3, 0: 1 / 3, 1: 1 / 3})):
        worst = 0.0
        # col a = unexplained one (index over all pairs), col b = any other
        a_idx = cols[unexpl]
        for chunk in np.array_split(a_idx, 8):
            am, au = ms[chunk][:, None], us[chunk][:, None]
            bm, bu = ms[None, :], us[None, :]
            pr = np.zeros((len(chunk), P * P))
            for ta, pa in probs.items():
                for tb, pb in probs.items():
                    cm = (ta * am + tb * bm) % P
                    cu = (ta * au + tb * bu) % P
                    pr += pa * pb * window[cm, cu]
            worst = max(worst, pr.max())
        out[name] = worst
    return out, int(unexpl.sum()), int(explained.sum())


for w0, w1 in ((1, 0), (1, 1), (3, 7), (0, 5), (13, 29)):
    res, n_unexpl, n_expl = run(w0, w1)
    print(f"w=({w0},{w1}) explained pairs {n_expl} of {P*P}; worst Pr[pass] over all unexplained (a, any b): {res}")
