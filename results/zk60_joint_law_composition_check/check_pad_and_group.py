#!/usr/bin/env python3
"""Three linear-algebra facts the check needs and the draft takes on trust.

(a) M-cols: M's pad block.  M's a-rows are ordinary interpolants on G_m of
    (L coefficients || Q pads || zeros) evaluated on a coset of G_nn
    (hashline/src/zk.rs:437-448).  The pad block at the sampled coset points
    is [ Lagrange_{L+k}(x_j) ].  Lagrange_t(x) = w^t (x^m - 1) / (m (x - w^t)),
    so the block is diag((x_j^m-1)/m) * Cauchy(x_j ; w^{t_k}) * diag(w^{t_k}):
    full rank min(d, Q) for distinct x_j off the subgroup.  Checked here.

(b) H-pad: the PCS pad block.  encode_row_zk (zkp-core/src/pcs.rs:618-637)
    puts the pads on Z_n(x) x^k, so the block is
    diag(x_j^n - 1) * Vandermonde(x_j): full rank min(d, Q).  Checked here.

(c) THE CHECK'S OWN LEMMA (attack 4/5): inside ONE opening group with m
    member claims, the observation (group vector's message half, the m
    individual published terminals) is a SURJECTION of the m reserved pairs'
    message rows onto the verifier's consistency subspace
    { (v, y_1..y_m) : <v, cw> = sum_c lambda_c y_c }.  So publishing the
    individual terminals adds nothing to the group vector beyond that one
    public identity -- which is what the generic-rank lemma's reduction
    (disclosed = 256 k0 + u-term, generators = the group and proximity
    combinations only) silently assumes.  Needs lambda_c != 0, cm_c != 0,
    cw != 0, all three refused-if-zero in the Rust.
"""

import random

P = (1 << 64) - (1 << 32) + 1  # the real Goldilocks prime (2-adic valuation 32)


def inv(a):
    return pow(a % P, P - 2, P)


def rank(rows, ncols):
    m = [[x % P for x in r] for r in rows]
    r = 0
    for c in range(ncols):
        piv = next((i for i in range(r, len(m)) if m[i][c]), None)
        if piv is None:
            continue
        m[r], m[piv] = m[piv], m[r]
        iv = inv(m[r][c])
        m[r] = [(x * iv) % P for x in m[r]]
        for i in range(len(m)):
            if i != r and m[i][c]:
                f = m[i][c]
                m[i] = [(a - f * b) % P for a, b in zip(m[i], m[r])]
        r += 1
        if r == len(m):
            break
    return r


