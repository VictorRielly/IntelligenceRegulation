#!/usr/bin/env python3
"""Route R (ring lift) parameter re-derivation.

Mirrors the C0-C4 iteration of the lattice report Section 11 /
derive_params_gadget in zkmatrix-rs/src/bin/lattice_matmul.rs, with the
Route Z scalar-challenge factors replaced by ring-challenge operator norms
over R_q = Z_q[X]/(X^d + 1), d = 128, coefficient embedding.

Substitutions (see docs/zkmatrix-poc/ROUTE_R_DESIGN.md Section 3):
  - repetitions r = 1 (challenge set C = quinary-coefficient ring elements,
    |C| = 5^128 = 2^297.2, replacing C1's r(b-2) >= 256).
  - challenge operator norm  op  replaces 2^b:
      worst case      op_wc = ||c||_1 <= 2d          (l1 * l2 bound)
      concentration   op_c  = 1.3 * sqrt(E[c_i^2] d) = 1.3 sqrt(2d)
    (E||c x||^2 = d E[c^2] ||x||^2 exactly for negacyclic convolution; the
    1.3 tail matches the report's 1.2 discipline with margin. Concentration
    bounds are legitimate for rejection-CENTER sizing -- the challenges are
    honest-verifier randomness -- with a restart-if-exceeded rule and a
    2^-64-class addition to the soundness error where extraction compares
    against combined honest openings; both uses are flagged in the doc.)
  - combining t commitments with independent ring challenges:
      worst case      B = t * op_wc * b0
      concentration   B = 1.3 * sqrt(2 d t) * b0
  - multiplication expansion: products of short elements bound by
    ||xy||_2 <= ||x||_1 ||y||_2 (worst case) / sqrt(d E[x^2]) ||y||_2 (conc).

The X^d+1 expansion factor is inside op; everything else is the report's
chain verbatim: sigma = 12 T, B = 1.2 sigma sqrt(dim), beta per protocol,
C2: q > 8 beta, C3: k_Z >= (log2 beta / 2)^2 / (log2 q * log2 delta0),
C4: N_Z >= k_Z + msg_Z + 768 log2 q / 11.7.
"""

import math

D = 128
LOG2_DELTA0 = 0.005326
E_C2 = 2.0  # E[c_i^2] for quinary coefficients {-2..2}
TAIL = 1.3


def op_norm(conc: bool) -> float:
    return TAIL * math.sqrt(E_C2 * D) if conc else 2.0 * D


def combine(t: int, b0: float, conc: bool) -> float:
    if conc:
        return TAIL * math.sqrt(E_C2 * D * t) * b0
    return t * 2.0 * D * b0


def derive(proto: str, rows: int, inner: int, cols: int, msg_min: int,
           log2_q: float, conc: bool):
    """One C0-C4 iteration at fixed log2 q. Returns dict or None (C2 fail)."""
    msg_r = max(1, math.ceil(max(rows, inner, msg_min) / D))
    msg_z = msg_r * D
    d_lwe = math.ceil(768.0 * log2_q / 11.7)
    k_z = 12 * D  # seed guess
    out = {}
    for _ in range(6):
        n_r = math.ceil((k_z + msg_z + d_lwe) / D)
        n_z = n_r * D
        b0 = math.sqrt(n_z)
        op = op_norm(conc)
        if proto == "pi1":
            b_rho = combine(cols, b0, conc)
            t_sq = 2.0 * (op * b_rho) ** 2
            dim = 2 * n_z
        else:  # pi2
            b_rho_s = combine(rows, b0, conc)
            b_rho_v = combine(cols, b0, conc)
            last = op * b0 + op * op * b_rho_v
            t_sq = op * op * (b_rho_s ** 2 + b_rho_v ** 2) + last * last
            dim = 3 * n_z
        sigma = 12.0 * math.sqrt(t_sq)
        bound = 1.2 * sigma * math.sqrt(dim)
        if proto == "pi1":
            beta = 2.0 * bound + op * b_rho
        else:
            beta = max(2.0 * bound + op * b_rho_s,
                       3.0 * op * bound + op ** 3 * b_rho_v)
        k_z = math.ceil((math.log2(beta) / 2.0) ** 2
                        / (log2_q * LOG2_DELTA0))
        out = dict(msg_r=msg_r, msg_z=msg_z, n_r=n_r, n_z=n_z,
                   kappa=math.ceil(k_z / D), k_z=k_z,
                   sigma=sigma, bound=bound, beta=beta, d_lwe=d_lwe)
    # C2 with >= 1 bit headroom; C0 ring analogue (LS18: q > 32) is trivial.
    if 2.0 ** log2_q <= 16.0 * out["beta"]:
        return None
    out["log2_q"] = log2_q
    return out


