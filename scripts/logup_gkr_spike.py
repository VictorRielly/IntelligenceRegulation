#!/usr/bin/env python3
"""M4 LogUp-GKR spike: machine checks for the lookup-argument design round.

Companion to docs/zkmatrix-poc/M4_LOOKUP_DESIGN.md (the design round this
spike validates) and docs/zkmatrix-poc/M4_LOOKUP_LITERATURE.md (the verdict
it implements: LogUp, Habock ePrint 2022/1530, proven with the
Papini-Habock GKR fractional sumcheck, ePrint 2023/1284, as a fused-pair
lookup). Style follows scripts/zk_lemma_check.py: pure stdlib, exact
arithmetic, one OK line per machine-checked claim, negative demonstrations
for every ordering edge (F5 pairs: the attack ACCEPTS under the wrong
order, the shipped order REJECTS the same crafting).

Checks, in order (every OK line asserts):
  1. The log-derivative multiset identity with multiplicities over an
     explicitly implemented extension field GF(q^e) (polynomial quotient
     ring F_q[Y]/(Y^e - c)); honest witness passes, an out-of-table
     value fails.
  2. The fused-pair reduction (x, y) -> x + kappa*y: honest pass; wrong-y
     caught; the kappa ordering edge BOTH directions (base-field kappa
     known first -> exact fused collision accepts; post-commit kappa
     rejects the same crafting); the extension-field sharpening (a kappa
     with any nonzero non-constant coordinate admits NO base-field
     collision even when fully known -> the deterministic kappa := Y
     fusion of the design doc); the alpha-before-m edge (crafted
     multiplicities accept at a known alpha, fresh alpha rejects).
  3. The layered fractional-sum GKR of Papini-Habock: projective
     (numerator, denominator) binary tree over N leaves, layer-by-layer
     sumcheck transcript down to leaf MLE claims, root cross-check
     against the table tree, leaf claims checked E4-style (public
     tensor-weight inner products); tampered-layer and wrong-y negatives.
  4. The characteristic ceiling at a TINY prime (q = 13): char copies of
     an out-of-table value vanish from the identity -> FALSE accept for
     every alpha; per-instance splitting removes the attack -> both
     sub-instances reject.
  5. The MLE-evaluation reduction (the E4 claim shape): MLE at a random
     extension point equals the public tensor-weight inner product, and
     decomposes into e base-field public-weight functionals (the
     ct-claim landing), with a tamper negative.

PROGRESS (updated as sections land, for rate-limit resilience):
  [x] GF(q^e) arithmetic (binomial quotient, e in {2,3}, no-root test)
  [x] Check 1: log-derivative identity + out-of-table negative
  [x] Check 2: fusion, kappa/alpha ordering edges, kappa := Y sharpening
  [x] Check 3: full GKR transcript + tamper negatives
  [x] Check 4: characteristic-ceiling attack + per-instance fix
  [x] Check 5: MLE / E4 claim shape + coordinate decomposition

Run from the repo root:  python3 scripts/logup_gkr_spike.py
"""

import random

# ---------------------------------------------------------------------------
# GF(q^e) as F_q[Y]/(Y^e - c), implemented explicitly (the design doc's
# "explicit tower" arm; the recommended GF(q^16) slot field has identical
# algebra with e = 16 and the binomial X^16 - eta^(2t+1) already in the
# engine's CRT layer). e is restricted to primes {2, 3} here so the
# no-root irreducibility test is complete (a reducible quadratic or cubic
# has a linear factor).


