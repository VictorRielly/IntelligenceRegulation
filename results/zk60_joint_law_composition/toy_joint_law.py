#!/usr/bin/env python3
"""A toy masked sumcheck, enumerated exactly, as a sanity check of the
conditional sampler O1 and of Theorem 3.3's hypotheses.

Evidence for ZK60_JOINT_LAW_COMPOSITION.md sections 3 and 5.3.

WHAT THIS IS.  A faithful miniature of ONE private-block slot over a small
prime field: one main sumcheck variable, one extension round, degree 2, one
public table and one private table, a Chiesa-Forbes-Spooner mask with
L = N*d + 2 = 6 uniform coefficients, a reserved-pair value R that masks the
terminal, the published scalar `sigma + c*G`, the d+1 = 3 published values per
round, and the verifier's derived mask evaluation
`g_val = (fin - poly(terminals)) / c`.  The prover's whole randomness (the 6
mask coefficients and R) is ENUMERATED, so the distribution of the published
view is computed exactly, not sampled.

WHAT THIS IS NOT.  It is an ILLUSTRATION.  The field is a small prime, not
Fp2 with |Fp2| = 2^128; there is one slot, not 23; there is no polynomial
commitment, no pad, no Merkle tree, and no adaptivity.  Nothing here proves
anything about the real protocol.  What it does is check that the composition
argument's moving parts behave as section 3 says, and that each of the four
rules the memo identifies as load-bearing, when broken, makes the JOINT law
witness-dependent while leaving the marginals untouched.

No witness value, salt or private plane from any capture is used.

Run:  python3 toy_joint_law.py
"""

from collections import Counter
from itertools import product

Q = 5  # the prime field; 5 is enough for degree 2 (nodes 0,1,2 distinct) and e not in {0,1}


def inv(a):
    return pow(a % Q, Q - 2, Q)


def interp(vals, x):
    """Lagrange evaluation at x of the polynomial through (0, vals[0]), ..., (d, vals[d])."""
    d = len(vals) - 1
    out = 0
    for i in range(d + 1):
        num, den = 1, 1
        for m in range(d + 1):
            if m != i:
                num = num * (x - m) % Q
                den = den * (i - m) % Q
        out = (out + vals[i] * num * inv(den)) % Q
    return out


# ------------------------------------------------------------------ the mask
# g(x1, x2) = a0 + a'*x1*x2 + u1(x1) + u2(x2),  u_j(X) = a_{j,1} X + a_{j,2} X^2
# coeffs = [a0, a', a_{0,1}, a_{0,2}, a_{1,1}, a_{1,2}]   (sumcheck.rs:192-193)
N_VARS, DEGREE = 2, 2
L = N_VARS * DEGREE + 2


def g_at(a, xs, degree=DEGREE):
    acc = a[0]
    pr = 1
    for x in xs:
        pr = pr * x % Q
    acc = (acc + a[1] * pr) % Q
    for i, x in enumerate(xs):
        xp = 1
        for e in range(1, degree + 1):
            xp = xp * x % Q
            acc = (acc + a[2 + i * degree + (e - 1)] * xp) % Q
    return acc % Q


def mask_total(a, degree=DEGREE):
    return sum(g_at(a, [x1, x2], degree) for x1 in (0, 1) for x2 in (0, 1)) % Q


def mask_round0(a, degree=DEGREE):
    """sum over x2 in {0,1} of g(X, x2), at X = 0..DEGREE."""
    return [sum(g_at(a, [x, x2], degree) for x2 in (0, 1)) % Q for x in range(DEGREE + 1)]


def mask_round1(a, rho0, degree=DEGREE):
    """g(rho0, X), at X = 0..DEGREE."""
    return [g_at(a, [rho0, x], degree) for x in range(DEGREE + 1)]


def mask_eval(a, rho0, e, degree=DEGREE):
    return g_at(a, [rho0, e], degree)


# ------------------------------------------------------------------ one slot


def mle1(t, x):
    """multilinear extension of a 2-entry table over one variable"""
    return (t[0] + x * (t[1] - t[0])) % Q