def minimal_q(proto, rows, inner, cols, msg_min, conc):
    for lq in [x / 2.0 for x in range(56, 125)]:  # 28.0 .. 62.0
        r = derive(proto, rows, inner, cols, msg_min, lq, conc)
        if r is not None:
            return r
    return None


def commit_col_kb(r, lq):
    return (r["kappa"] + r["msg_r"]) * D * lq / 8.0 / 1024.0


def proof_kb(proto, r, lq):
    sigma_bits = math.log2(r["sigma"]) + 4
    if proto == "pi1":
        bits = r["msg_z"] * lq + 2 * r["n_z"] * sigma_bits
    else:
        bits = (2 * r["msg_z"] * lq + 3 * r["n_z"] * sigma_bits
                + (r["kappa"] * D + D) * lq)
    return bits / 8.0 / 1024.0


def show(label, proto, rows, inner, cols, msg_min=0):
    print(f"\n### {label} ({proto}, {rows}x{inner}x{cols})")
    print("| norm model | min log2 q | kappa | N_r (N_Z) | msg_r | "
          "log2 sigma | log2 beta | commit/col KB | proof KB (r=1) |")
    print("|---|---|---|---|---|---|---|---|---|")
    for conc, name in [(False, "worst-case l1"), (True, "concentration")]:
        r = minimal_q(proto, rows, inner, cols, msg_min, conc)
        if r is None:
            print(f"| {name} | (none <= 2^62) | | | | | | | |")
            continue
        lq = r["log2_q"]
        print(f"| {name} | {lq:.1f} | {r['kappa']} | "
              f"{r['n_r']} ({r['n_z']}) | {r['msg_r']} | "
              f"{math.log2(r['sigma']):.1f} | {math.log2(r['beta']):.1f} | "
              f"{commit_col_kb(r, lq):.1f} | {proof_kb(proto, r, lq):.1f} |")
        # also at fixed q = 2^31-19 if feasible (prototype modulus)
        r31 = derive(proto, rows, inner, cols, msg_min, 31.0, conc)
        if r31 is not None:
            print(f"| {name} @ q=2^31 | 31.0 | {r31['kappa']} | "
                  f"{r31['n_r']} ({r31['n_z']}) | {r31['msg_r']} | "
                  f"{math.log2(r31['sigma']):.1f} | "
                  f"{math.log2(r31['beta']):.1f} | "
                  f"{commit_col_kb(r31, 31.0):.1f} | "
                  f"{proof_kb(proto, r31, 31.0):.1f} |")


