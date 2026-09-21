#!/usr/bin/env python3
"""The two channels the toy lemma proved IDENTICALLY, recomputed at the
SHAPED parameters: the pad block (H-pad / M-cols) and the CFS mask channel.

A. THE PAD BLOCK.  `zkp-core/src/pcs.rs::encode_row_zk` encodes a row over a
COSET: `x_j = 7 * w_nn^j`, and the pad half of the column functional is
`E_j[pad k] = Z_n(x_j) * x_j^k`, `Z_n(x) = x^n - 1`.  The pad block on a set
`S` of distinct opened indices is therefore
`diag(Z_n(x_j)) * Vandermonde(x_j)_{k < Q}`, whose determinant on `|S| = Q`
rows is `prod_j Z_n(x_j) * prod_{i<j} (x_j - x_i)` — computed here exactly,
with no elimination, at each shape's own `(n, nn, Q)`.  At the toy `n = Q`;
at the shaped layouts `n` is 1,024 or 16,384 while `Q` stays 256, so the two
halves have different lengths and the check has to be redone.

B. THE CFS MASK CHANNEL.  `zkp-core/src/sumcheck.rs:185-277` ported line for
line.  For every slot of every shape: `dim ker R = 1` (so
`uncovered = 0`), and both published functionals (`sum_weights`,
`eval_weights`) lie in the row span of the published rounds.  Several `rho`
regimes, plus the negative control the toy check used — publish only `d`
values per round instead of `d + 1`.
"""
from __future__ import annotations
import json, os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fieldlib import (P, ONE, ZERO, f2add, f2sub, f2mul, rand_f2, rank_fp)

HERE = os.path.dirname(os.path.abspath(__file__))
MODEL = os.path.join(HERE, "model")


def two_adic_root(k):
    return pow(7, (P - 1) >> k, P)