class GF:
    def __init__(self, q, e):
        assert e in (2, 3), "spike supports prime degrees 2 and 3"
        self.q, self.e = q, e
        powers = {pow(a, e, q) for a in range(q)}
        self.c = next(c for c in range(2, q) if c not in powers)
        self.zero = (0,) * e
        self.one = (1,) + (0,) * (e - 1)
        # Y, the generator: the deterministic fusion constant of the design.
        self.gen = (0, 1) + (0,) * (e - 2)

    def embed(self, a):
        return (a % self.q,) + (0,) * (self.e - 1)

    def add(self, a, b):
        return tuple((x + y) % self.q for x, y in zip(a, b))

    def sub(self, a, b):
        return tuple((x - y) % self.q for x, y in zip(a, b))

    def mul(self, a, b):
        e, q, c = self.e, self.q, self.c
        out = [0] * (2 * e - 1)
        for i, ai in enumerate(a):
            if ai:
                for j, bj in enumerate(b):
                    out[i + j] = (out[i + j] + ai * bj) % q
        for k in range(2 * e - 2, e - 1, -1):  # fold Y^k -> c * Y^(k-e)
            if out[k]:
                out[k - e] = (out[k - e] + out[k] * c) % q
                out[k] = 0
        return tuple(out[:e])

    def pow(self, a, n):
        acc, base = self.one, a
        while n:
            if n & 1:
                acc = self.mul(acc, base)
            base = self.mul(base, base)
            n >>= 1
        return acc

    def inv(self, a):
        assert a != self.zero, "inversion of zero"
        return self.pow(a, self.q ** self.e - 2)

    def rand(self, rng):
        return tuple(rng.randrange(self.q) for _ in range(self.e))

    def rand_nonbase(self, rng):
        """Random element with a nonzero non-constant coordinate (kappa
        drawn 'properly' from the extension, not from the base field)."""
        while True:
            a = self.rand(rng)
            if any(a[1:]):
                return a


def rand_alpha(F, rng, avoid):
    """Random alpha avoiding the poles in `avoid` (honest-completeness
    guard; the real protocol's failure probability is (N + T)/|K|)."""
    while True:
        a = F.rand(rng)
        if all(F.sub(a, v) != F.zero for v in avoid):
            return a


def logup_holds(F, wit_fused, tab_fused, mult, alpha):
    """sum_i 1/(alpha - w_i) == sum_j m_j/(alpha - t_j), all in GF(q^e).
    mult entries are field elements (the identity never range-checks
    them — that fact IS the characteristic ceiling, check 4)."""
    lhs = F.zero
    for w in wit_fused:
        lhs = F.add(lhs, F.inv(F.sub(alpha, w)))
    rhs = F.zero
    for m, t in zip(mult, tab_fused):
        rhs = F.add(rhs, F.mul(m, F.inv(F.sub(alpha, t))))
    return lhs == rhs


def fuse(F, x, y, kappa):
    return F.add(F.embed(x), F.mul(kappa, F.embed(y)))


def histogram(xs, table_v):
    idx = {v: j for j, v in enumerate(table_v)}
    m = [0] * len(table_v)
    for x in xs:
        m[idx[x]] += 1
    return m


# ---------------------------------------------------------------------------
# Check 1: the log-derivative multiset identity with multiplicities.


def check_1():
    F = GF(97, 3)  # |K| = 97^3 = 912,673 ~ 2^19.8
    rng = random.Random(41)
    T, N = 16, 128
    table = [3 * j + 1 for j in range(T)]  # distinct base-field values
    wit = [table[rng.randrange(T)] for _ in range(N)]
    m = [F.embed(c) for c in histogram(wit, table)]
    wf = [F.embed(w) for w in wit]
    tf = [F.embed(t) for t in table]
    alpha = rand_alpha(F, rng, wf + tf)
    assert logup_holds(F, wf, tf, m, alpha), "honest LogUp identity FAILED"
    print(f"OK 1a: log-derivative identity with multiplicities holds "
          f"(GF(97^3), Y^3 - {F.c}, N={N}, T={T})")
    bad = list(wf)
    bad[0] = F.embed(wit[0] + 1)  # one value pushed out of the table
    for trial in range(3):
        a2 = rand_alpha(F, rng, bad + tf)
        assert not logup_holds(F, bad, tf, m, a2), \
            "out-of-table witness ACCEPTED"
    print("OK 1b: one out-of-table witness value rejected at 3 random alphas")


# ---------------------------------------------------------------------------
# Check 2: the fused-pair reduction and its ordering edges.