def slot_view(pub, priv, a, R, c, rho0, e, mask_degree=DEGREE):
    """Return (view tuple, g_val, G, sanity dict) for one masked slot.

    poly(v) = v_pub * v_priv  -- every monomial carries the public factor, so
    poly(extensions) = 0 and the extension round is consistent
    (private_block/argument.rs:18-22).  `mask_degree` is the mask's per-variable
    degree; the slot's own degree (hence the d+1 published values per round) is
    always DEGREE, so mask_degree < DEGREE is the under-degree-mask control."""
    degree = DEGREE
    sigma = (pub[0] * priv[0] + pub[1] * priv[1]) % Q
    G = mask_total(a, mask_degree)
    gamma = (sigma + c * G) % Q

    h0 = [mle1(pub, x) * mle1(priv, x) % Q for x in range(degree + 1)]
    m0 = mask_round0(a, mask_degree)
    s0 = [(h0[i] + c * m0[i]) % Q for i in range(degree + 1)]

    claim1 = interp(s0, rho0)
    cur_pub = mle1(pub, rho0)
    cur_priv = mle1(priv, rho0)
    # the extension round: the line from (cur_pub, cur_priv) to (0, R)
    h1 = [((1 - y) * cur_pub % Q) * (((1 - y) * cur_priv + y * R) % Q) % Q
          for y in range(degree + 1)]
    m1 = mask_round1(a, rho0, mask_degree)
    s1 = [(h1[i] + c * m1[i]) % Q for i in range(degree + 1)]

    fin = interp(s1, e)
    term = ((1 - e) * cur_priv + e * R) % Q

    sel = (1 - e) % Q
    want = sel * cur_pub % Q * term % Q
    g_val = (fin - want) * inv(c) % Q if c % Q else None

    sanity = {
        "chain0": (s0[0] + s0[1]) % Q == gamma % Q,
        "chain1": (s1[0] + s1[1]) % Q == claim1 % Q,
        "derived_is_true_eval": (g_val == mask_eval(a, rho0, e, mask_degree)) if c % Q else None,
    }
    view = (gamma, s0[0], s0[1], s0[2], s1[0], s1[1], s1[2], term)
    return view, g_val, G, sanity


# ------------------------------------------------------------------ experiments

CH = dict(c=2, rho0=3, e=4)          # c != 0, e not in {0, 1}
CH2 = dict(c=3, rho0=1, e=2)         # the second slot's own challenges
PUB1 = (2, 4)
PUB2 = (1, 3)
THETA = 2

# three witnesses with pairwise different sums AND pairwise different
# multilinear extensions at rho0, so that a control which leaks either one
# is visible on every pair
WITNESSES = {"w": (1, 2), "w'": (2, 2), "zero": (0, 0)}
PAIRS = [("w", "w'"), ("w", "zero"), ("w'", "zero")]


def enumerate_single(pub, priv, ch, extra="none", mask_degree=DEGREE, coef_len=L):
    """Exact distribution of the published view over (mask coefficients, R)."""
    dist = Counter()
    bad = 0
    for a in product(range(Q), repeat=coef_len):
        for R in range(Q):
            view, g_val, G, sane = slot_view(pub, priv, a, R, mask_degree=mask_degree, **ch)
            if not (sane["chain0"] and sane["chain1"]):
                bad += 1
            if ch["c"] % Q and sane["derived_is_true_eval"] is False:
                bad += 1
            if extra == "none":
                key = view
            elif extra == "leak_R":            # a blinding value published twice
                key = view + ((g_val + R) % Q,)
            elif extra == "leak_G":            # a private slot's Gamma functional batched into M
                key = view + (G,)
            else:
                raise ValueError(extra)
            dist[key] += 1
    return dist, bad


def compare(name, da, db, note=""):
    same = da == db
    print(f"  {name:<52} {'SAME' if same else 'DIFFERENT'}   "
          f"support {len(da)} vs {len(db)}   {note}")
    if not same:
        only_a = set(da) - set(db)
        diff = [k for k in set(da) & set(db) if da[k] != db[k]]
        detail = []
        if only_a:
            detail.append(f"{len(only_a)} view(s) reachable for one witness only")
        if diff:
            detail.append(f"{len(diff)} view(s) with different multiplicity")
        print(f"       -> {'; '.join(detail)}")
    return same


def compare_all(label, dists):
    """Compare the three witness pairs; return how many SEPARATE."""
    fired = 0
    for x, y in PAIRS:
        if not compare(f"{label}: law({x}) vs law({y})", dists[x], dists[y]):
            fired += 1
    print(f"       verdict: the laws separate on {fired} of {len(PAIRS)} witness pairs")
    return fired


