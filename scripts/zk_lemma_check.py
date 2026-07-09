#!/usr/bin/env python3
"""Numeric sanity checks for the U-P proof-debt tranche (Q4.3d/e, R1, Q4.4c).

Checks, in order:
  1. The transcript-determinism / exact-leak identities for the
     sigma-twisted quadratic claim family (Q4.3d): given (c, z) the head
     images are the stated deterministic functions of (publics, x), and
     the leak triple (Q, Lambda_a, Lambda_b) is verifier-computable.
  2. Same for the untwisted quadratic ring family and the ct-quadratic
     (reveal + g-mask) family, including the (h, W_quad) -> Q leak.
  3. Completeness of the R1-masked check equation (the hardening spec):
     the padded images verify with the extra -sigma(P_MA) - P_MB
     - sigma(P_MW) terms and G0~ absorbing the pad mask images.
  4. C-recovery from the gate's W_tq leak at the real parameters
     (D = 128, q = 2^31 - 399, rows = 4, cols = 3): the linear system
     over the leaked ring element has full rank and recovers C exactly.
  5. ARP numbers: the coded SLACK_OP budget vs the Q4.4c coordinate-wise
     direct-witness bound at the frozen (n = 512, rows = 256, alpha = 3)
     point, plus a Monte-Carlo check of the per-row 1/2 bound.

Pure Python, no dependencies. Run from the repo root:
    python3 scripts/zk_lemma_check.py
Every check asserts; the script prints one OK line per check.
"""

import random

# ---------------------------------------------------------------------------
# Toy negacyclic ring R_q = Z_q[X]/(X^D + 1).


def pmul(a, b, D, q):
    out = [0] * D
    for i, ai in enumerate(a):
        if ai == 0:
            continue
        for j, bj in enumerate(b):
            k = i + j
            if k < D:
                out[k] = (out[k] + ai * bj) % q
            else:
                out[k - D] = (out[k - D] - ai * bj) % q
    return out


def padd(a, b, q):
    return [(x + y) % q for x, y in zip(a, b)]


def psub(a, b, q):
    return [(x - y) % q for x, y in zip(a, b)]


def pneg(a, q):
    return [(-x) % q for x in a]


def auto(a, t, D, q):
    """sigma_t: X^i -> X^{t i mod 2D} with X^D = -1 sign handling."""
    out = [0] * D
    for i, ai in enumerate(a):
        e = (t * i) % (2 * D)
        if e < D:
            out[e] = (out[e] + ai) % q
        else:
            out[e - D] = (out[e - D] - ai) % q
    return out


def conj(a, D, q):
    return auto(a, 2 * D - 1, D, q)


def rand_poly(D, q, rng):
    return [rng.randrange(q) for _ in range(D)]


def quinary(D, rng):
    return [rng.randrange(-2, 3) for _ in range(D)]


def to_mod(a, q):
    return [x % q for x in a]


# ---------------------------------------------------------------------------
# Check 1 + 2 + 3: the claim-family identities on a toy ring.


def combo(coeffs, table, D, q):
    acc = [0] * D
    for idx, cf in coeffs:
        acc = padd(acc, pmul(cf, table[idx], D, q), q)
    return acc


def quad_combo(quad, ta, tb, D, q, twist):
    acc = [0] * D
    for ia, ib, gamma in quad:
        left = conj(ta[ia], D, q) if twist else ta[ia]
        acc = padd(acc, pmul(gamma, pmul(left, tb[ib], D, q), D, q), q)
    return acc


