#!/usr/bin/env python3
"""U-AG2 O-3 claim-reduction spike (Agent DB lane, 2026-07-27).

Numerically verifies the key reductions of
docs/zkmatrix-poc/AGGREGATION_CLAIM_REDUCTION.md at toy shape.
This checks ALGEBRA, not security: toy rings/moduli, base-field
"soundness" points, deterministic FS-style challenges. Certificates
(names match the document):

  SPK-1  CR-L1 power-point lemma (tensor weights = shifted MLE eval),
         at the real q31 and at the toy field.
  SPK-2  CR-L2 slot-evaluation lemma at a toy negacyclic ring
         Z_97[X]/(X^8+1): evaluation is a ring hom, Galois twists
         move the PUBLIC point (ev_w(sigma_t x) = ev_{w^t} x), ring
         claims hold iff all root-evaluations hold, and a full toy
         conj-twisted quadratic claim (the committed-executions
         gate's claim form) accepts honest / rejects tampered under
         the root-RLC batch.
  SPK-3  CR-1/CR-L3 matmul sumcheck (the gate's replacement): a real
         toy sumcheck prover/verifier over F_q31, honest C accepts,
         tampered C rejects.
  SPK-4  CR-3/CR-4/CR-L6 zero-checks: Hadamard z = x*y (degree 3)
         and binariness b(b-1) = 0, honest accept / one-position
         tamper reject.
  SPK-5  CR-9 cross-modulus link reduction: integer-exactness logic
         at two toy moduli (honest equal, tampered value caught by
         the xi rows), and the reduced form — the mu-batched
         slice-sumcheck over a toy global tensor with the verifier
         evaluating the dense-xi kernel at the terminal — honest
         accept / tampered slice value reject.
  SPK-6  CR-5/CR-8: (a) K-coordinate decomposition of pinned values
         at toy GF(97^2) (k_weight_coords pattern) + RLC-batch
         tamper; (b) packing-image identity (the zeta dissolution's
         fallback): honest packed tensor passes, junk-bearing
         tensor fails.
  SPK-7  CR-L4a multi-point -> one-point batch: two evaluation
         claims batched into one sumcheck, honest accept / tampered
         claimed value reject.

Stdlib only. Deterministic (SHA-256 transcript). Runs in < 1 s.
"""

import hashlib
import sys

Q31 = 2**31 - 399  # the real protocol modulus (used as a toy FIELD here)
P = 97             # toy base field for the ring/extension legs
RESULTS = []


def check(name, ok):
    RESULTS.append((name, bool(ok)))
    print(("  OK  " if ok else "  FAIL") + " " + name)


# --------------------------------------------------------------------------
# Transcript (deterministic FS-style challenges).

class Transcript:
    def __init__(self, label):
        self.h = hashlib.sha256(label.encode())

    def absorb(self, *ints):
        for v in ints:
            self.h.update(int(v).to_bytes(16, "little", signed=True))

    def challenge(self, p):
        out = int.from_bytes(self.h.digest(), "little") % p
        self.h.update(b"next")
        return out


# --------------------------------------------------------------------------
# Multilinear toolkit over F_p. Tables are lists of length 2^n; bit j of
# the index is variable j (variable 0 folded first).

def inv(x, p):
    return pow(x % p, p - 2, p)


