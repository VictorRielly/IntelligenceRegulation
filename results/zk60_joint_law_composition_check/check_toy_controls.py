#!/usr/bin/env python3
"""Adversarial controls the delegated draft did NOT run.

For ZK60_JOINT_LAW_COMPOSITION_CHECK.md, attack 7.  The toy is the same
shape as the draft's (one main variable, one extension round, degree 2, one
public and one private table, a CFS mask with L = N d + 2 coefficients, a
reserved-pair value R masking the terminal, the published scalar sigma + c G,
d + 1 published values per round, the verifier's derived
g_val = (fin - poly(terminals)) / c) -- but the model is re-coded here from
the Rust, not imported, so an error in the draft's model does not propagate.

Controls added here (predictions recorded in the check document BEFORE the run):

  G1  the mask evaluation disclosed through M, i.e. the view PLUS g_val
      -- the honest form of Lemma 3.1 + Fact 3.2 at one slot.  PREDICT SAME.
  G2  only d values per round published (drop X = d from the view).
      PREDICT SAME -- strictly less is published, so this cannot separate,
      which is why the draft's section 7.1 RESULT 4 does not show what it says.
  G3  d + 2 values per round (the round polynomial also evaluated at X = d+1).
      PREDICT SAME -- the extra value is determined, degree d.
  G4  TWO slots, independent masks, ONE reserved pair shared by both
      terminals (what audit_claims forbids), plus the theta-batched M value.
      PREDICT marginals SAME, JOINT DIFFERENT.
  G5  G4 without the theta-batched value -- isolates the shared pair.
  G6  TWO slots hosting EACH OTHER (a hosted slot before its host):
      kappa0*kappa1 != 1 -- PREDICT SAME (any invertible change of claimed-sum
      coordinates preserves "uniform on C"); kappa0*kappa1 == 1 -- PREDICT no
      honest prover exists (a completeness failure, not a leak).
  G7  honest TWO slots, independent masks, plus the theta-batched M value.
      PREDICT SAME.

No witness value, salt or private plane is read.
"""

from collections import Counter
from itertools import product

N_VARS, DEGREE = 2, 2
L = N_VARS * DEGREE + 2  # 6


class F:
    def __init__(self, q):
        self.q = q

    def inv(self, a):
        return pow(a % self.q, self.q - 2, self.q)

    def interp(self, vals, x):
        q, d = self.q, len(vals) - 1
        out = 0
        for i in range(d + 1):
            num, den = 1, 1
            for m in range(d + 1):
                if m != i:
                    num = num * (x - m) % q
                    den = den * (i - m) % q
            out = (out + vals[i] * num * self.inv(den)) % q
        return out


def g_at(f, a, xs, degree=DEGREE):
    q = f.q
    acc, pr = a[0], 1
    for x in xs:
        pr = pr * x % q
    acc = (acc + a[1] * pr) % q
    for i, x in enumerate(xs):
        xp = 1
        for e in range(1, degree + 1):
            xp = xp * x % q
            acc = (acc + a[2 + i * degree + e - 1] * xp) % q
    return acc % q


def mask_total(f, a):
    return sum(g_at(f, a, [x1, x2]) for x1 in (0, 1) for x2 in (0, 1)) % f.q


def mle1(f, t, x):
    return (t[0] + x * (t[1] - t[0])) % f.q