def check_families():
    D, q = 16, 12289
    rng = random.Random(7)
    n_obj = 5
    x = [rand_poly(D, q, rng) for _ in range(n_obj)]  # witness slots
    Y = [rand_poly(D, q, rng) for _ in range(n_obj)]  # mask images A2 y
    c = to_mod(quinary(D, rng), q)
    sc = conj(c, D, q)
    # Virtual openings P_i = c x_i - Y_i (the verifier's p_table).
    P = [psub(pmul(c, xi, D, q), Yi, q) for xi, Yi in zip(x, Y)]
    quad = [(0, 1, to_mod(quinary(D, rng), q)), (2, 3, to_mod(quinary(D, rng), q)),
            (1, 4, to_mod(quinary(D, rng), q))]
    lin = [(2, rand_poly(D, q, rng)), (4, rand_poly(D, q, rng))]

    # ---- sigma-twisted family (QuadCtClaim / TwistedQuadRingClaim algebra).
    Q = quad_combo(quad, x, x, D, q, True)
    L = combo(lin, x, D, q)
    Ga = quad_combo(quad, x, Y, D, q, True)
    Gb = quad_combo(quad, Y, x, D, q, True)
    G0 = quad_combo(quad, Y, Y, D, q, True)
    W = combo(lin, Y, D, q)
    E = quad_combo(quad, P, P, D, q, True)
    aP = combo(lin, P, D, q)
    # Engine check identity: E + sc Ga + c Gb - G0 + sc (sum aP + W)
    #   = sc c (Q + L)   [with c C_L - ZA_L = sum a P].
    lhs = padd(E, pmul(sc, Ga, D, q), q)
    lhs = padd(lhs, pmul(c, Gb, D, q), q)
    lhs = psub(lhs, G0, q)
    lhs = padd(lhs, pmul(sc, padd(aP, W, q), D, q), q)
    rhs = pmul(pmul(sc, c, D, q), padd(Q, L, q), D, q)
    assert lhs == rhs, "twisted check identity FAILED"
    # Leak identities (Q4.3d): all verifier-computable given the head + z.
    La = quad_combo(quad, x, P, D, q, True)   # Lambda_a = sum gamma sigma(x_a) P_b
    Lb = quad_combo(quad, P, x, D, q, True)   # Lambda_b = sum gamma x_b sigma(P_a)
    assert psub(pmul(c, Q, D, q), Ga, q) == La, "Ga leak identity FAILED"
    assert psub(pmul(sc, Q, D, q), Gb, q) == Lb, "Gb leak identity FAILED"
    assert padd(W, aP, q) == pmul(c, L, D, q), "W leak identity FAILED"
    g0_pred = psub(psub(pmul(pmul(sc, c, D, q), Q, D, q), pmul(sc, La, D, q), q),
                   pmul(c, Lb, D, q), q)
    assert padd(g0_pred, E, q) == G0, "G0 determinism identity FAILED"
    print("OK 1: twisted-quad check identity + exact leak triple (Q, La, Lb)")

    # ---- ct-quadratic variant: reveal h = Q + L + g, W_quad includes the
    # g-slot mask image; (h, W_quad) reveals Q exactly: c h - (W_quad +
    # sum a P + P_g) = c Q.
    g = rand_poly(D, q, rng)
    Yg = rand_poly(D, q, rng)
    Pg = psub(pmul(c, g, D, q), Yg, q)
    h = padd(padd(Q, L, q), g, q)
    Wq = padd(W, Yg, q)
    lhs = psub(pmul(c, h, D, q), padd(padd(Wq, aP, q), Pg, q), q)
    assert lhs == pmul(c, Q, D, q), "ct-quad (h, W_quad) -> Q leak FAILED"
    print("OK 2a: ct-quad reveal pair (h, W_quad) leaks Q despite the g-mask")

    # ---- untwisted quadratic ring family: E2 + c G1 - G0u + c(sum aP + W)
    #   = c^2 (Q + L); G1 leaks Lambda_1 = sum gamma (x_a P_b + P_a x_b).
    Qu = quad_combo(quad, x, x, D, q, False)
    G1 = padd(quad_combo(quad, x, Y, D, q, False),
              quad_combo(quad, Y, x, D, q, False), q)
    G0u = quad_combo(quad, Y, Y, D, q, False)
    E2 = quad_combo(quad, P, P, D, q, False)
    lhs = padd(E2, pmul(c, G1, D, q), q)
    lhs = psub(lhs, G0u, q)
    lhs = padd(lhs, pmul(c, padd(aP, W, q), D, q), q)
    rhs = pmul(pmul(c, c, D, q), padd(Qu, L, q), D, q)
    assert lhs == rhs, "untwisted check identity FAILED"
    L1 = padd(quad_combo(quad, x, P, D, q, False),
              quad_combo(quad, P, x, D, q, False), q)
    two_cQ = pmul(to_mod([2] + [0] * (D - 1), q), pmul(c, Qu, D, q), D, q)
    assert psub(two_cQ, G1, q) == L1, "G1 leak identity FAILED"
    print("OK 2b: untwisted-quad check identity + G1/W leak pair")

    # ---- R1-masked twisted variant (the hardening spec's check equation).
    ma, mb, mw = (rand_poly(D, q, rng) for _ in range(3))
    # Pads with sigma(c) coefficients are committed pre-conjugated.
    Yma, Ymb, Ymw = (rand_poly(D, q, rng) for _ in range(3))
    Pma = psub(pmul(c, conj(ma, D, q), D, q), Yma, q)  # slot holds conj(ma)
    Pmb = psub(pmul(c, mb, D, q), Ymb, q)              # slot holds mb
    Pmw = psub(pmul(c, conj(mw, D, q), D, q), Ymw, q)  # slot holds conj(mw)
    Gat = padd(Ga, ma, q)
    Gbt = padd(Gb, mb, q)
    Wt = padd(W, mw, q)
    G0t = padd(padd(G0, conj(Yma, D, q), q), padd(Ymb, conj(Ymw, D, q), q), q)
    lhs = padd(E, pmul(sc, Gat, D, q), q)
    lhs = padd(lhs, pmul(c, Gbt, D, q), q)
    lhs = psub(lhs, G0t, q)
    lhs = padd(lhs, pmul(sc, padd(aP, Wt, q), D, q), q)
    lhs = psub(lhs, conj(Pma, D, q), q)
    lhs = psub(lhs, Pmb, q)
    lhs = psub(lhs, conj(Pmw, D, q), q)
    rhs = pmul(pmul(sc, c, D, q), padd(Q, L, q), D, q)
    assert lhs == rhs, "R1-masked twisted check identity FAILED"
    print("OK 3a: R1-masked twisted check equation is complete")

    # ---- R1-masked untwisted variant: pads m1 (on G1) and mw (on W), both
    # plain-committed (their check coefficients are c, not sigma(c)).
    m1 = rand_poly(D, q, rng)
    Ym1 = rand_poly(D, q, rng)
    Pm1 = psub(pmul(c, m1, D, q), Ym1, q)
    Pmw2 = psub(pmul(c, mw, D, q), Ymw, q)             # slot holds mw (plain)
    G1t = padd(G1, m1, q)
    Wt2 = padd(W, mw, q)
    G0ut = padd(G0u, padd(Ym1, Ymw, q), q)
    lhs = padd(E2, pmul(c, G1t, D, q), q)
    lhs = psub(lhs, G0ut, q)
    lhs = padd(lhs, pmul(c, padd(aP, Wt2, q), D, q), q)
    lhs = psub(lhs, Pm1, q)
    lhs = psub(lhs, Pmw2, q)
    rhs = pmul(pmul(c, c, D, q), padd(Qu, L, q), D, q)
    assert lhs == rhs, "R1-masked untwisted check identity FAILED"
    print("OK 3b: R1-masked untwisted check equation is complete")