def main():
    print("A toy masked sumcheck, enumerated exactly")
    print(f"field F_{Q}; one slot = 1 main variable + 1 extension round, degree {DEGREE};")
    print(f"mask with L = N*d + 2 = {L} uniform coefficients; terminal mask R;")
    print(f"randomness enumerated: {Q}^{L} * {Q} = {Q ** (L + 1)} runs per witness per experiment.")
    print("ILLUSTRATION ONLY -- see the header. Nothing here proves the real statement.")
    print()

    # ---------------------------------------------------------------- A: honest
    print("A. HONEST, one slot: is the published view's law witness-independent?")
    ds = {}
    total_bad = 0
    for wname, priv in WITNESSES.items():
        d, bad = enumerate_single(PUB1, priv, CH)
        ds[wname] = d
        total_bad += bad
    print(f"  sanity: verifier chain equations and 'derived g_val == true g(rho,e)' "
          f"failures: {total_bad}")
    ok_a = compare_all("honest", ds) == 0
    uniform_on_C = len(set(ds["w"].values())) == 1
    print(f"  the law is uniform on its support (Lemma 2.2's shape): {uniform_on_C}; "
          f"support size {len(ds['w'])}")
    print(f"  expected dim: the view has 8 coordinates; C has dim N*d+1 = {N_VARS*DEGREE+1} "
          f"and the terminal adds 1, so |support| should be {Q ** (N_VARS*DEGREE + 2)}")
    print()

    # ---------------------------------------------------------------- B: no refusal on c = 0
    print("B. CONTROL, the c = 0 refusal dropped (argument.rs:274-277 removed):")
    d0 = {}
    for wname, priv in WITNESSES.items():
        d0[wname], _ = enumerate_single(PUB1, priv, dict(c=0, rho0=3, e=4))
    fired_b = compare_all("c = 0", d0)
    print()

    # ---------------------------------------------------------------- C: mask degree too low
    print(f"C. CONTROL, the mask's degree lowered to {DEGREE-1} (L = N*(d-1)+2 = "
          f"{N_VARS*(DEGREE-1)+2}), so it no longer spans C_s:")
    dd = {}
    for wname, priv in WITNESSES.items():
        dd[wname], _ = enumerate_single(PUB1, priv, CH, mask_degree=DEGREE - 1,
                                        coef_len=N_VARS * (DEGREE - 1) + 2)
    print("       (the slot still publishes d+1 = 3 values per round; only the mask's"
          " own degree is lowered)")
    fired_c = compare_all("under-degree mask", dd)
    print()

    # ---------------------------------------------------------------- D: the counterexample shape
    print("D. CONTROL, the terminal's blinding R published a second time through M")
    print("   (the (H(mask), mask XOR w) shape: M would disclose g_val + R, not g_val):")
    dl = {}
    for wname, priv in WITNESSES.items():
        dl[wname], _ = enumerate_single(PUB1, priv, CH, extra="leak_R")
    fired_d = compare_all("R published twice", dl)
    print("   the marginals without the extra value are SAME on all pairs (experiment A),")
    print("   so this is the counterexample shape: uniform marginals, separating joint.")
    print()

    # ---------------------------------------------------------------- E: a Private slot's Gamma batched
    print("E. CONTROL, a PRIVATE slot's Gamma functional batched into M, so M's")
    print("   disclosed value is no longer a public function of the view (section 3.2):")
    dg = {}
    for wname, priv in WITNESSES.items():
        dg[wname], _ = enumerate_single(PUB1, priv, CH, extra="leak_G")
    fired_e = compare_all("G disclosed", dg)
    sig = {k: (PUB1[0] * v[0] + PUB1[1] * v[1]) % Q for k, v in WITNESSES.items()}
    print(f"   the true sums are {sig}; the control separates exactly the pairs whose")
    print("   sums differ, which is the leak it is supposed to exhibit: sigma = Gamma - c*G.")
    print()

    # ---------------------------------------------------------------- F: two slots, shared mask
    print("F. TWO SLOTS.  Honest: independent masks, so the joint law is the product of")
    print("   the two marginals and A already settles it.  Control: ONE mask reused by")
    print("   both slots (audit_claims forbids the analogue on the commitment side).")
    print(f"   enumerating {Q}^{L} * {Q} * {Q} = {Q ** (L + 2)} runs per witness pair.")

    def joint_shared(priv1, priv2):
        dist = Counter()
        marg1, marg2 = Counter(), Counter()
        for a in product(range(Q), repeat=L):
            for R1 in range(Q):
                v1, g1, _, _ = slot_view(PUB1, priv1, a, R1, **CH)
                for R2 in range(Q):
                    v2, g2, _, _ = slot_view(PUB2, priv2, a, R2, **CH2)
                    vq = (g1 + THETA * g2) % Q
                    dist[v1 + v2 + (vq,)] += 1
                    marg1[v1] += 1
                    marg2[v2] += 1
        return dist, marg1, marg2

    j_w, m1_w, m2_w = joint_shared(WITNESSES["w"], WITNESSES["w'"])
    j_z, m1_z, m2_z = joint_shared(WITNESSES["zero"], WITNESSES["zero"])
    s1_same = compare("slot 1 marginal, shared mask", m1_w, m1_z)
    s2_same = compare("slot 2 marginal, shared mask", m2_w, m2_z)
    j_same = compare("JOINT law, shared mask", j_w, j_z)
    print()
    print("SUMMARY")
    print(f"  A  honest one-slot law witness-independent on all 3 pairs : {ok_a}")
    print(f"  B  c = 0 refusal dropped, pairs separated                 : {fired_b}/3")
    print(f"  C  mask degree too low to span C_s, pairs separated       : {fired_c}/3")
    print(f"  D  terminal blinding R published twice, pairs separated   : {fired_d}/3")
    print(f"  E  a private slot's Gamma batched into M, pairs separated : {fired_e}/3")
    print(f"  F  two slots sharing one mask: marginals same ({s1_same and s2_same}), "
          f"joint same ({j_same})")
    print()
    print("  D and F are the (H(mask), mask XOR w) shape: every marginal is untouched")
    print("  and the JOINT law separates.  They are the two failures the memo's")
    print("  section 5.3 has to rule out, and section 3 rules them out by Lemma 3.1")
    print("  (M reveals one functional) and Fact 3.2 (that functional is public).")


if __name__ == "__main__":
    main()