def subgroup(order, rnd):
    """A multiplicative subgroup of order `order` in F_P, and a generator."""
    assert (P - 1) % order == 0
    while True:
        h = rnd.randrange(2, P)
        g = pow(h, (P - 1) // order, P)
        if pow(g, order // 2, P) != 1:
            return g


def main():
    rnd = random.Random(31337)
    out = []

    # ---- (a) M's Lagrange pad block -------------------------------------
    m, nn, Q, Lc = 32, 256, 16, 6          # scaled-down (real: 512, 4096, 256, <=50)
    w = subgroup(m, rnd)
    coset = subgroup(nn, rnd)
    shift = 7
    nodes = [pow(w, t, P) for t in range(m)]
    for d in (Q - 3, Q, Q + 4):
        js = rnd.sample(range(nn), d)
        xs = [shift * pow(coset, j, P) % P for j in js]
        # Lagrange_t(x) = prod_{s != t} (x - node_s)/(node_t - node_s)
        blk = []
        for x in xs:
            row = []
            for k in range(Q):
                t = Lc + k
                num, den = 1, 1
                for s in range(m):
                    if s != t:
                        num = num * (x - nodes[s]) % P
                        den = den * (nodes[t] - nodes[s]) % P
                row.append(num * inv(den) % P)
            blk.append(row)
        out.append(f"(a) M pad block: {d} distinct coset points x {Q} pads -> rank {rank(blk, Q)} "
                   f"(expected min(d,Q) = {min(d, Q)})")

    # ---- (b) the PCS pad block ------------------------------------------
    n, nn2, Q2 = 32, 256, 16
    coset2 = subgroup(nn2, rnd)
    for d in (Q2 - 3, Q2, Q2 + 4):
        js = rnd.sample(range(nn2), d)
        xs = [shift * pow(coset2, j, P) % P for j in js]
        blk = [[(pow(x, n, P) - 1) * pow(x, k, P) % P for k in range(Q2)] for x in xs]
        out.append(f"(b) PCS pad block: {d} distinct coset points x {Q2} pads -> rank {rank(blk, Q2)} "
                   f"(expected min(d,Q) = {min(d, Q2)})")

    # ---- (c) the group / terminal surjection ----------------------------
    # unknowns: m pairs P_c in Fp^{2 ncol} (the two reserved rows' messages),
    # entering the group vector as lambda_c cm_c (P_c,re + U P_c,im) and the
    # terminal as cm_c <P_c, cw>.  Everything is done over Fp with a formal
    # U^2 = 7 so the arithmetic matches Fp2 = Fp[U]/(U^2-7).
    def mul2(a, b):
        return ((a[0] * b[0] + 7 * a[1] * b[1]) % P, (a[0] * b[1] + a[1] * b[0]) % P)

    ncol = 5
    for mem in (1, 2, 4):
        lam = [(rnd.randrange(1, P), rnd.randrange(1, P)) for _ in range(mem)]
        cm = [(rnd.randrange(1, P), rnd.randrange(1, P)) for _ in range(mem)]
        cw = [(rnd.randrange(1, P), rnd.randrange(1, P)) for _ in range(ncol)]
        # unknown vector: for each claim c, two Fp rows of ncol entries each
        nun = mem * 2 * ncol
        rows = []          # each observation as an Fp functional (re and im parts)
        # group vector's message half: ncol Fp2 entries -> 2 ncol Fp functionals
        for t in range(ncol):
            for part in (0, 1):
                f = [0] * nun
                for c in range(mem):
                    k = mul2(lam[c], cm[c])
                    # contribution k * (row_re[t] + U row_im[t])
                    base = c * 2 * ncol
                    f[base + t] = (f[base + t] + (k[0] if part == 0 else k[1])) % P
                    ku = mul2(k, (0, 1))
                    f[base + ncol + t] = (f[base + ncol + t] + (ku[0] if part == 0 else ku[1])) % P
                rows.append(f)
        # the m terminals: cm_c * <P_c, cw>
        for c in range(mem):
            for part in (0, 1):
                f = [0] * nun
                base = c * 2 * ncol
                for t in range(ncol):
                    k = mul2(cm[c], cw[t])
                    f[base + t] = (f[base + t] + (k[0] if part == 0 else k[1])) % P
                    ku = mul2(k, (0, 1))
                    f[base + ncol + t] = (f[base + ncol + t] + (ku[0] if part == 0 else ku[1])) % P
                rows.append(f)
        r = rank(rows, nun)
        expect = 2 * ncol + 2 * mem - 2          # one Fp2 = 2 Fp dependency
        out.append(f"(c) group with {mem} member claim(s), {ncol} columns: rank of the blinding map "
                   f"= {r}, observations {2*ncol + 2*mem}, expected {expect} "
                   f"(= all but the one public identity <v,cw> = sum lambda_c y_c)")
        # control: one cm zero (what audit_claims:103-108 refuses)
        cm0 = list(cm)
        cm0[0] = (0, 0)
        rows0 = []
        for t in range(ncol):
            for part in (0, 1):
                f = [0] * nun
                for c in range(mem):
                    k = mul2(lam[c], cm0[c])
                    base = c * 2 * ncol
                    f[base + t] = (f[base + t] + (k[0] if part == 0 else k[1])) % P
                    ku = mul2(k, (0, 1))
                    f[base + ncol + t] = (f[base + ncol + t] + (ku[0] if part == 0 else ku[1])) % P
                rows0.append(f)
        for c in range(mem):
            for part in (0, 1):
                f = [0] * nun
                base = c * 2 * ncol
                for t in range(ncol):
                    k = mul2(cm0[c], cw[t])
                    f[base + t] = (f[base + t] + (k[0] if part == 0 else k[1])) % P
                    ku = mul2(k, (0, 1))
                    f[base + ncol + t] = (f[base + ncol + t] + (ku[0] if part == 0 else ku[1])) % P
                rows0.append(f)
        out.append(f"    CONTROL cm_0 = 0: rank {rank(rows0, nun)} (drops => that claim's terminal and "
                   f"its share of the group vector are no longer blinded)")
    print("\n".join(out))


if __name__ == "__main__":
    main()