# ===========================================================================
# Q3 (k = 8 split): residue classes, q8 selection, LS18 (k, q) frontier.
#
# LS18 (Lyubashevsky-Seiler, EUROCRYPT 2018), general form as quoted in
# ROUTE_R_DESIGN.md Section 1: for prime q = 2k+1 (mod 4k), X^d + 1 splits
# into k irreducible factors X^(d/k) - r_i mod q, and every nonzero y in R_q
# with ||y||_inf < q^(1/k) / sqrt(k) is invertible. Quinary challenge
# differences have ||c - c'||_inf <= 4, so the coverage condition is
# q^(1/k) / sqrt(k) > 4, i.e. q > (4 sqrt(k))^k.
#
# k = 8 residue condition: q = 17 (mod 32). Equivalently v2(q-1) = 4:
# primitive 16th roots of unity eta exist (eta^8 = -1), no 32nd roots, so
# X^128 + 1 = prod_{t=0..7} (X^16 - eta^(2t+1)) with each binomial
# irreducible (Lidl-Niederreiter Thm 3.75: X^n - s irreducible over F_q iff
# every prime p | n divides ord(s) and not (q-1)/ord(s), and 4 | n implies
# q = 1 mod 4; here n = 16, ord(s) = 16, (q-1)/16 odd, q = 1 mod 16).
# ===========================================================================

CHALLENGE_DIFF_INF = 4  # quinary challenge differences: ||c - c'||_inf <= 4

_MR_BASES = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37)


def is_prime(n: int) -> bool:
    """Deterministic Miller-Rabin for n < 3.3e24 (fixed base set)."""
    if n < 2:
        return False
    for p in _MR_BASES:
        if n % p == 0:
            return n == p
    d, s = n - 1, 0
    while d % 2 == 0:
        d //= 2
        s += 1
    for a in _MR_BASES:
        x = pow(a, d, n)
        if x in (1, n - 1):
            continue
        for _ in range(s - 1):
            x = x * x % n
            if x == n - 1:
                break
        else:
            return False
    return True


def v2(n: int) -> int:
    s = 0
    while n % 2 == 0:
        n //= 2
        s += 1
    return s


def ls18_bound(q: float, k: int) -> float:
    return q ** (1.0 / k) / math.sqrt(k)


def ls18_min_q(k: int) -> float:
    """Smallest q with LS18 coverage of quinary differences at split k."""
    return float((CHALLENGE_DIFF_INF * math.sqrt(k)) ** k)