# ---------------------------------------------------------------------------
# Check 4: C-recovery from the gate's W_tq leak at real parameters.


def check_c_recovery():
    D, q = 128, 2**31 - 399
    rng = random.Random(11)
    rows, cols = 4, 3
    s = [to_mod(quinary(D, rng), q) for _ in range(rows)]
    v = [to_mod(quinary(D, rng), q) for _ in range(cols)]
    # Leak equation: leaked = sum_ij C[i][j] * (conj(s_i) v_j) in R_q.
    e = [[pmul(conj(s[i], D, q), v[j], D, q) for j in range(cols)] for i in range(rows)]
    C = [[rng.randrange(q) for _ in range(cols)] for _ in range(rows)]
    leaked = [0] * D
    for i in range(rows):
        for j in range(cols):
            leaked = padd(leaked, [(C[i][j] * x) % q for x in e[i][j]], q)
    # Solve the D x (rows*cols) linear system over Z_q (q prime).
    ncols = rows * cols
    M = [[e[i][j][k] for i in range(rows) for j in range(cols)] + [leaked[k]]
         for k in range(D)]
    rank, piv_col, r = 0, 0, 0
    for col in range(ncols):
        piv = next((rr for rr in range(r, D) if M[rr][col] % q != 0), None)
        if piv is None:
            continue
        M[r], M[piv] = M[piv], M[r]
        inv = pow(M[r][col], q - 2, q)
        M[r] = [(x * inv) % q for x in M[r]]
        for rr in range(D):
            if rr != r and M[rr][col] % q != 0:
                f = M[rr][col]
                M[rr] = [(a - f * b) % q for a, b in zip(M[rr], M[r])]
        r += 1
    rank = r
    assert rank == ncols, f"gate leak system rank {rank} != {ncols}"
    # Consistency (no leftover nonzero rows) + recovery.
    for rr in range(rank, D):
        assert all(x % q == 0 for x in M[rr]), "inconsistent system"
    rec = [0] * ncols
    for rr in range(rank):
        lead = next(cc for cc in range(ncols) if M[rr][cc] % q != 0)
        rec[lead] = M[rr][ncols] % q
    flatC = [C[i][j] for i in range(rows) for j in range(cols)]
    assert rec == flatC, "C recovery mismatch"
    print(f"OK 4: gate W_tq leak -> full C recovery (rank {rank}/{ncols} at D={D}, q31)")