def slot(f, pub, priv, a, R, c, rho0, e, n_points=DEGREE + 1, host_term=0):
    """One masked slot.  Returns a dict of everything the receipt carries.

    `host_term` is subtracted from the published scalar (the host form
    Gamma = c G - sum kappa c_h G_h); the verifier adds it back.
    `n_points` is how many evaluations per round the receipt carries.
    """
    q = f.q
    sigma = (pub[0] * priv[0] + pub[1] * priv[1]) % q
    G = mask_total(f, a)
    gamma = (sigma + c * G - host_term) % q
    claim0 = (sigma + c * G) % q  # what the verifier reconstructs

    pts = list(range(n_points))
    h0 = [mle1(f, pub, x) * mle1(f, priv, x) % q for x in pts]
    m0 = [sum(g_at(f, a, [x, x2]) for x2 in (0, 1)) % q for x in pts]
    s0 = [(h0[i] + c * m0[i]) % q for i in range(n_points)]

    claim1 = f.interp(s0[:DEGREE + 1], rho0)
    cp, cv = mle1(f, pub, rho0), mle1(f, priv, rho0)
    h1 = [((1 - y) * cp % q) * (((1 - y) * cv + y * R) % q) % q for y in pts]
    m1 = [g_at(f, a, [rho0, y]) for y in pts]
    s1 = [(h1[i] + c * m1[i]) % q for i in range(n_points)]

    fin = f.interp(s1[:DEGREE + 1], e)
    term = ((1 - e) * cv + e * R) % q
    want = (1 - e) % q * cp % q * term % q
    g_val = (fin - want) * f.inv(c) % q
    ok = ((s0[0] + s0[1]) % q == claim0 % q and (s1[0] + s1[1]) % q == claim1 % q
          and g_val == g_at(f, a, [rho0, e]))
    return {"view": (gamma,) + tuple(s0) + tuple(s1) + (term,), "g": g_val, "G": G, "ok": ok}


def compare(name, da, db):
    same = da == db
    print(f"  {name:<58} {'SAME' if same else 'DIFFERENT'}  supports {len(da)} / {len(db)}")
    return same


# ---------------------------------------------------------------- single slot, F_5
def single(q=5, c=2, rho0=3, e=4):
    f = F(q)
    pub = (2, 4)
    wits = {"w": (1, 2), "w'": (2, 2), "zero": (0, 0)}
    print(f"SINGLE SLOT over F_{q}, c={c}, rho0={rho0}, e={e}; "
          f"randomness {q}^{L} * {q} = {q ** (L + 1)} runs per witness")
    kinds = {"G1 view + g_val (M discloses V)": "plus_g",
             "G2 only d values per round": "drop_last",
             "G3 d + 2 values per round": "extra_point",
             "baseline (the draft's experiment A)": "plain"}
    bad = 0
    for label, kind in kinds.items():
        dists = {}
        for wn, priv in wits.items():
            dd = Counter()
            n_points = DEGREE + 2 if kind == "extra_point" else DEGREE + 1
            for a in product(range(q), repeat=L):
                for R in range(q):
                    s = slot(f, pub, priv, a, R, c, rho0, e, n_points=n_points)
                    if not s["ok"]:
                        bad += 1
                    v = s["view"]
                    if kind == "plus_g":
                        v = v + (s["g"],)
                    elif kind == "drop_last":
                        # the view minus s0[d] and s1[d]
                        v = (v[0],) + v[1:3] + v[4:6] + (v[7],)
                    dd[v] += 1
            dists[wn] = dd
        fired = 0
        for x, y in [("w", "w'"), ("w", "zero"), ("w'", "zero")]:
            if not compare(f"{label}: {x} vs {y}", dists[x], dists[y]):
                fired += 1
        print(f"      -> separates on {fired} of 3 pairs")
    print(f"  sanity failures (chain + derived-g identity): {bad}")
    print()