def mle_eval(table, point, p):
    cur = list(table)
    for z in point:
        cur = [(cur[2 * i] * (1 - z) + cur[2 * i + 1] * z) % p
               for i in range(len(cur) // 2)]
    return cur[0]


def eq_weight(z, bits, p):
    w = 1
    for zj, bj in zip(z, bits):
        w = w * ((zj if bj else (1 - zj)) % p) % p
    return w


def eq_table(z, p):
    n = len(z)
    return [eq_weight(z, [(i >> j) & 1 for j in range(n)], p)
            for i in range(2**n)]


def lagrange_eval(evals, x, p):
    # evals = g(0..d); evaluate g at x.
    d = len(evals) - 1
    acc = 0
    for i, yi in enumerate(evals):
        num, den = 1, 1
        for j in range(d + 1):
            if j != i:
                num = num * ((x - j) % p) % p
                den = den * ((i - j) % p) % p
        acc = (acc + yi * num * inv(den, p)) % p
    return acc


def sumcheck(terms, claim, p, tr):
    """terms: list of (coeff, [table, ...]); proves
    sum_b sum_terms coeff * prod tables == claim. Returns
    (rounds_ok, point, terminal_values) where terminal_values[t][f]
    is factor f of term t fully folded. A dishonest (claim, tables)
    pair fails a round check (rounds_ok False)."""
    tabs = [[list(t) for t in fs] for (_, fs) in terms]
    coefs = [c % p for (c, _) in terms]
    n = (len(tabs[0][0])).bit_length() - 1
    deg = max(len(fs) for fs in tabs)
    point = []
    for _ in range(n):
        evals = []
        for t in range(deg + 1):
            acc = 0
            for c, fs in zip(coefs, tabs):
                half = len(fs[0]) // 2
                for i in range(half):
                    prod = c
                    for f in fs:
                        prod = prod * ((f[2 * i] * (1 - t) + f[2 * i + 1] * t) % p) % p
                    acc = (acc + prod) % p
            evals.append(acc)
        if (evals[0] + evals[1] - claim) % p != 0:
            return False, point, None
        tr.absorb(*evals)
        r = tr.challenge(p)
        point.append(r)
        claim = lagrange_eval(evals, r, p)
        tabs = [[[(f[2 * i] * (1 - r) + f[2 * i + 1] * r) % p
                  for i in range(len(f) // 2)] for f in fs] for fs in tabs]
    term_vals = [[f[0] for f in fs] for fs in tabs]
    final = 0
    for c, vs in zip(coefs, term_vals):
        prod = c
        for v in vs:
            prod = prod * v % p
        final = (final + prod) % p
    return (final - claim) % p == 0, point, term_vals


def rng_stream(label, p, count):
    out, i = [], 0
    while len(out) < count:
        h = hashlib.sha256(f"{label}:{i}".encode()).digest()
        out.append(int.from_bytes(h, "little") % p)
        i += 1
    return out


# --------------------------------------------------------------------------
# SPK-1 — CR-L1 power-point lemma.

def spk1():
    for (p, tag) in [(Q31, "q31"), (P, "p97")]:
        n = 4
        x = rng_stream(f"spk1-x-{tag}", p, 2**n)
        c = [v % p for v in rng_stream(f"spk1-c-{tag}", p - 2, n)]  # avoid -1
        c = [(v + 2) % p for v in c]
        c = [v if v != p - 1 else 1 for v in c]
        lhs = 0
        for i, xi in enumerate(x):
            w = 1
            for j in range(n):
                if (i >> j) & 1:
                    w = w * c[j] % p
            lhs = (lhs + w * xi) % p
        z = [c[j] * inv(1 + c[j], p) % p for j in range(n)]
        scale = 1
        for j in range(n):
            scale = scale * (1 + c[j]) % p
        rhs = scale * mle_eval(x, z, p) % p
        check(f"SPK-1 power-point lemma at {tag}", lhs == rhs)


# --------------------------------------------------------------------------
# SPK-2 — CR-L2 at the toy ring Z_97[X]/(X^8+1).

DTOY = 8


def ring_mul(a, b, p):
    out = [0] * DTOY
    for i, ai in enumerate(a):
        if ai == 0:
            continue
        for j, bj in enumerate(b):
            e = i + j
            s = 1
            if e >= DTOY:
                e -= DTOY
                s = -1
            out[e] = (out[e] + s * ai * bj) % p
    return out


def sigma_t(x, t):
    out = [0] * DTOY
    for i, xi in enumerate(x):
        e = (t * i) % (2 * DTOY)
        if e >= DTOY:
            out[e - DTOY] = (out[e - DTOY] - xi) % P
        else:
            out[e] = (out[e] + xi) % P
    return out


def ev(x, w, p):
    acc, wp = 0, 1
    for xi in x:
        acc = (acc + xi * wp) % p
        wp = wp * w % p
    return acc


def spk2():
    # find omega of order 2*DTOY = 16 in Z_97.
    g = next(gc for gc in range(2, P)
             if all(pow(gc, (P - 1) // f, P) != 1 for f in (2, 3)))
    omega = pow(g, (P - 1) // (2 * DTOY), P)
    check("SPK-2 omega has order 2D (omega^D = -1)",
          pow(omega, DTOY, P) == P - 1)
    a = rng_stream("spk2-a", P, DTOY)
    b = rng_stream("spk2-b", P, DTOY)
    check("SPK-2 evaluation is a ring homomorphism",
          ev(ring_mul(a, b, P), omega, P) == ev(a, omega, P) * ev(b, omega, P) % P)
    ok_twist = all(
        ev(sigma_t(a, t), omega, P) == ev(a, pow(omega, t, P), P)
        for t in range(1, 2 * DTOY, 2))
    check("SPK-2 twist law ev_w(sigma_t x) = ev_(w^t)(x), all odd t", ok_twist)
    conj = sigma_t(a, 2 * DTOY - 1)
    check("SPK-2 conj law ev_w(conj x) = ev_(w^-1)(x)",
          ev(conj, omega, P) == ev(a, inv(omega, P), P))
    # Full toy conj-twisted quadratic claim (the gate's claim form):
    #   gamma * conj(x_a) * x_b - x_3 = 0 with x_3 committed honest.
    gamma = rng_stream("spk2-g", P, DTOY)
    x3 = ring_mul(gamma, ring_mul(sigma_t(a, 2 * DTOY - 1), b, P), P)
    roots = [pow(omega, t, P) for t in range(1, 2 * DTOY, 2)]
    lam = rng_stream("spk2-lam", P, len(roots))

    def batched_defect(x3v):
        acc = 0
        for lr, w in zip(lam, roots):
            ident = (ev(gamma, w, P) * ev(a, inv(w, P), P) % P * ev(b, w, P)
                     - ev(x3v, w, P)) % P
            acc = (acc + lr * ident) % P
        return acc

    check("SPK-2 twisted-quad claim: honest root-RLC batch = 0",
          batched_defect(x3) == 0)
    x3_bad = list(x3)
    x3_bad[3] = (x3_bad[3] + 1) % P
    check("SPK-2 twisted-quad claim: tampered witness REJECTED",
          batched_defect(x3_bad) != 0)


# --------------------------------------------------------------------------
# SPK-3 — CR-1/CR-L3 matmul sumcheck (the gate's replacement).

def spk3():
    p = Q31
    lr, li, lm = 2, 3, 2  # A: 4x8, B: 8x4, C: 4x4
    A = rng_stream("spk3-A", p, 2**(lr + li))   # index = row_bits | inner_bits
    B = rng_stream("spk3-B", p, 2**(li + lm))   # index = inner_bits | col_bits
    C = [0] * 2**(lr + lm)
    for r in range(2**lr):
        for c in range(2**lm):
            acc = 0
            for u in range(2**li):
                acc = (acc + A[r + (u << lr)] * B[u + (c << li)]) % p
            C[r + (c << lr)] = acc

    def run(c_table):
        tr = Transcript("spk3")
        tr.absorb(*A, *B, *c_table)
        rx = [tr.challenge(p) for _ in range(lr)]
        ry = [tr.challenge(p) for _ in range(lm)]
        # fold A at rx (row vars are the LOW bits of A's index).
        a_fold = list(A)
        for z in rx:
            a_fold = [(a_fold[2 * i] * (1 - z) + a_fold[2 * i + 1] * z) % p
                      for i in range(len(a_fold) // 2)]
        # fold B at ry (col vars are the HIGH bits): fold from the top.
        b_fold = list(B)
        for z in reversed(ry):
            half = len(b_fold) // 2
            b_fold = [(b_fold[i] * (1 - z) + b_fold[i + half] * z) % p
                      for i in range(half)]
        claim = mle_eval(c_table, rx + ry, p)
        ok, _, _ = sumcheck([(1, [a_fold, b_fold])], claim, p, tr)
        return ok

    check("SPK-3 matmul sumcheck: honest C ACCEPTS", run(C))
    C_bad = list(C)
    C_bad[5] = (C_bad[5] + 1) % p
    check("SPK-3 matmul sumcheck: tampered C REJECTS", not run(C_bad))


# --------------------------------------------------------------------------
# SPK-4 — CR-3/CR-4/CR-L6 zero-checks.

def spk4():
    p = Q31
    n = 4
    X = rng_stream("spk4-x", p, 2**n)
    Y = rng_stream("spk4-y", p, 2**n)
    Z = [x * y % p for x, y in zip(X, Y)]

    def run_had(z_table):
        tr = Transcript("spk4-had")
        tr.absorb(*X, *Y, *z_table)
        r = [tr.challenge(p) for _ in range(n)]
        eqt = eq_table(r, p)
        ok, _, _ = sumcheck(
            [(1, [eqt, X, Y]), (-1, [eqt, z_table])], 0, p, tr)
        return ok

    check("SPK-4 Hadamard zero-check: honest ACCEPTS", run_had(Z))
    Z_bad = list(Z)
    Z_bad[7] = (Z_bad[7] + 1) % p
    check("SPK-4 Hadamard zero-check: one-position tamper REJECTS",
          not run_had(Z_bad))

    Bv = [v % 2 for v in rng_stream("spk4-b", p, 2**n)]

    def run_bin(b_table):
        tr = Transcript("spk4-bin")
        tr.absorb(*b_table)
        r = [tr.challenge(p) for _ in range(n)]
        eqt = eq_table(r, p)
        ok, _, _ = sumcheck(
            [(1, [eqt, b_table, b_table]), (-1, [eqt, b_table])], 0, p, tr)
        return ok

    check("SPK-4 binariness zero-check: honest ACCEPTS", run_bin(Bv))
    B_bad = list(Bv)
    B_bad[2] = 5
    check("SPK-4 binariness zero-check: non-binary REJECTS",
          not run_bin(B_bad))


# --------------------------------------------------------------------------
# SPK-5 — CR-9 cross-modulus link reduction.

def spk5():
    # The real modulus pair (q31, q46 = 2^46 - 1103, `Q8_46`): "toy" here
    # means n = 8 values, not a toy field — an early draft used p = 97 for
    # the target side and the tamper leg hit an accidental zero of the
    # mu-xi combination mod 97 (prob ~1/97 per draw), a live demonstration
    # of why the production sumcheck field is GF(q^16) ~ 2^496.
    p_gnd, p_tgt = 2**46 - 1103, Q31
    n_vals, w_planes, l_rows, wbits = 8, 2, 8, 4
    vals = [v % (2**w_planes) for v in rng_stream("spk5-v", 4, n_vals)]
    bits = [[(v >> i) & 1 for v in vals] for i in range(w_planes)]
    half = 2**(wbits - 1)
    xi = [[(v % 2**wbits) - half
           for v in rng_stream(f"spk5-xi{r}", 2**wbits, n_vals)]
          for r in range(l_rows)]
    y = [sum(a * b for a, b in zip(row, vals)) for row in xi]
    check("SPK-5 link: honest y inside the grounding gate",
          all(abs(v) < p_gnd // 2 for v in y))
    gnd_ok = all(
        sum((xi[r][t] << i) * bits[i][t]
            for i in range(w_planes) for t in range(n_vals)) % p_gnd
        == y[r] % p_gnd for r in range(l_rows))
    tgt_ok = all(
        sum(xi[r][t] * vals[t] for t in range(n_vals)) % p_tgt
        == y[r] % p_tgt for r in range(l_rows))
    check("SPK-5 link: both residue sides match the revealed integers",
          gnd_ok and tgt_ok)
    vals_bad = list(vals)
    vals_bad[3] = (vals_bad[3] + 1) % p_tgt
    caught = any(
        sum(xi[r][t] * vals_bad[t] for t in range(n_vals)) % p_tgt
        != y[r] % p_tgt for r in range(l_rows))
    check("SPK-5 link: tampered value caught by an xi row", caught)

    # Reduced form: the values live in a 32-position global toy tensor at
    # slice u = 2 (positions 16..23); mu-batched slice sumcheck with the
    # verifier evaluating the dense-xi kernel at the terminal (CR-L5 +
    # CR-L4a; the O(l*n) kernel cost of Section 7.2).
    p = p_tgt
    V = rng_stream("spk5-V", p, 32)
    for t in range(n_vals):
        V[16 + t] = vals[t] % p

    def run(v_table):
        tr = Transcript("spk5-red")
        tr.absorb(*v_table)
        mu = [tr.challenge(p) for _ in range(l_rows)]
        W = [0] * 32
        for t in range(n_vals):
            W[16 + t] = sum(mu[r] * xi[r][t] for r in range(l_rows)) % p
        claim = sum(mu[r] * (y[r] % p) for r in range(l_rows)) % p
        ok, point, term = sumcheck([(1, [W, v_table])], claim, p, tr)
        if not ok:
            return False
        # verifier recomputes the kernel terminal from public xi (O(l*n)).
        return term[0][0] == mle_eval(W, point, p)

    check("SPK-5 reduced link: mu-batched slice sumcheck ACCEPTS", run(V))
    V_bad = list(V)
    V_bad[18] = (V_bad[18] + 1) % p
    check("SPK-5 reduced link: tampered slice value REJECTS", not run(V_bad))


# --------------------------------------------------------------------------
# SPK-6 — pin coordinate rows (a) and the packing-image identity (b).

def spk6():
    p = P
    # (a) toy K' = GF(97^2) = Z_97[Y]/(Y^2 - s), s a non-residue.
    s = next(c for c in range(2, p) if pow(c, (p - 1) // 2, p) == p - 1)

    def kmul(a, b):
        return ((a[0] * b[0] + s * a[1] * b[1]) % p,
                (a[0] * b[1] + a[1] * b[0]) % p)

    def kadd(a, b):
        return ((a[0] + b[0]) % p, (a[1] + b[1]) % p)

    kap = [(rng_stream(f"spk6-k{e}", p, 2)[0], rng_stream(f"spk6-k{e}", p, 2)[1])
           for e in range(3)]
    xs = [(rng_stream(f"spk6-x{e}", p, 2)[0], rng_stream(f"spk6-x{e}", p, 2)[1])
          for e in range(3)]
    direct = (0, 0)
    for ke, xe in zip(kap, xs):
        direct = kadd(direct, kmul(ke, xe))
    # coordinate rows: M(kappa)[c][j] = coord c of kappa * Y^j
    # (k_weight_coords, lookup.rs:226 — Y^1 wraps to (s*a1, a0)).
    rows = []
    for c in range(2):
        row = []
        for ke in kap:
            m = [[ke[0], s * ke[1] % p], [ke[1], ke[0]]]
            row.append(m[c])
        rows.append(row)
    coord = [sum(rw[e][j] * xs[e][j] for e in range(3) for j in range(2)) % p
             for rw in rows]
    check("SPK-6a pin coordinate rows match direct GF(p^2) arithmetic",
          tuple(coord) == direct)
    psi = rng_stream("spk6-psi", p, 2)
    batch = lambda cs: sum(ps * c for ps, c in zip(psi, cs)) % p
    xs_bad = [list(x) for x in xs]
    xs_bad[1][0] = (xs_bad[1][0] + 1) % p
    coord_bad = [sum(rw[e][j] * xs_bad[e][j] for e in range(3) for j in range(2)) % p
                 for rw in rows]
    check("SPK-6a psi-RLC pin batch: tampered element REJECTED",
          batch(coord) == batch(list(direct)) and batch(coord_bad) != batch(list(direct)))

    # (b) packing-image identity (CR-8 fallback): elements of 4 coeffs
    # packing 2 values via public basis vectors e_0, e_1.
    E = [rng_stream("spk6-e0", p, 4), rng_stream("spk6-e1", p, 4)]
    vv = rng_stream("spk6-vv", p, 4)  # 2 elements x 2 values
    X = [0] * 8  # 2 elements x 4 coeffs; index = coeff_bits | elem_bit
    for u in range(2):
        for i in range(4):
            X[i + 4 * u] = sum(E[t][i] * vv[2 * u + t] for t in range(2)) % p
    tr = Transcript("spk6-pack")
    tr.absorb(*X, *vv)
    r = [tr.challenge(p) for _ in range(3)]

    def defect(x_table):
        acc = 0
        for u in range(2):
            for i in range(4):
                b = [(i >> 0) & 1, (i >> 1) & 1, u]
                w = eq_weight(r, b, p)
                pv = (x_table[i + 4 * u]
                      - sum(E[t][i] * vv[2 * u + t] for t in range(2))) % p
                acc = (acc + w * pv) % p
        return acc

    check("SPK-6b packing-image zero-check: honest packed tensor = 0",
          defect(X) == 0)
    X_bad = list(X)
    X_bad[2] = (X_bad[2] + 7) % p  # junk injected off the packing image
    check("SPK-6b packing-image zero-check: junk-bearing tensor REJECTED",
          defect(X_bad) != 0)


# --------------------------------------------------------------------------
# SPK-7 — CR-L4a multi-point -> one-point batch.

def spk7():
    p = Q31
    n = 3
    T = rng_stream("spk7-T", p, 2**n)
    z1 = rng_stream("spk7-z1", p, n)
    z2 = rng_stream("spk7-z2", p, n)
    v1, v2 = mle_eval(T, z1, p), mle_eval(T, z2, p)

    def run(v2_claim):
        tr = Transcript("spk7")
        tr.absorb(*T, v1, v2_claim)
        mu1, mu2 = tr.challenge(p), tr.challenge(p)
        K = [(mu1 * a + mu2 * b) % p
             for a, b in zip(eq_table(z1, p), eq_table(z2, p))]
        claim = (mu1 * v1 + mu2 * v2_claim) % p
        ok, point, term = sumcheck([(1, [K, T])], claim, p, tr)
        if not ok:
            return False
        kv = (mu1 * _eq_at(z1, point, p) + mu2 * _eq_at(z2, point, p)) % p
        return term[0][0] == kv

    check("SPK-7 multi-point batch: honest claims ACCEPT", run(v2))
    check("SPK-7 multi-point batch: tampered claimed value REJECTS",
          not run((v2 + 1) % p))


def _eq_at(z, r, p):
    w = 1
    for zj, rj in zip(z, r):
        w = w * ((zj * rj + (1 - zj) * (1 - rj)) % p) % p
    return w


# --------------------------------------------------------------------------

def main():
    print("claim_reduction_spike: O-3 reduction certificates (toy shape)")
    spk1()
    spk2()
    spk3()
    spk4()
    spk5()
    spk6()
    spk7()
    n_ok = sum(1 for _, ok in RESULTS if ok)
    print(f"\n{n_ok}/{len(RESULTS)} OK")
    if n_ok != len(RESULTS):
        sys.exit(1)


if __name__ == "__main__":
    main()