def primitive_16th_root(q: int) -> int:
    """eta with eta^8 = -1 mod q (primitive 16th root); needs 16 | q-1."""
    assert (q - 1) % 16 == 0
    for x in range(2, 1000):
        eta = pow(x, (q - 1) // 16, q)
        if pow(eta, 8, q) == q - 1:
            return eta
    raise ValueError(f"no primitive 16th root found for q = {q}")


def _polymul_mod_binomial(a, b, s, q, n=16):
    """a * b mod (X^n - s) mod q; a, b are length-n coefficient lists."""
    wide = [0] * (2 * n)
    for i, ai in enumerate(a):
        if ai == 0:
            continue
        for j, bj in enumerate(b):
            wide[i + j] = (wide[i + j] + ai * bj) % q
    return [(wide[i] + s * wide[i + n]) % q for i in range(n)]


def binomial_irreducible_frobenius(q: int, s: int, n: int = 16) -> bool:
    """Direct Frobenius check that f = X^n - s is irreducible over F_q:
    X^(q^(n/2)) != X and X^(q^n) = X in F_q[X]/(f). Sufficient here since
    all irreducible factors of a binomial dividing X^d + 1 in this setting
    have equal 2-power degree, so a proper factor forces degree <= n/2."""
    x_poly = [0] * n
    x_poly[1] = 1
    # xq = X^q mod f by square-and-multiply on the exponent q.
    xq = [0] * n
    xq[0] = 1  # start with 1, multiply by X per bit
    base = list(x_poly)
    e = q
    while e > 0:
        if e & 1:
            xq = _polymul_mod_binomial(xq, base, s, q, n)
        base = _polymul_mod_binomial(base, base, s, q, n)
        e >>= 1
    # Frobenius iterates by composition: X^(q^(j+1)) = (X^(q^j)) o (X^q).
    def compose(g, h):
        out = [0] * n
        for coeff in reversed(g):
            out = _polymul_mod_binomial(out, h, s, q, n)
            out[0] = (out[0] + coeff) % q
        return out

    frob = list(xq)  # X^(q^1)
    for _ in range(n // 2 - 1):
        frob = compose(frob, xq)  # X^(q^(n/2))
    if frob == x_poly:
        return False
    for _ in range(n // 2):
        frob = compose(frob, xq)  # X^(q^n)
    return frob == x_poly


def find_q8(bits: int):
    """Largest prime q < 2^bits with q = 17 mod 32, plus split data."""
    q = None
    c = 15  # 2^bits = 0 mod 32 for bits >= 5, so q = 2^bits - c needs c = 15 mod 32
    while True:
        cand = (1 << bits) - c
        if cand % 32 == 17 and is_prime(cand):
            q = cand
            break
        c += 32
    eta = primitive_16th_root(q)
    # slot roots in the butterfly leaf order used by ring_lattice.rs
    exps = [1, 9, 5, 13, 3, 11, 7, 15]
    roots = [pow(eta, e, q) for e in exps]
    # verify: product of the 8 binomials is X^128 + 1 mod q
    prod = [1]
    for r in roots:
        nxt = [0] * (len(prod) + 16)
        for i, c0 in enumerate(prod):
            nxt[i + 16] = (nxt[i + 16] + c0) % q
            nxt[i] = (nxt[i] - r * c0) % q
        prod = nxt
    expect = [0] * 129
    expect[0] = 1
    expect[128] = 1
    assert prod == expect, "product of slot binomials != X^128 + 1"
    # verify irreducibility of every slot binomial (criterion + Frobenius)
    assert v2(q - 1) == 4
    for r in roots:
        # ord(r) = 16: r = eta^odd and eta has order 16
        assert pow(r, 8, q) == q - 1 and pow(r, 16, q) == 1
        assert binomial_irreducible_frobenius(q, r)
    return dict(q=q, c=c, eta=eta, exps=exps, roots=roots)


def k_split_study():
    print("\n### Q3: k-split residue classes and LS18 coverage "
          "(quinary diffs, ||.||_inf <= 4)")
    print("| k | residue class | min q for LS18 coverage | single-limb? |")
    print("|---|---|---|---|")
    for k in (2, 4, 8, 16):
        mq = ls18_min_q(k)
        feas = "yes" if mq < 2 ** 63 else "NO (> 2^63)"
        print(f"| {k} | q = {2 * k + 1} mod {4 * k} | "
              f"q > (4 sqrt({k}))^{k} = 2^{math.log2(mq):.1f} | {feas} |")
    print("  => k = 8 is the deepest split reachable with quinary "
          "challenges at single-limb q; k = 16 needs q > 2^64.")

    print("\n### Q3: LS18 bound q^(1/k)/sqrt(k) and margin over 4, "
          "by (k, q)")
    qs = [("2^28", 2.0 ** 28), ("q31-class (2^31)", 2.0 ** 31),
          ("2^37", 2.0 ** 37), ("q46-class (2^46)", 2.0 ** 46)]
    print("| k | " + " | ".join(name for name, _ in qs) + " |")
    print("|---|" + "---|" * len(qs))
    for k in (2, 4, 8, 16):
        cells = []
        for _, qv in qs:
            b = ls18_bound(qv, k)
            verdict = f"{b:.1f} ({b / 4:.2f}x)" if b > 4 else f"{b:.1f} FAIL"
            cells.append(verdict)
        print(f"| {k} | " + " | ".join(cells) + " |")

    for bits in (31, 46):
        r = find_q8(bits)
        q = r["q"]
        b = ls18_bound(q, 8)
        print(f"\n  q8 at {bits} bits: q = 2^{bits} - {r['c']} = {q} "
              f"(prime, q mod 32 = {q % 32})")
        print(f"    eta (primitive 16th root) = {r['eta']}; slot roots "
              f"eta^{r['exps']}")
        print(f"    all 8 binomials X^16 - eta^odd verified irreducible "
              f"(criterion + Frobenius); product = X^128 + 1 ok")
        print(f"    LS18 bound q^(1/8)/sqrt(8) = {b:.2f}; quinary-diff "
              f"margin {b / 4:.2f}x")
    print("  NOTE: RING_MULT_BOTTLENECK.md Section 3's '~10-13 at q ~ 2^31'"
          " was an estimate; the exact bound at 2^31 is "
          f"{ls18_bound(2.0**31, 8):.2f} (margin "
          f"{ls18_bound(2.0**31, 8) / 4:.2f}x). Corrected in the results.")


# ===========================================================================
# Q2 (response digit decomposition): the modulus is forced to ~2^46 by the
# norm chain of the *combined* witnesses (C2: q > 8 beta with beta carrying
# the combination count t and the Gaussian-mask blowup 14.4 op sqrt(N_Z dim)).
# Design (prototype-implemented in ring_lattice.rs section 12):
#
#   Every combination witness u (per-coefficient magnitude W_u, from t
#   combined ternary vectors) is replaced by its balanced base-2^e digit
#   vectors u = sum_j 2^(ej) u_j, ||u_j||_inf <= 2^(e-1), with
#   (i)   published digit statements t_j = A1 u_j,
#   (ii)  exact range claims on each digit (M2 binary-decomposition
#         ct-claims -- deterministic coefficient checks, no Sigma slack;
#         prototype stand-in: the per-digit response norm check),
#   (iii) the public mod-q recombination sum_j 2^(ej) t_j = t, and
#   (iv)  per-digit Sigma openings sharing one challenge, jointly
#         rejection-sampled; centers scale with 2^(e-1), NOT with W_u.
#
#   Extraction recovers digits that are genuinely range-bounded (ct-claims
#   are exact over Z_q), so the recombined witness has honest magnitude
#   W_u and every C2/C3-relevant norm collapses to the digit scale:
#   beta = beta(e), independent of t. Cost: L = ceil((log2 W_u + 1)/e)
#   digit rounds instead of one (proof size), plus L digit commitments per
#   combination (per-claim commit ops, side-linear).
#
#   COUPLING (the Q2/Q3 risk): the smaller q must still cover the k = 8
#   LS18 bound (q > 2^28.07); the frontier table below reports both
#   constraints jointly.
# ===========================================================================

E_RHO2 = 2.0 / 3.0  # E[rho_i^2] for ternary randomness


def witness_coeff_bound(t: int, conc: bool) -> float:
    """Per-coefficient magnitude of a t-fold challenge combination of
    ternary vectors: worst t * ||c||_1 = t * 2D; concentration
    1.3 sqrt(t * D * E[c^2] * E[rho^2])."""
    if conc:
        return TAIL * math.sqrt(t * D * E_C2 * E_RHO2)
    return t * 2.0 * D


def derive_q2(proto: str, rows: int, inner: int, cols: int, msg_min: int,
              log2_q: float, conc: bool, e: int):
    """C0-C4 iteration for the digit-decomposed opening layer."""
    t = max(rows, cols)
    w_u = witness_coeff_bound(t, conc)
    l_dig = math.ceil((math.log2(w_u) + 1.0) / e)
    msg_r = max(1, math.ceil(max(rows, inner, msg_min) / D))
    msg_z = msg_r * D
    d_lwe = math.ceil(768.0 * log2_q / 11.7)
    k_z = 8 * D
    out = {}
    for _ in range(6):
        n_r = math.ceil((k_z + msg_z + d_lwe) / D)
        n_z = n_r * D
        op = op_norm(conc)
        half = 2.0 ** (e - 1)
        # Joint (bundled) rejection over the L digit responses.
        t_bundle = op * half * math.sqrt(l_dig * n_z)
        sigma = 12.0 * t_bundle
        bound = 1.2 * sigma * math.sqrt(l_dig * n_z)
        beta_dig = 2.0 * bound + op * half * math.sqrt(n_z)
        # Recombined range-proved witness after one challenge clearing --
        # honest magnitude W_u, not the Gaussian-response magnitude.
        beta_rec = op * w_u * math.sqrt(n_z)
        beta = max(beta_dig, beta_rec)
        k_z = math.ceil((math.log2(beta) / 2.0) ** 2
                        / (log2_q * LOG2_DELTA0))
        out = dict(msg_r=msg_r, msg_z=msg_z, n_r=n_r, n_z=n_z,
                   kappa=math.ceil(k_z / D), k_z=k_z, sigma=sigma,
                   bound=bound, beta=beta, l_dig=l_dig, w_u=w_u, e=e,
                   d_lwe=d_lwe)
    if 2.0 ** log2_q <= 16.0 * out["beta"]:
        return None
    out["log2_q"] = log2_q
    return out


def minimal_q_q2(proto, rows, inner, cols, msg_min, conc, e):
    for lq in [x / 2.0 for x in range(52, 125)]:  # 26.0 .. 62.0
        r = derive_q2(proto, rows, inner, cols, msg_min, lq, conc, e)
        if r is not None:
            return r
    return None


def proof_kb_q2(proto, r, lq):
    """Pi2-shaped proof size with digit decomposition: responses go per
    digit (L smaller vectors each), and the digit statements (kappa ring
    rows per digit, both combination sides) are carried in the proof.
    Model, same conventions as proof_kb."""
    sigma_bits = math.log2(r["sigma"]) + 4
    l_dig = r["l_dig"]
    resp = 3 * l_dig * r["n_z"] * sigma_bits
    stmts = 2 * l_dig * r["kappa"] * D * lq
    bits = 2 * r["msg_z"] * lq + resp + (r["kappa"] * D + D) * lq + stmts
    return bits / 8.0 / 1024.0


def q2_frontier():
    q31 = 2147483249.0  # q8_31 = 2^31 - 399 (k = 8 class)
    print("\n### Q2: digit-decomposition frontier, Pi2 n = 2048 "
          "(concentration; baseline q46 = 117.0 KB, beta = 2^42.0)")
    print("| e | L | log2 W_u | log2 sigma | log2 beta | min log2 q (C2) |"
          " C2 headroom @q31 (bits) | kappa | N_r | proof KB | delta vs "
          "q46 |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    base = minimal_q(("pi2"), 2048, 2048, 2048, 0, True)
    base_kb = proof_kb("pi2", base, base["log2_q"])
    for e in (2, 3, 4, 6, 8):
        rmin = minimal_q_q2("pi2", 2048, 2048, 2048, 0, True, e)
        r31 = derive_q2("pi2", 2048, 2048, 2048, 0, 31.0, True, e)
        if rmin is None:
            print(f"| {e} | - | - | - | - | (none) | | | | | |")
            continue
        if r31 is None:
            print(f"| {e} | {rmin['l_dig']} | "
                  f"{math.log2(rmin['w_u']):.1f} | "
                  f"{math.log2(rmin['sigma']):.1f} | "
                  f"{math.log2(rmin['beta']):.1f} | {rmin['log2_q']:.1f} | "
                  f"exceeds q31 | {rmin['kappa']} | {rmin['n_r']} | "
                  f"{proof_kb_q2('pi2', rmin, rmin['log2_q']):.1f} | - |")
            continue
        hr = 31.0 - math.log2(8.0 * r31["beta"])
        kb = proof_kb_q2("pi2", r31, 31.0)
        print(f"| {e} | {rmin['l_dig']} | {math.log2(rmin['w_u']):.1f} | "
              f"{math.log2(r31['sigma']):.1f} | "
              f"{math.log2(r31['beta']):.1f} | {rmin['log2_q']:.1f} | "
              f"{hr:.1f} | {r31['kappa']} | {r31['n_r']} | {kb:.1f} | "
              f"{kb - base_kb:+.1f} |")
    print(f"  (baseline undecomposed: min log2 q = {base['log2_q']:.1f}, "
          f"kappa = {base['kappa']}, N_r = {base['n_r']}, "
          f"proof {base_kb:.1f} KB)")

    print("\n### Q2 x Q3 coupling: the (k, q, e) frontier "
          "(LS18 margin = q^(1/k)/sqrt(k) / 4)")
    print("| k | LS18 min q | e = 2 C2 min q | joint min q | LS18 margin "
          "@ joint min q | LS18 margin @ q31 | verdict |")
    print("|---|---|---|---|---|---|---|")
    e2 = minimal_q_q2("pi2", 2048, 2048, 2048, 0, True, 2)
    c2_min = e2["log2_q"]
    for k in (2, 4, 8, 16):
        ls_min = math.log2(ls18_min_q(k))
        joint = max(ls_min, c2_min)
        if joint > 63:
            print(f"| {k} | 2^{ls_min:.1f} | 2^{c2_min:.1f} | > 2^63 | - |"
                  f" - | infeasible (single limb) |")
            continue
        mj = ls18_bound(2.0 ** joint, k) / 4.0
        m31 = ls18_bound(q31, k) / 4.0
        verdict = ("RECOMMENDED (max split)" if k == 8
                   else "feasible, slower kernels")
        print(f"| {k} | 2^{ls_min:.1f} | 2^{c2_min:.1f} | 2^{joint:.1f} | "
              f"{mj:.2f}x | {m31:.2f}x | {verdict} |")
    print("  => recommended operating point: k = 8, q = q8_31 = 2^31 - 399,"
          f" e in {{2, 3, 4}}. The C2 floor (2^{c2_min:.1f} at e = 2)"
          " sits ABOVE the k = 8 LS18 minimum (2^28.1), so no achievable"
          " q forces k below 8; digit decomposition and the k = 8 split"
          " are jointly feasible at a 31-bit single-limb modulus.")


def soundness_accounting():
    print("### Challenge-set soundness accounting (replaces C1)")
    for base, name in [(3, "ternary {-1,0,1}"), (5, "quinary {-2..2}")]:
        log_c = D * math.log2(base)
        eps = 1.0 - log_c  # log2(2/|C|)
        post_fs = 128.0 + eps  # log2((Q+1)^2 eps), Q = 2^64
        verdict = "PASS" if post_fs <= -128 else "FAIL"
        print(f"  {name}: |C| = {base}^{D} = 2^{log_c:.1f}; "
              f"knowledge error 2/|C| = 2^{eps:.1f}; "
              f"(Q+1)^2 eps = 2^{post_fs:.1f} vs target 2^-128 -> {verdict}")
    log_c = 256 * math.log2(3)
    print(f"  ternary at d=256 (fallback): |C| = 2^{log_c:.1f}; "
          f"post-FS 2^{128 + 1 - log_c:.1f} -> PASS")


if __name__ == "__main__":
    print("Route R parameter tables (d = 128, quinary challenges, r = 1)")
    soundness_accounting()
    k_split_study()
    q2_frontier()
    # Demo chain shapes (M0/M1 report): X 16x32, W1 32x64, W2 64x8.
    show("demo chain worst shape", "pi2", 32, 32, 64, msg_min=64)
    # Square n = 2048, both protocols (the LLM-scale reference claim).
    show("n = 2048 square", "pi2", 2048, 2048, 2048)
    show("n = 2048 square", "pi1", 2048, 2048, 2048)
    # FFN-like rectangle at Llama-7B width (per-token-block claims).
    show("FFN block 512x4096x11008", "pi2", 512, 4096, 11008)