def check_2():
    F = GF(97, 3)
    q = F.q
    rng = random.Random(43)
    T, N = 16, 128
    table_v = list(range(T))
    table_y = [(5 * v * v + 3) % 89 for v in table_v]  # toy "SiLU" table
    xs = [table_v[rng.randrange(T)] for _ in range(N)]
    ys = [table_y[x] for x in xs]
    m = [F.embed(c) for c in histogram(xs, table_v)]

    def run(kappa, xs_, ys_, mult, alpha=None, rng_=None):
        wf = [fuse(F, x, y, kappa) for x, y in zip(xs_, ys_)]
        tf = [fuse(F, v, t, kappa) for v, t in zip(table_v, table_y)]
        if alpha is None:
            alpha = rand_alpha(F, rng_, wf + tf)
        return logup_holds(F, wf, tf, mult, alpha), alpha

    # 2a: honest fused pass, kappa drawn from the extension after commit.
    kappa = F.rand_nonbase(rng)
    ok, _ = run(kappa, xs, ys, m, rng_=rng)
    assert ok, "honest fused lookup FAILED"
    print("OK 2a: fused-pair lookup x + kappa*y passes on the honest witness")

    # 2b: wrong y at one element is caught for random kappa/alpha.
    ys_bad = list(ys)
    ys_bad[5] = (ys[5] + 1) % q
    for _ in range(3):
        ok, _ = run(kappa, xs, ys_bad, m, rng_=rng)
        assert not ok, "wrong y ACCEPTED under post-commit kappa"
    print("OK 2b: a wrong y at one element is rejected (3 random alphas)")

    # 2c: the kappa ordering edge, F5-pair. Direction 1 (the attack): a
    # BASE-FIELD kappa known before y is committed admits the exact
    # collision  y'_i = T[v'] + (v' - x_i) * kappa^{-1}: the fused value
    # lands exactly on table row v', so the multiset identity holds
    # IDENTICALLY (every alpha) with the shifted multiplicities.
    kappa0 = 7  # adversary knows this base-field fusion challenge first
    i_star, v_prime = 5, (xs[5] + 3) % T
    y_forged = (table_y[v_prime]
                + (v_prime - xs[i_star]) * pow(kappa0, q - 2, q)) % q
    assert y_forged != table_y[xs[i_star]], "degenerate forgery pick"
    ys_forged = list(ys)
    ys_forged[i_star] = y_forged
    m_forged = histogram(xs, table_v)
    m_forged[xs[i_star]] -= 1
    m_forged[v_prime] += 1
    m_forged = [F.embed(c) for c in m_forged]
    k0 = F.embed(kappa0)
    for _ in range(5):
        ok, _ = run(k0, xs, ys_forged, m_forged, rng_=rng)
        assert ok, "kappa-first collision should ACCEPT (the attack)"
    # Direction 2 (the shipped order): the SAME committed forgery against
    # a kappa drawn after commitment fails.
    for _ in range(3):
        k1 = F.rand_nonbase(rng)
        ok, _ = run(k1, xs, ys_forged, m_forged, rng_=rng)
        assert not ok, "post-commit kappa ACCEPTED the crafted y"
    print("OK 2c: kappa ordering edge (F5 pair): base-field kappa known "
          "first ACCEPTS the exact fused collision (5 alphas); a kappa "
          "drawn after commitment REJECTS the same crafting")

    # 2d: the sharpening that the design adopts. For kappa with ANY
    # nonzero non-constant coordinate, x + kappa*y' = v + kappa*T[v] over
    # base-field (x, y', v, T[v]) forces y' = T[v] and x = v: brute-force
    # over all q candidate y' and all T rows shows the ONLY solution is
    # the honest one — even with kappa fully known to the adversary.
    # Hence the deterministic fusion kappa := Y (F.gen) is exact.
    for kap in (F.rand_nonbase(rng), F.gen):
        tf = [fuse(F, v, t, kap) for v, t in zip(table_v, table_y)]
        sols = [(yp, j) for yp in range(q) for j in range(T)
                if fuse(F, xs[i_star], yp, kap) == tf[j]]
        assert sols == [(table_y[xs[i_star]], xs[i_star])], \
            f"unexpected fused collision {sols}"
    print("OK 2d: extension-field kappa admits NO base-field forgery even "
          "when known in advance (brute force over all y' and rows, "
          "random kappa AND kappa := Y) — the deterministic-fusion basis")

    # 2e: the alpha-before-m edge, F5-pair. Direction 1: with alpha known
    # first, the prover of a corrupted witness SOLVES for m_0 (one
    # equation, T unknowns — multiplicities are never range-checked):
    # m_0 = (LHS - sum_{j>=1} m_j/(alpha - t_j)) * (alpha - t_0).
    kappa = F.rand_nonbase(rng)
    wf_bad = [fuse(F, x, y, kappa) for x, y in zip(xs, ys_bad)]
    tf = [fuse(F, v, t, kappa) for v, t in zip(table_v, table_y)]
    alpha_known = rand_alpha(F, rng, wf_bad + tf)
    lhs = F.zero
    for w in wf_bad:
        lhs = F.add(lhs, F.inv(F.sub(alpha_known, w)))
    m_crafted = [F.embed(c) for c in histogram(xs, table_v)]
    rest = F.zero
    for mj, tj in zip(m_crafted[1:], tf[1:]):
        rest = F.add(rest, F.mul(mj, F.inv(F.sub(alpha_known, tj))))
    m_crafted[0] = F.mul(F.sub(lhs, rest), F.sub(alpha_known, tf[0]))
    assert logup_holds(F, wf_bad, tf, m_crafted, alpha_known), \
        "crafted-m at known alpha should ACCEPT (the attack)"
    # Direction 2: the same crafted m against a fresh alpha fails.
    for _ in range(3):
        a2 = rand_alpha(F, rng, wf_bad + tf)
        assert not logup_holds(F, wf_bad, tf, m_crafted, a2), \
            "crafted m survived a fresh alpha"
    print("OK 2e: alpha ordering edge (F5 pair): m crafted AFTER alpha "
          "ACCEPTS a corrupted witness; a fresh alpha REJECTS the same m")