# --------------------------------------------------------------- A. pads
def pad_block_report(name, log_n, inv_rate, Q, label):
    n = 1 << log_n
    lnn = log_n + (inv_rate.bit_length() - 1)
    nn = 1 << lnn
    w_nn = two_adic_root(lnn)
    out = []
    # `pcs.rs:649` the coset generator must not fall into the subgroup
    assert pow(7, nn, P) != 1, "the coset meets the encoding subgroup"
    # Z_n(x_j) = 7^n * w_{nn/n}^j - 1 : only nn/n distinct values
    rep = nn // n
    w_rep = two_adic_root(rep.bit_length() - 1)
    vals = [(pow(7, n, P) * pow(w_rep, j, P) - 1) % P for j in range(rep)]
    nz = all(v != 0 for v in vals)
    # a direct spot check against the closed form
    rng = random.Random(7)
    ok = True
    for _ in range(64):
        j = rng.randrange(nn)
        x = 7 * pow(w_nn, j, P) % P
        ok &= (pow(x, n, P) - 1) % P == vals[j % rep]
    # node distinctness: j -> 7 w_nn^j is injective on [0, nn)
    inj = len({pow(w_nn, j, P) for j in range(min(nn, 1 << 16))}) == min(nn, 1 << 16)
    # the exact determinant on Q distinct nodes, three column sets
    dets = []
    for tag, idx in (("consecutive", list(range(Q))),
                     ("maximally spread", [j * (nn // Q) for j in range(Q)]),
                     ("pseudo-random", sorted(random.Random(11).sample(range(nn), Q)))):
        xs = [7 * pow(w_nn, j, P) % P for j in idx]
        d = 1
        for j in idx:
            d = d * vals[j % rep] % P
        for a in range(Q):
            for b in range(a + 1, Q):
                d = d * ((xs[b] - xs[a]) % P) % P
                if d == 0:
                    break
            if d == 0:
                break
        dets.append((tag, d != 0))
    out.append(f"  {label:<22} n = 2^{log_n}, rate 1/{inv_rate}, nn = 2^{lnn}, "
               f"Q = {Q}")
    out.append(f"    Z_n(x_j) != 0 at every one of the {nn:,} encoded "
               f"positions: {nz}  ({rep} distinct values, closed form verified "
               f"on 64 random j: {ok})")
    out.append(f"    the nodes 7*w_nn^j are distinct: {inj}")
    out.append(f"    exact det(diag(Z_n) * Vandermonde) on {Q} distinct "
               f"columns != 0: " + ", ".join(f"{t} {v}" for t, v in dets))
    return out


# ----------------------------------------------------------- B. CFS mask
def cfs_round(coeffs, n_vars, degree, j, prev):
    """`sumcheck.rs:256-277`, ported."""
    half = pow(2, P - 2, P)

    def a(jj, e):
        return coeffs[2 + jj * degree + (e - 1)]

    def u(jj, x):
        acc, xp = ZERO, ONE
        for e in range(1, degree + 1):
            xp = f2mul(xp, x)
            acc = f2add(acc, f2mul(a(jj, e), xp))
        return acc

    base = coeffs[0]
    for i, r in enumerate(prev):
        base = f2add(base, u(i, r))
    for i in range(j + 1, n_vars):
        v = u(i, ONE)
        base = f2add(base, (v[0] * half % P, v[1] * half % P))
    scale = ((1 << (n_vars - 1 - j)) % P, 0)
    prod_prev = ONE
    for r in prev:
        prod_prev = f2mul(prod_prev, r)
    out = []
    for x in range(degree + 1):
        xv = (x % P, 0)
        out.append(f2add(f2mul(scale, f2add(base, u(j, xv))),
                         f2mul(f2mul(coeffs[1], prod_prev), xv)))
    return out


def cfs_matrix(n_vars, degree, rho, published):
    """R: coefficient space -> the published round values, as Fp rows over the
    realified coefficient space (2L columns)."""
    L = n_vars * degree + 2
    rows = []
    for j in range(n_vars):
        for x in range(published):
            re = [0] * (2 * L)
            im = [0] * (2 * L)
            for c in range(L):
                basis = [ZERO] * L
                basis[c] = ONE
                v = cfs_round(basis, n_vars, degree, j, rho[:j])[x]
                re[2 * c], re[2 * c + 1] = v[0], (7 * v[1]) % P
                im[2 * c], im[2 * c + 1] = v[1], v[0]
            rows.append(re)
            rows.append(im)
    return rows, L


def sum_weights(n_vars, degree):
    L = n_vars * degree + 2
    w = [((1 << (n_vars - 1)) % P, 0)] * L
    w[0] = ((1 << n_vars) % P, 0)
    w[1] = ONE
    return w


def eval_weights(rho, degree):
    w = [ONE]
    pr = ONE
    for r in rho:
        pr = f2mul(pr, r)
    w.append(pr)
    for r in rho:
        xp = ONE
        for _ in range(degree):
            xp = f2mul(xp, r)
            w.append(xp)
    return w


def realify_functional(v):
    L = len(v)
    re = [0] * (2 * L)
    im = [0] * (2 * L)
    for c, x in enumerate(v):
        re[2 * c], re[2 * c + 1] = x[0], (7 * x[1]) % P
        im[2 * c], im[2 * c + 1] = x[1], x[0]
    return re, im


def cfs_check(n_vars, degree, rho, published):
    rows, L = cfs_matrix(n_vars, degree, rho, published)
    rk = rank_fp(rows, 2 * L)
    ker = 2 * L - rk
    sw = realify_functional(sum_weights(n_vars, degree))
    ew = realify_functional(eval_weights(rho, degree))
    inside = all(rank_fp(rows + [f], 2 * L) == rk for f in (sw[0], sw[1], ew[0], ew[1]))
    return ker, inside


def main():
    out = []
    w = out.append
    w("THE PAD BLOCK AND THE CFS MASK CHANNEL AT THE SHAPED PARAMETERS")
    w("field: Goldilocks; all arithmetic exact")
    w("")
    w("A. THE PAD BLOCK (H-pad, M-cols) — no challenge enters, no union bound")
    w("-" * 74)
    for name in ("toy", "rung_g", "m125"):
        m = json.load(open(os.path.join(MODEL, f"model_{name}.json")))
        sh = m["shape"]
        for line in pad_block_report(name, sh["log_cols"], sh["inv_rate"], 256,
                                     f"{name}  A / H"):
            w(line)
        for line in pad_block_report(name, sh["endpoint_log_n"],
                                     sh["endpoint_inv_rate"], 256,
                                     f"{name}  endpoint/boundary"):
            w(line)
    # `hashline/src/zk.rs:373-375`: the masking commitment's geometry is
    # shape-independent — MASK_LOG_MSG 9, MASK_LOG_DOM 12, MASK_Q 256
    for line in pad_block_report("M", 9, 8, 256, "M (every shape)"):
        w(line)
    w("")
    w("B. THE CFS MASK CHANNEL, slot by slot")
    w("-" * 74)
    w("   `dim ker R` must be 1 over Fp2 (so `uncovered = 0`), and both")
    w("   `sum_weights` and `eval_weights` must lie in the row span, at every")
    w("   rho.  The elimination is over Fp on the REALIFIED coefficient space,")
    w("   so an Fp2 kernel of dimension 1 shows as an Fp kernel of dimension 2.")
    for name in ("rung_g", "m125"):
        m = json.load(open(os.path.join(MODEL, f"model_{name}.json")))
        slots = m["slots"]
        bad = []
        regimes = {}
        for reg in ("uniform", "all-one", "all-equal", "base-field", "all-zero"):
            kers, ins = set(), True
            for s in slots:
                nv = s["main_rounds"] + s["extension_rounds"]
                dg = s["degree"]
                rng = random.Random(hash((name, reg, s["slot"])) & 0xffff)
                if reg == "uniform":
                    rho = [rand_f2(rng) for _ in range(nv)]
                elif reg == "all-one":
                    rho = [ONE] * nv
                elif reg == "all-equal":
                    v = rand_f2(rng)
                    rho = [v] * nv
                elif reg == "base-field":
                    rho = [(rng.randrange(P), 0) for _ in range(nv)]
                else:
                    rho = [ZERO] * nv
                k, i = cfs_check(nv, dg, rho, dg + 1)
                kers.add(k // 2)
                ins &= i
                if k != 2 or not i:
                    bad.append((reg, s["slot"], k, i))
            regimes[reg] = (sorted(kers), ins)
        w(f"  {name}: {len(slots)} slots, "
          f"(N, d) pairs "
          f"{sorted({(s['main_rounds']+s['extension_rounds'], s['degree']) for s in slots})}")
        for reg, (kers, ins) in regimes.items():
            w(f"    rho {reg:<12} dim_Fp2 ker R {kers}   both functionals in the "
              f"row span: {ins}")
        if bad:
            w(f"    FAILURES: {bad[:10]}")
        # the negative control: publish only `d` values per round
        s = max(slots, key=lambda s: s["degree"])
        nv, dg = s["main_rounds"] + s["extension_rounds"], s["degree"]
        rng = random.Random(5)
        rho = [rand_f2(rng) for _ in range(nv)]
        k_full, _ = cfs_check(nv, dg, rho, dg + 1)
        k_short, _ = cfs_check(nv, dg, rho, dg)
        w(f"    negative control, slot {s['slot']} (N={nv}, d={dg}): "
          f"d+1 values per round -> dim_Fp2 ker R {k_full//2}; "
          f"only d -> {k_short//2}")
    text = "\n".join(out) + "\n"
    sys.stdout.write(text)
    with open(os.path.join(HERE, "channels_shaped.txt"), "w") as fh:
        fh.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