# ---------------------------------------------------------------------------
# Check 5: ARP budgets — coded SLACK_OP gate vs the Q4.4c bound.


def check_arp_numbers():
    import math
    D = 128
    SLACK_OP, JL_C = 4.0 * D, 13.0
    n, rows, w_inf, alpha = 512, 256, 1, 3.0
    center_row = 1.3 * math.sqrt(n * 0.5) * w_inf
    sigma_arp = math.ceil(alpha * center_row * math.sqrt(rows))
    y_bound = 1.2 * sigma_arp * math.sqrt(rows)
    coded = SLACK_OP * 2.0 * y_bound / math.sqrt(rows / JL_C)
    # Q4.4c: |b*_j| <= 2 y_bound per coordinate, so ||b*||_2 <= 2 y_bound sqrt(n).
    direct = 2.0 * y_bound * math.sqrt(n)
    print(f"OK 5a: frozen ARP point n={n} rows={rows} alpha={alpha}: "
          f"y_bound=2^{math.log2(y_bound):.2f}, coded extract=2^{math.log2(coded):.2f}, "
          f"Q4.4c extract=2^{math.log2(direct):.2f} "
          f"({math.log2(coded / direct):.2f} bits tighter)")
    assert direct < coded, "Q4.4c bound should be tighter than the coded gate"
    # Per-row 1/2 bound Monte-Carlo, ADVERSARIAL mask: one coordinate far
    # above 2*y_bound, mask m fixed at 0 so the r_j = 0 branch (prob 1/2)
    # lands the value dead-center in the window — the bound is tight.
    q = 2**46 - 1103
    rng = random.Random(13)
    b = [rng.randrange(-2, 3) for _ in range(n)]
    b[7] = int(3 * y_bound)  # violating coordinate
    trials, hits = 4000, 0
    Y = int(y_bound)
    for _ in range(trials):
        acc = 0
        for bj in b:
            r = rng.randrange(4)
            if r == 0:
                acc += bj
            elif r == 1:
                acc -= bj
        val = acc % q  # m = 0: the adversary's best fixed mask here
        if val > q // 2:
            val -= q
        if -Y <= val <= Y:
            hits += 1
    frac = hits / trials
    assert 0.40 <= frac <= 0.55, f"per-row window rate {frac} not in the 1/2 class"
    print(f"OK 5b: adversarial per-row window rate {frac:.3f} (the 1/2 bound is tight)")


if __name__ == "__main__":
    check_families()
    check_c_recovery()
    check_arp_numbers()
    print("all zk_lemma_check assertions passed")