# ---------------------------------------------------------------- two slots, F_3
def two_slot(q=3):
    f = F(q)
    ch1 = dict(c=1, rho0=2, e=2)
    ch2 = dict(c=2, rho0=1, e=2)
    pub1, pub2 = (2, 1), (1, 2)
    theta = 2
    wa = {"s1": (1, 2), "s2": (2, 1)}
    wb = {"s1": (0, 0), "s2": (0, 0)}
    print(f"TWO SLOTS over F_{q}; per slot randomness {q}^{L} * {q} = {q ** (L + 1)}")

    def table(pub, priv, ch):
        """(a, R) -> slot dict, precomputed."""
        out = {}
        for a in product(range(q), repeat=L):
            for R in range(q):
                out[(a, R)] = slot(f, pub, priv, a, R, **ch)
        return out

    def run(wits, shared_R, with_v):
        t1 = table(pub1, wits["s1"], ch1)
        t2 = table(pub2, wits["s2"], ch2)
        joint, m1, m2 = Counter(), Counter(), Counter()
        if shared_R:
            for R in range(q):
                l1 = [t1[(a, R)] for a in product(range(q), repeat=L)]
                l2 = [t2[(a, R)] for a in product(range(q), repeat=L)]
                for s1 in l1:
                    for s2 in l2:
                        key = s1["view"] + s2["view"]
                        if with_v:
                            key = key + ((s1["g"] + theta * s2["g"]) % q,)
                        joint[key] += 1
                        m1[s1["view"]] += 1
                        m2[s2["view"]] += 1
        else:
            d1, d2 = Counter(), Counter()
            for k, s in t1.items():
                d1[(s["view"], s["g"])] += 1
            for k, s in t2.items():
                d2[(s["view"], s["g"])] += 1
            for (v1, g1), n1 in d1.items():
                for (v2, g2), n2 in d2.items():
                    key = v1 + v2
                    if with_v:
                        key = key + ((g1 + theta * g2) % q,)
                    joint[key] += n1 * n2
                    m1[v1] += n2 * n1
                    m2[v2] += n1 * n2
        return joint, m1, m2

    for label, shared, withv in [
        ("G7 honest, independent masks and pairs, + theta-batched V", False, True),
        ("G4 ONE reserved pair shared by the two terminals, + V", True, True),
        ("G5 ONE reserved pair shared, no V", True, False),
    ]:
        ja, m1a, m2a = run(wa, shared, withv)
        jb, m1b, m2b = run(wb, shared, withv)
        print(f" {label}")
        compare("   slot 1 marginal", m1a, m1b)
        compare("   slot 2 marginal", m2a, m2b)
        compare("   JOINT", ja, jb)
    print()


# ------------------------------------------------- G6: hosting cycles, F_3
def hosting_cycle(q=3):
    """Two slots hosting each other: A_0 = Gamma_0 + k0 Gamma_1,
    A_1 = Gamma_1 + k1 Gamma_0, with A_s the honest masked total.
    The prover must solve M (Gamma) = (A) with M = [[1,k0],[k1,1]]."""
    f = F(q)
    ch1 = dict(c=1, rho0=2, e=2)
    ch2 = dict(c=2, rho0=1, e=2)
    pub1, pub2 = (2, 1), (1, 2)
    wa = {"s1": (1, 2), "s2": (2, 1)}
    wb = {"s1": (0, 0), "s2": (0, 0)}
    print(f"G6 CYCLIC HOSTING over F_{q} (a hosted slot placed BEFORE its host)")
    for k0, k1 in [(1, 2), (1, 1)]:
        det = (1 - k0 * k1) % q
        if det == 0:
            print(f"   kappa0={k0} kappa1={k1}: det(1 - k0 k1) = 0 -- the scalar system")
            print("     M (Gamma_0, Gamma_1) = (A_0, A_1) is SINGULAR: for a generic")
            print("     witness there is NO honest prover at all (a completeness")
            print("     failure), and when a solution exists it is not unique, so the")
            print("     claimed-sum coordinates are not a change of basis.")
            continue
        dists = {}
        iv = f.inv(det)
        for name, wits in [("A", wa), ("B", wb)]:
            # collapse each slot to (its honest masked total A, the rest of its view)
            c1, c2 = Counter(), Counter()
            for a in product(range(q), repeat=L):
                for R in range(q):
                    s = slot(f, pub1, wits["s1"], a, R, **ch1)
                    c1[(s["view"][0], s["view"][1:])] += 1
                    s = slot(f, pub2, wits["s2"], a, R, **ch2)
                    c2[(s["view"][0], s["view"][1:])] += 1
            dd = Counter()
            for (A0, rest0), n0 in c1.items():
                for (A1, rest1), n1 in c2.items():
                    G0 = (A0 - k0 * A1) * iv % q
                    G1 = (A1 - k1 * A0) * iv % q
                    dd[(G0, G1) + rest0 + rest1] += n0 * n1
            dists[name] = dd
        compare(f"   kappa0={k0} kappa1={k1} (det != 0): law(A) vs law(B)", dists["A"], dists["B"])
    print()


if __name__ == "__main__":
    single()
    two_slot()
    hosting_cycle()