# ---------------------------------------------------------------------------
# Check 3: the layered fractional-sum GKR (Papini-Habock projective
# accumulation), full transcript at toy scale.
#
# Conventions: vectors of length 2^k are MLE'd with variable 0 binding the
# LOW index bit; children of parent j are indices 2j (left) and 2j+1
# (right), so the child's variable 0 is the left/right selector. One
# layer transition proves, for parent point z in K^k and claims
# (Pz, Qz) = (p_k(z), q_k(z)):
#     p_k(z) = sum_b eq(z,b) [ p_(k+1)(0,b) q_(k+1)(1,b)
#                            + p_(k+1)(1,b) q_(k+1)(0,b) ]
#     q_k(z) = sum_b eq(z,b)   q_(k+1)(0,b) q_(k+1)(1,b)
# batched with a fresh lambda into ONE degree-3 sumcheck over b; the
# verifier folds the four end-of-sumcheck child values with a fresh mu
# into the next layer's claim at z' = (mu, r_1..r_k).


def tensor_weights(F, point):
    """L(point)[i] = prod_t (point_t if bit_t(i) else 1 - point_t) — the
    public tensor weight vector; eq(z, b) = L(z)[b]."""
    L = [F.one]
    for r in point:
        om = F.sub(F.one, r)
        # point[t] binds index bit t (little-endian, matching mle_eval's
        # fold order): the new bit is the HIGH bit of the doubled index.
        L = [F.mul(l, om) for l in L] + [F.mul(l, r) for l in L]
    return L


def mle_eval(F, vec, point):
    v = list(vec)
    for r in point:
        om = F.sub(F.one, r)
        v = [F.add(F.mul(v[2 * j], om), F.mul(v[2 * j + 1], r))
             for j in range(len(v) // 2)]
    return v[0]


def build_tree(F, p_leaves, q_leaves):
    p_layers, q_layers = [list(p_leaves)], [list(q_leaves)]
    while len(p_layers[0]) > 1:
        p, q = p_layers[0], q_layers[0]
        np_, nq_ = [], []
        for j in range(len(p) // 2):
            pL, pR, qL, qR = p[2 * j], p[2 * j + 1], q[2 * j], q[2 * j + 1]
            np_.append(F.add(F.mul(pL, qR), F.mul(pR, qL)))
            nq_.append(F.mul(qL, qR))
        p_layers.insert(0, np_)
        q_layers.insert(0, nq_)
    return p_layers, q_layers


def lagrange4(F, ys, r):
    """Cubic through (0..3, ys), evaluated at r."""
    xs = [F.embed(i) for i in range(4)]
    acc = F.zero
    for i in range(4):
        num, den = F.one, F.one
        for j in range(4):
            if j != i:
                num = F.mul(num, F.sub(r, xs[j]))
                den = F.mul(den, F.sub(xs[i], xs[j]))
        acc = F.add(acc, F.mul(ys[i], F.mul(num, F.inv(den))))
    return acc


def fold_at(F, tab, x):
    om = F.sub(F.one, x)
    return [F.add(F.mul(tab[2 * j], om), F.mul(tab[2 * j + 1], x))
            for j in range(len(tab) // 2)]


def gkr_run(F, rng, p_layers, q_layers):
    """Root-to-leaves fractional-GKR verification. The prover side is the
    layer tables; the verifier side is every arithmetic check below.
    Returns (ok, z, P_claim, Q_claim): the leaf-layer MLE claims at z."""
    Pz, Qz = p_layers[0][0], q_layers[0][0]
    z = []
    for k in range(len(p_layers) - 1):
        lam = F.rand(rng)
        C = F.add(Pz, F.mul(lam, Qz))
        cp, cq = p_layers[k + 1], q_layers[k + 1]
        pL, pR, qL, qR = cp[0::2], cp[1::2], cq[0::2], cq[1::2]
        eqt = tensor_weights(F, z)
        rs = []
        for _ in range(k):
            g = []
            for xv in range(4):
                x = F.embed(xv)
                e_, a_, b_, c_, d_ = (fold_at(F, t, x)
                                      for t in (eqt, pL, pR, qL, qR))
                s = F.zero
                for j in range(len(e_)):
                    term = F.add(F.add(F.mul(a_[j], d_[j]),
                                       F.mul(b_[j], c_[j])),
                                 F.mul(lam, F.mul(c_[j], d_[j])))
                    s = F.add(s, F.mul(e_[j], term))
                g.append(s)
            if F.add(g[0], g[1]) != C:  # the sumcheck round check
                return False, z, Pz, Qz
            r = F.rand(rng)
            C = lagrange4(F, g, r)
            eqt, pL, pR, qL, qR = (fold_at(F, t, r)
                                   for t in (eqt, pL, pR, qL, qR))
            rs.append(r)
        vp0, vp1, vq0, vq1 = pL[0], pR[0], qL[0], qR[0]
        eqz = F.one  # verifier recomputes eq(z, rs) directly
        for zt, rt in zip(z, rs):
            eqz = F.mul(eqz, F.add(F.mul(zt, rt),
                                   F.mul(F.sub(F.one, zt), F.sub(F.one, rt))))
        rhs = F.mul(eqz, F.add(F.add(F.mul(vp0, vq1), F.mul(vp1, vq0)),
                               F.mul(lam, F.mul(vq0, vq1))))
        if C != rhs:  # the end-of-sumcheck layer check
            return False, z, Pz, Qz
        mu = F.rand(rng)
        Pz = F.add(vp0, F.mul(mu, F.sub(vp1, vp0)))
        Qz = F.add(vq0, F.mul(mu, F.sub(vq1, vq0)))
        z = [mu] + rs
    return True, z, Pz, Qz


def check_3():
    F = GF(97, 3)
    rng = random.Random(47)
    T, N = 8, 64
    table_v = list(range(T))
    table_y = [(3 * v + 5) % 31 for v in table_v]
    xs = [table_v[rng.randrange(T)] for _ in range(N)]
    ys = [table_y[x] for x in xs]
    kappa = F.gen  # the deterministic fusion of OK-2d
    m = histogram(xs, table_v)
    wf = [fuse(F, x, y, kappa) for x, y in zip(xs, ys)]
    tf = [fuse(F, v, t, kappa) for v, t in zip(table_v, table_y)]
    alpha = rand_alpha(F, rng, wf + tf)

    # Witness tree (p = 1, q = alpha - w_i) and table tree
    # (p = m_j, q = alpha - t_j).
    pw, qw = build_tree(F, [F.one] * N, [F.sub(alpha, w) for w in wf])
    pt, qt = build_tree(F, [F.embed(c) for c in m],
                        [F.sub(alpha, t) for t in tf])

    # 3a: projective accumulation equals the direct fractional sum.
    direct = F.zero
    for w in wf:
        direct = F.add(direct, F.inv(F.sub(alpha, w)))
    assert F.mul(pw[0][0], F.inv(qw[0][0])) == direct, \
        "projective root != direct fractional sum"
    print(f"OK 3a: projective (p,q) tree root equals the direct fractional "
          f"sum (N={N} leaves, depth {len(pw) - 1})")

    # 3b: the full transcript. Root cross-check P_w Q_t == P_t Q_w, then
    # both GKR descents, then the leaf claims checked E4-style.
    assert qw[0][0] != F.zero and qt[0][0] != F.zero
    assert F.mul(pw[0][0], qt[0][0]) == F.mul(pt[0][0], qw[0][0]), \
        "root cross-check FAILED on honest data"
    ok, zw, Pw, Qw = gkr_run(F, rng, pw, qw)
    assert ok, "witness-tree GKR rejected an honest prover"
    ok, zt, Pt, Qt = gkr_run(F, rng, pt, qt)
    assert ok, "table-tree GKR rejected an honest prover"
    # Leaf checks, witness side: P = MLE of all-ones = 1;
    # Q = alpha - (MLE(x)(z) + kappa * MLE(y)(z)) with the two tensor
    # MLEs computed as PUBLIC-WEIGHT INNER PRODUCTS — the E4 claim shape.
    Lw = tensor_weights(F, zw)
    mle_x = F.zero
    mle_y = F.zero
    for Li, x, y in zip(Lw, xs, ys):
        mle_x = F.add(mle_x, F.mul(Li, F.embed(x)))
        mle_y = F.add(mle_y, F.mul(Li, F.embed(y)))
    assert Pw == F.one, "witness-tree numerator leaf claim != 1"
    assert Qw == F.sub(alpha, F.add(mle_x, F.mul(kappa, mle_y))), \
        "witness-tree denominator leaf claim mismatch"
    # Leaf checks, table side: P = MLE(m)(z_t) as a weight inner product
    # (the multiplicity column's E4 claim); Q = alpha - MLE(fused table),
    # verifier-computable from the public table.
    Lt = tensor_weights(F, zt)
    mle_m = F.zero
    for Li, mj in zip(Lt, m):
        mle_m = F.add(mle_m, F.mul(Li, F.embed(mj)))
    assert Pt == mle_m, "table-tree multiplicity leaf claim mismatch"
    assert Qt == F.sub(alpha, mle_eval(F, tf, zt)), \
        "table-tree denominator leaf claim mismatch"
    print("OK 3b: full layered GKR transcript verifies: root cross-check, "
          "both descents, leaf MLE claims = public-weight inner products "
          "(the E4 shape) for x, y, and the multiplicity column")

    # 3c: tampered interior layer (one node of layer 2 shifted, ancestors
    # left honest): the layer-2 sumcheck's very first round equation
    # g(0) + g(1) = C breaks.
    pw2 = [list(layer) for layer in pw]
    pw2[2][1] = F.add(pw2[2][1], F.one)
    ok, _, _, _ = gkr_run(F, rng, pw2, qw)
    assert not ok, "tampered layer value ACCEPTED"
    print("OK 3c: a tampered interior layer value is rejected by the "
          "layer sumcheck (round-sum mismatch)")

    # 3d: wrong y through the FULL protocol: both trees are internally
    # consistent (each descent passes), but the root cross-check — the
    # log-derivative identity itself — fails.
    ys_bad = list(ys)
    ys_bad[7] = ys[7] + 1
    wf_bad = [fuse(F, x, y, kappa) for x, y in zip(xs, ys_bad)]
    alpha2 = rand_alpha(F, rng, wf_bad + tf)
    pwb, qwb = build_tree(F, [F.one] * N, [F.sub(alpha2, w) for w in wf_bad])
    ptb, qtb = build_tree(F, [F.embed(c) for c in m],
                          [F.sub(alpha2, t) for t in tf])
    ok, _, _, _ = gkr_run(F, rng, pwb, qwb)
    assert ok, "internally consistent tree should pass its own descent"
    assert F.mul(pwb[0][0], qtb[0][0]) != F.mul(ptb[0][0], qwb[0][0]), \
        "wrong y survived the root cross-check"
    print("OK 3d: wrong y at one leaf passes its own (consistent) descent "
          "but is rejected by the root cross-check — semantic soundness "
          "lives in the alpha-identity, as designed")


# ---------------------------------------------------------------------------
# Check 4: the characteristic ceiling, attack and fix, at q = 13.


def check_4():
    q0 = 13
    F = GF(q0, 3)  # |K| = 2197; char(K) = 13 regardless of extension
    rng = random.Random(53)
    T = 8
    table = list(range(T))
    u = 11  # NOT in the table
    # N = 16 >= char: 13 copies of u plus 3 honest values.
    wit = [u] * q0 + [2, 5, 7]
    m_attack = [F.embed(c) for c in histogram([2, 5, 7], table)]
    wf = [F.embed(w) for w in wit]
    tf = [F.embed(t) for t in table]
    # The attack: 13 * 1/(alpha - u) = 0 in characteristic 13, so the
    # identity holds IDENTICALLY — for every alpha — with zero
    # multiplicity charged to u. A false accept at the identity level.
    for _ in range(5):
        a = rand_alpha(F, rng, wf + tf)
        assert logup_holds(F, wf, tf, m_attack, a), \
            "ceiling attack should ACCEPT (char copies vanish)"
    print(f"OK 4a: characteristic ceiling attack: N=16 >= char={q0}, "
          f"13 copies of out-of-table value {u} vanish from the identity "
          f"-> FALSE accept at 5 random alphas (extension size "
          f"{q0 ** 3} does not help; the ceiling is the CHARACTERISTIC)")
    # The fix: per-instance splitting. Two instances of 8; the copy
    # counts (8 and 5) are nonzero mod 13, so each instance's identity
    # fails for random alpha.
    inst_a, inst_b = wit[:8], wit[8:]
    m_a = [F.embed(0)] * T  # no honest members in instance A
    m_b = [F.embed(c) for c in histogram([2, 5, 7], table)]
    for _ in range(3):
        a = rand_alpha(F, rng, wf + tf)
        assert not logup_holds(F, [F.embed(w) for w in inst_a], tf, m_a, a), \
            "split instance A accepted the ceiling attack"
        assert not logup_holds(F, [F.embed(w) for w in inst_b], tf, m_b, a), \
            "split instance B accepted the ceiling attack"
    print("OK 4b: per-instance splitting (8 + 8 < char each) REJECTS both "
          "sub-instances — the fix the design bakes in as per-layer "
          "table instancing")


# ---------------------------------------------------------------------------
# Check 5: the MLE-evaluation reduction — the E4 claim shape.


def check_5():
    F = GF(97, 3)
    rng = random.Random(59)
    N = 64
    xs = [rng.randrange(F.q) for _ in range(N)]
    r = [F.rand(rng) for _ in range(6)]  # log2(64) variables
    v = mle_eval(F, [F.embed(x) for x in xs], r)
    L = tensor_weights(F, r)
    ip = F.zero
    for Li, x in zip(L, xs):
        ip = F.add(ip, F.mul(Li, F.embed(x)))
    assert ip == v, "tensor-weight inner product != MLE evaluation"
    print(f"OK 5a: MLE(x)(r) equals the public tensor-weight inner product "
          f"<L(r), x> (N={N}) — the E4 claim is a public-weight linear "
          f"functional of the committed column")
    # Coordinate decomposition: x is base-field, so coordinate c of v is
    # a BASE-FIELD public-weight functional sum_i (L_i)_c * x_i — exactly
    # e linear ct-claims through pack_functional.
    for c in range(F.e):
        s = sum(L[i][c] * xs[i] for i in range(N)) % F.q
        assert s == v[c], f"coordinate {c} functional mismatch"
    print(f"OK 5b: v decomposes into e={F.e} base-field public-weight "
          f"functionals (the ct-claim landing; e=16 in the slot field)")
    xs_bad = list(xs)
    xs_bad[3] = (xs[3] + 1) % F.q
    ip_bad = F.zero
    for Li, x in zip(L, xs_bad):
        ip_bad = F.add(ip_bad, F.mul(Li, F.embed(x)))
    assert ip_bad != v, "tampered witness matched the pinned value"
    print("OK 5c: a tampered witness coefficient breaks the pinned "
          "functional value (binding through the weights)")


if __name__ == "__main__":
    check_1()
    check_2()
    check_3()
    check_4()
    check_5()
    print("all logup_gkr_spike assertions passed")
