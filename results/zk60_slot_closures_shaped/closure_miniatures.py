#!/usr/bin/env python3
"""GENERIC-INSTANCE miniatures for the shaped slot closures.

What each miniature runs is the REAL mechanism, ported line by line from lane
commit 8c5922b:

  argument.rs:173-182  claim_point        argument.rs:186-219  priv_table
  argument.rs:221-231  table_of           argument.rs:252-278  mask_eval / build_claim
  argument.rs:299-442  run_slot           argument.rs:734-745  PadTerm::eval
  argument.rs:1126-1187 SC_SCORE / SC_PV as REPAIRED by stage 20
  zkp-core/src/sumcheck.rs:47-131 prove, :135-160 verify,
                          :255-274 CfsMask::round, :297-314 extension_round
                          and masked_terminal

on GENERIC data: every plane word and every challenge is a fresh random field
element from a named seed, several seeds, and the instances are checked to be
NON-degenerate (a degenerate instance is the exact trap that hid finding
S19-F1 from a design memo, its adversarial check and a code review).

What is checked, per miniature:

  P1  the CONSTRUCTION PREMISE  poly(exts) = 0  at EVERY extension round;
  P2  T'(w, pi) in C_s -- the verifier's own chain accepts the honest
      unmasked-plus-extension transcript -- for arbitrary pi, NOT only honest
      pi (Theorem 3.3 needs it for every pi);
  P3  rank R_s = N_s d_s + 1 = dim C_s and dim ker R_s = 1, at the slot's own
      shaped (N, d);
  P4  the derived-value identity: the verifier's  g = (fin - poly(vals))/c
      equals the mask's own g(rho_full)  --  (H4)'s sentence 1;
  P5  the terminal decomposition  m_t = cd * T_t(point) + cm_t * P_t  with
      cd = prod(1-e) and cm_t = e_{r} * prod_{j>r}(1-e_j), and every
      coefficient nonzero under the slot's own refusals;
  P6  the witness enters the published sumcheck channel only inside C_s:
      T'(w, pi) - T'(w', pi') lies in Im R_s for every pair tested.

and the controls that give the checks teeth (C1..C5 below).

Nothing here is a privacy claim. The miniature models ONE slot's published
field values at FIXED challenges; it does not model the PCS openings, the
mask commitment M, the hash layer, or a run.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fp2 as F

OUT = os.path.dirname(os.path.abspath(__file__))
HALF = pow(2, F.P - 2, F.P)

# ------------------------------------------------------------------ mle.rs


def eq_table_msb(point):
    """mle.rs: the eq tensor of `point`, most-significant coordinate first —
    the FIRST entry of `point` is the HIGH bit of the index."""
    t = [F.ONE]
    for p in point:
        nt = []
        for v in t:
            nt.append(F.mul(v, F.sub(F.ONE, p)))
            nt.append(F.mul(v, p))
        t = nt
    return t


def eq_point(point, x):
    acc = F.ONE
    for p, xi in zip(point, x):
        acc = F.mul(acc, F.add(F.mul(p, xi), F.mul(F.sub(F.ONE, p), F.sub(F.ONE, xi))))
    return acc


def eval_mle_ext(v, rho):
    e = eq_table_msb(rho)
    acc = F.ZERO
    for a, b in zip(v, e):
        acc = F.add(acc, F.mul(a, b))
    return acc


def interpolate_eval(vals, x):
    return F.interpolate_eval(vals, x)


# --------------------------------------------------------- argument.rs tables
RHO, FLIP, FIXED = 0, 1, 2


def priv_table(coords, log, plane, n_vars):
    """argument.rs:186-219, verbatim. `plane` is a list of base-field ints."""
    fixed = [c[1] for c in coords if c[0] == FIXED]
    eqf = eq_table_msb(fixed)
    used = 0
    for c in coords:
        if c[0] in (RHO, FLIP):
            used |= 1 << (n_vars - 1 - c[1])
    out = [F.ZERO] * (1 << n_vars)
    for idx in range(1 << log):
        x, z = 0, 0
        for j, c in enumerate(coords):
            b = (idx >> (log - 1 - j)) & 1
            if c[0] == RHO:
                x |= b << (n_vars - 1 - c[1])
            elif c[0] == FLIP:
                x |= (1 - b) << (n_vars - 1 - c[1])
            else:
                z = (z << 1) | b
        v = F.base(plane[idx])
        out[x] = F.add(out[x], F.mul(eqf[z], v))
    for x in range(len(out)):
        if x & ~used & ((1 << n_vars) - 1) != 0:
            out[x] = out[x & used]
    return out


def eq_table_over_cube(point, start, n_vars):
    """argument.rs:223-227 (Tab::Eq)"""
    e = eq_table_msb(point)
    shift = n_vars - start - len(point)
    return [e[(x >> shift) & (len(e) - 1)] for x in range(1 << n_vars)]


# ----------------------------------------------------------------- CfsMask
def mask_len(n, d):
    return n * d + 2


def mask_sum_weights(n, d):
    w = [F.base(pow(2, n - 1, F.P))] * mask_len(n, d)
    w = list(w)
    w[0] = F.base(pow(2, n, F.P))
    w[1] = F.ONE
    return w


def mask_eval_weights(rho, d):
    w = [F.ONE]
    p = F.ONE
    for r in rho:
        p = F.mul(p, r)
    w.append(p)
    for r in rho:
        xp = F.ONE
        for _ in range(d):
            xp = F.mul(xp, r)
            w.append(xp)
    return w


def mask_round(a, n, d, j, prev):
    def u(i, x):
        acc = F.ZERO
        xp = F.ONE
        for e in range(1, d + 1):
            xp = F.mul(xp, x)
            acc = F.add(acc, F.mul(a[2 + i * d + (e - 1)], xp))
        return acc

    b = a[0]
    for i, r in enumerate(prev):
        b = F.add(b, u(i, r))
    for i in range(j + 1, n):
        b = F.add(b, F.scal(u(i, F.ONE), HALF))
    scale = F.base(pow(2, n - 1 - j, F.P))
    pp = F.ONE
    for r in prev:
        pp = F.mul(pp, r)
    return [F.add(F.mul(scale, F.add(b, u(j, F.base(x)))),
                  F.mul(F.mul(a[1], pp), F.base(x))) for x in range(d + 1)]


def dot(w, a):
    acc = F.ZERO
    for x, y in zip(w, a):
        acc = F.add(acc, F.mul(x, y))
    return acc


# ------------------------------------------------------------- the slot run
class Slot:
    """One slot definition: tables + closure + declared (main, ext, degree)."""

    def __init__(self, tabs, poly, degree, ext):
        # tabs: list of ("eq", table) | ("pub", table) | ("priv", table, ext_round)
        self.tabs = tabs
        self.poly = poly
        self.degree = degree
        self.ext = ext
        self.n = (len(tabs[0][1]) - 1).bit_length()
        assert all(len(t[1]) == 1 << self.n for t in tabs)

    def values(self):
        return [t[1] for t in self.tabs]

    def total(self):
        acc = F.ZERO
        vals = self.values()
        for x in range(1 << self.n):
            acc = F.add(acc, self.poly([v[x] for v in vals]))
        return acc


def sumcheck_prove(tables, degree, poly, rho):
    """sumcheck.rs:47-131 with the challenges supplied (fixed-challenge world)."""
    tabs = [list(t) for t in tables]
    n_rounds = (len(tabs[0]) - 1).bit_length()
    assert len(rho) == n_rounds
    rounds = []
    ln = len(tabs[0])
    for rd in range(n_rounds):
        half = ln // 2
        acc = [F.ZERO] * (degree + 1)
        for i in range(half):
            cur = [t[i] for t in tabs]
            dif = [F.sub(t[i + half], t[i]) for t in tabs]
            acc[0] = F.add(acc[0], poly(cur))
            for d in range(1, degree + 1):
                cur = [F.add(c, dd) for c, dd in zip(cur, dif)]
                acc[d] = F.add(acc[d], poly(cur))
        rounds.append(acc)
        r = rho[rd]
        for t in tabs:
            for i in range(half):
                t[i] = F.add(t[i], F.mul(r, F.sub(t[i + half], t[i])))
            del t[half:]
        ln = half
    return rounds, [t[0] for t in tabs]


def extension_round(finals, exts, degree, poly):
    """sumcheck.rs:297-309"""
    out = []
    for x in range(degree + 1):
        xv = F.base(x)
        v = [F.add(f, F.mul(xv, F.sub(e, f))) for f, e in zip(finals, exts)]
        out.append(poly(v))
    return out


def masked_terminal(fin, ext, r):
    return F.add(fin, F.mul(r, F.sub(ext, fin)))


def run_slot(slot, c, a, rho, es, pmask, hosted_scalar=F.ZERO, kind="private"):
    """argument.rs:299-442, prover side, at FIXED challenges.

    `pmask[i]` is the reserved pair's value for private table i (the
    `mask_eval` of argument.rs:252-261, an Fp2 element); `a` the slot's mask
    coefficients; `c` the CFS multiplier.
    Returns the published view and the intermediates the checks need.
    """
    n, ext, degree = slot.n, slot.ext, slot.degree
    N = n + ext
    assert len(a) == mask_len(N, degree)
    assert len(rho) == n and len(es) == ext
    g_total = dot(mask_sum_weights(N, degree), a)
    honest_sum = slot.total()
    if kind == "private":
        scalar = F.add(honest_sum, F.mul(c, g_total))
    elif kind == "standalone":
        scalar = F.mul(c, g_total)
    else:
        scalar = F.add(F.mul(c, g_total), hosted_scalar)
    rounds, finals = sumcheck_prove(slot.values(), degree, slot.poly, rho)
    # mask the main rounds: sumcheck.rs:284-294 through the transcript masker
    masked = []
    for j in range(n):
        gj = mask_round(a, N, degree, j, rho[:j])
        masked.append([F.add(s, F.mul(c, g)) for s, g in zip(rounds[j], gj)])
    cur = list(finals)
    prev = list(rho)
    premise = []
    for m in range(ext):
        exts = []
        k = 0
        for t in slot.tabs:
            if t[0] == "priv":
                exts.append(pmask[k] if t[2] == m else F.ZERO)
                k += 1
            else:
                exts.append(F.ZERO)
        premise.append(slot.poly(exts))          # P1: must be ZERO
        sk = extension_round(cur, exts, degree, slot.poly)
        gk = mask_round(a, N, degree, len(prev), prev)
        sk = [F.add(x, F.mul(c, g)) for x, g in zip(sk, gk)]
        masked.append(sk)
        e = es[m]
        cur = [masked_terminal(v, x, e) for v, x in zip(cur, exts)]
        prev.append(e)
    terms = [v for t, v in zip(slot.tabs, cur) if t[0] == "priv"]
    g_val = dot(mask_eval_weights(prev, degree), a)
    return {"scalar": scalar, "rounds": masked, "terms": terms, "prev": prev,
            "finals": finals, "premise": premise, "g_total": g_total,
            "g_val": g_val, "honest_sum": honest_sum}


def verify_slot(slot, c, view, claimed, rho, es):
    """argument.rs:373-399 + sumcheck.rs:135-160. Returns (ok, why, g_val)."""
    n, ext, degree = slot.n, slot.ext, slot.degree
    claim = claimed
    for j, s in enumerate(view["rounds"]):
        if len(s) != degree + 1:
            return False, "round %d length" % j, None
        if F.add(s[0], s[1]) != claim:
            return False, "round %d: s(0)+s(1) != claim" % j, None
        r = (rho + es)[j]
        claim = interpolate_eval(s, r)
    fin = claim
    sel = F.ONE
    for e in es:
        sel = F.mul(sel, F.sub(F.ONE, e))
    vals, k = [], 0
    for t in slot.tabs:
        if t[0] == "priv":
            vals.append(view["terms"][k])
            k += 1
        elif t[0] == "eq":
            vals.append(F.mul(sel, eval_mle_ext(t[1], rho)))
        else:
            vals.append(F.mul(sel, eval_mle_ext(t[1], rho)))
    g = F.mul(F.sub(fin, slot.poly(vals)), F.inv(c))
    return True, "", g


def round_map_columns(N, degree, rho_full):
    L = mask_len(N, degree)
    cols = []
    for i in range(L):
        e = [F.ZERO] * L
        e[i] = F.ONE
        v = []
        for j in range(N):
            v.extend(mask_round(e, N, degree, j, rho_full[:j]))
        cols.append(v)
    return cols


# ---------------------------------------------------------------- miniature A
def build_score_slot(rng, lt, lh, lkv, ldh, plane_q=None, plane_k=None,
                     repaired=True):
    """SC_SCORE (argument.rs:1126-1160) at a miniature geometry.

    Dom::Q = (t, head slot, c), Dom::Kv = (j, kv head, c), the head slot's
    HIGH `lkv` bits being the key-value group (correction C-1).
    `repaired=False` rebuilds the PRE-stage-20 definition, which fixes the
    group on BOTH factors and sums over the inner axis alone.
    """
    lhj = lh - lkv
    logq, logk = lt + lh + ldh, lt + lkv + ldh
    # the DEFINITION challenges first, so that a second witness at the same
    # public statement gets the same public tables
    r_h = rng.fp2_vec(lh)
    r_t = rng.fp2_vec(lt)
    r_j = rng.fp2_vec(lt)
    if plane_q is None:
        plane_q = [rng.fp() for _ in range(1 << logq)]
    if plane_k is None:
        plane_k = [rng.fp() for _ in range(1 << logk)]
    r_g, r_hj = r_h[:lkv], r_h[lkv:]
    if repaired:
        n = lkv + ldh
        cq = ([(FIXED, v) for v in r_t] + [(RHO, k) for k in range(lkv)]
              + [(FIXED, v) for v in r_hj] + [(RHO, k) for k in range(lkv, lkv + ldh)])
        ck = ([(FIXED, v) for v in r_j] + [(RHO, k) for k in range(lkv)]
              + [(RHO, k) for k in range(lkv, lkv + ldh)])
        tabs = [("eq", eq_table_over_cube(r_g, 0, n)),
                ("priv", priv_table(cq, logq, plane_q, n), 0),
                ("priv", priv_table(ck, logk, plane_k, n), 1)]
        poly = lambda v: F.mul(F.mul(v[0], v[1]), v[2])
        degree = 3
    else:
        n = ldh
        cq = ([(FIXED, v) for v in r_t] + [(FIXED, v) for v in r_h]
              + [(RHO, k) for k in range(ldh)])
        ck = ([(FIXED, v) for v in r_j] + [(FIXED, v) for v in r_g]
              + [(RHO, k) for k in range(ldh)])
        tabs = [("priv", priv_table(cq, logq, plane_q, n), 0),
                ("priv", priv_table(ck, logk, plane_k, n), 1)]
        poly = lambda v: F.mul(v[0], v[1])
        degree = 2
    return Slot(tabs, poly, degree, 2), (r_h, r_t, r_j), (plane_q, plane_k)


def true_score_target(plane_q, plane_k, lt, lh, lkv, ldh, r_h, r_t, r_j):
    """score~(r_h, r_t, r_j) where score[h][t][j] = sum_c q[t][h][c]*k[j][g(h)][c]."""
    lhj = lh - lkv
    nt, nh, nc = 1 << lt, 1 << lh, 1 << ldh
    eh, et, ej = eq_table_msb(r_h), eq_table_msb(r_t), eq_table_msb(r_j)
    acc = F.ZERO
    for h in range(nh):
        g = h >> lhj
        for t in range(nt):
            for j in range(nt):
                s = 0
                for c in range(nc):
                    s += plane_q[(t * nh + h) * nc + c] * plane_k[(j * (1 << lkv) + g) * nc + c]
                acc = F.add(acc, F.mul(F.mul(F.mul(eh[h], et[t]), ej[j]), F.base(s)))
    return acc


# ---------------------------------------------------------------- miniature B
def build_padzero_slot(rng, log, n_planes, inside=True, quadratic=True, planes=None):
    """A zero-check slot shaped like SC_TZC / SC_DZC: eq(tau) * [ a quadratic
    private clause + the batched pad-zero term ] + two gated HOST terms.

    `inside=False` is control C4: the pad-zero term placed OUTSIDE the
    eq(tau) bracket, which is the only structural thing that keeps the
    construction premise true for it.
    """
    n = log
    tau = rng.fp2_vec(n)
    p1 = rng.fp2_vec(n)
    p2 = rng.fp2_vec(n)
    i_tau, i_h1, i_h2 = 0, 1, 2
    tabs = [("eq", eq_table_over_cube(tau, 0, n)),
            ("eq", eq_table_over_cube(p1, 0, n)),
            ("eq", eq_table_over_cube(p2, 0, n))]
    # the support indicator: a public 0/1 table with a real pad (pad.rs:48-54)
    supp = [F.ONE if (x % 4) != 3 else F.ZERO for x in range(1 << n)]
    i_supp = len(tabs)
    tabs.append(("pub", supp))
    first_priv = len(tabs)
    mu = rng.fp2_vec(n_planes + 2)
    nu = [rng.fp2_nonzero(), rng.fp2_nonzero()]
    zeta = rng.fp2_nonzero()
    mu_pad = rng.fp2_nonzero()
    if planes is None:
        planes = [[rng.fp() for _ in range(1 << n)] for _ in range(n_planes)]
    for pl in planes:
        # every private plane is read on its own cube (coords = rho(0..n))
        coords = [(RHO, k) for k in range(n)]
        tabs.append(("priv", priv_table(coords, n, pl, n), 0))
    zw = []
    p = F.ONE
    for _ in range(n_planes):
        zw.append(p)
        p = F.mul(p, zeta)

    def poly(v):
        g = v[i_supp]
        d = v[first_priv]
        zc = F.mul(mu[0], F.sub(v[first_priv + 1] if n_planes > 1 else d,
                                F.mul(d, d))) if quadratic else F.mul(mu[0], d)
        for kk in range(1, n_planes):
            zc = F.add(zc, F.mul(mu[kk], F.mul(g, v[first_priv + kk])))
        pz = F.ZERO
        for kk in range(n_planes):
            pz = F.add(pz, F.mul(zw[kk], v[first_priv + kk]))
        pz = F.mul(mu_pad, F.mul(F.sub(F.ONE, g), pz))
        host1 = F.mul(nu[0], F.mul(v[i_h1], F.mul(g, v[first_priv])))
        host2 = F.mul(nu[1], F.mul(v[i_h2], F.mul(g, v[first_priv + n_planes - 1])))
        if inside:
            return F.add(F.add(F.mul(v[i_tau], F.add(zc, pz)), host1), host2)
        return F.add(F.add(F.add(F.mul(v[i_tau], zc), pz), host1), host2)

    return Slot(tabs, poly, 4, 1), planes


# ------------------------------------------------------------------- checks
def check_slot(slot, rng, label, kind="private", n_pi=4, n_wit=0, wit_slots=None):
    """P1..P6 for one slot definition."""
    N = slot.n + slot.ext
    c = rng.fp2_nonzero()
    rho = rng.fp2_vec(slot.n)
    es = []
    for _ in range(slot.ext):
        while True:
            e = rng.fp2_nonzero()
            if e != F.ONE:
                break
        es.append(e)
    a = rng.fp2_vec(mask_len(N, slot.degree))
    n_priv = sum(1 for t in slot.tabs if t[0] == "priv")
    out = {"label": label, "n": slot.n, "ext": slot.ext, "degree": slot.degree,
           "N": N, "L": mask_len(N, slot.degree), "dim_C": N * slot.degree + 1,
           "private_tables": n_priv}

    # P3
    cols = round_map_columns(N, slot.degree, rho + es)
    out["rank_R"] = F.rank_of_columns(cols)
    out["ker_R"] = out["L"] - out["rank_R"]
    out["P3"] = (out["rank_R"] == out["dim_C"] and out["ker_R"] == 1)

    # P1, P2, P4, P5 over several pi (including adversarial pi)
    pis = []
    for _ in range(n_pi):
        pis.append([rng.fp2() for _ in range(n_priv)])
    pis.append([F.ZERO] * n_priv)                      # pi = 0
    if n_priv >= 2:
        z = rng.fp2()
        pis.append([z] * n_priv)                       # equal pair values
    premise_ok, chain_ok, derived_ok, terms_ok = True, True, True, True
    diffs = []
    base_t = None
    for pi in pis:
        v = run_slot(slot, c, a, rho, es, pi, kind=kind)
        if any(not F.is_zero(x) for x in v["premise"]):
            premise_ok = False
        ok, why, g = verify_slot(slot, c, v, v["scalar"], rho, es)
        if not ok:
            chain_ok = False
        elif g != v["g_val"]:
            derived_ok = False
        # P5: the terminal decomposition
        cd = F.ONE
        for e in es:
            cd = F.mul(cd, F.sub(F.ONE, e))
        k = 0
        for t, fin in zip(slot.tabs, v["finals"]):
            if t[0] != "priv":
                continue
            r = t[2]
            cm = es[r]
            for e in es[r + 1:]:
                cm = F.mul(cm, F.sub(F.ONE, e))
            want = F.add(F.mul(cd, fin), F.mul(cm, pi[k]))
            if want != v["terms"][k]:
                terms_ok = False
            if F.is_zero(cm) or F.is_zero(cd):
                terms_ok = False
            k += 1
        # P2 / P6: the UNMASKED transcript in claimed-sum coordinates
        v0 = run_slot(slot, c, [F.ZERO] * out["L"], rho, es, pi, kind=kind)
        t0 = [v0["scalar"]] + [x for r in v0["rounds"] for x in r]
        if base_t is None:
            base_t = t0
        else:
            diffs.append([F.sub(x, y) for x, y in zip(t0, base_t)])
    out["P1_premise_zero"] = premise_ok
    out["P2_chain"] = chain_ok
    out["P4_derived_value"] = derived_ok
    out["P5_terminals"] = terms_ok
    # P6: every (w, pi) difference of the unmasked channel lies in Im R
    ext_cols = [[F.ZERO] + col for col in cols]        # the scalar coordinate
    # the mask's contribution to the scalar of a Private slot is c * G
    sw = mask_sum_weights(N, slot.degree)
    for i in range(len(cols)):
        ext_cols[i][0] = sw[i]
    if wit_slots:
        for s2 in wit_slots:
            v2 = run_slot(s2, c, [F.ZERO] * out["L"], rho, es, pis[0], kind=kind)
            t2 = [v2["scalar"]] + [x for r in v2["rounds"] for x in r]
            diffs.append([F.sub(x, y) for x, y in zip(t2, base_t)])
    r0 = F.rank_of_columns(ext_cols)
    out["P6_rank_ImR"] = r0
    out["P6_rank_ImR_plus_variation"] = F.rank_of_columns(ext_cols + diffs)
    out["P6_disclosed_dimension"] = out["P6_rank_ImR_plus_variation"] - r0
    # the test is only meaningful if the variations are not all zero
    out["P6_rank_of_the_variations_alone"] = F.rank_of_columns(diffs)
    out["P6"] = (out["P6_disclosed_dimension"] == 0
                 and out["P6_rank_of_the_variations_alone"] > 0)
    out["n_pi_tested"] = len(pis)
    out["n_variations"] = len(diffs)
    return out


def main():
    res = {"miniatures": [], "controls": []}

    # ---- A. the two bilinear slots, at one and two group bits
    for lkv, lh, tag in ((1, 2, "rung-G geometry (lkv = 1)"),
                         (2, 3, "rung-K4 / 125M geometry (lkv = 2)")):
        for seed in (11, 12, 13):
            rng = F.Rng(0xB11 * 1000 + seed * 31 + lkv)
            slot, pts, planes = build_score_slot(rng, lt=2, lh=lh, lkv=lkv, ldh=2)
            # a SECOND witness at the same public statement and the same
            # definition challenges, for P6's witness variation
            rw = F.Rng(0xB11 * 1000 + seed * 31 + lkv + 500000)
            alt_q = [rw.fp() for _ in range(len(planes[0]))]
            alt_k = [rw.fp() for _ in range(len(planes[1]))]
            alt, pts_alt, _ = build_score_slot(
                F.Rng(0xB11 * 1000 + seed * 31 + lkv), lt=2, lh=lh, lkv=lkv, ldh=2,
                plane_q=alt_q, plane_k=alt_k)
            assert pts_alt[0] == pts[0], "the second witness must share the statement"
            r = check_slot(slot, rng, "SC_SCORE %s seed %d" % (tag, seed),
                           wit_slots=[alt])
            # completeness: the slot's honest sum IS the score target
            s = slot.total()
            tgt = true_score_target(planes[0], planes[1], 2, lh, lkv, 2, *pts)
            r["honest_sum_equals_the_score_target"] = (s == tgt)
            # non-degeneracy: the PRE-repair definition must DISAGREE here
            rng2 = F.Rng(0xB11 * 1000 + seed * 31 + lkv)
            old, pts2, planes2 = build_score_slot(rng2, lt=2, lh=lh, lkv=lkv, ldh=2,
                                                  repaired=False)
            r["pre_repair_sum_differs_on_this_instance"] = (old.total() != tgt)
            res["miniatures"].append(r)

    for lkv, lh, tag in ((1, 2, "rung-G geometry (lkv = 1)"),
                         (2, 3, "rung-K4 / 125M geometry (lkv = 2)")):
        for seed in (21, 22):
            rng = F.Rng(0xB22 * 1000 + seed * 31 + lkv)
            # SC_PV: A_P on Dom::S = (slot, t, s), A_V8 on Dom::Kv = (s, g, i)
            lt, ldh = 2, 2
            lhj = lh - lkv
            logp, logv = lh + lt + lt, lt + lkv + ldh
            plane_p = [rng.fp() for _ in range(1 << logp)]
            plane_v = [rng.fp() for _ in range(1 << logv)]
            r_h, r_t, r_i = rng.fp2_vec(lh), rng.fp2_vec(lt), rng.fp2_vec(ldh)
            r_g, r_hj = r_h[:lkv], r_h[lkv:]
            n = lkv + lt
            cp = ([(RHO, k) for k in range(lkv)] + [(FIXED, v) for v in r_hj]
                  + [(FIXED, v) for v in r_t] + [(RHO, k) for k in range(lkv, lkv + lt)])
            cv = ([(RHO, k) for k in range(lkv, lkv + lt)] + [(RHO, k) for k in range(lkv)]
                  + [(FIXED, v) for v in r_i])
            tabs = [("eq", eq_table_over_cube(r_g, 0, n)),
                    ("priv", priv_table(cp, logp, plane_p, n), 0),
                    ("priv", priv_table(cv, logv, plane_v, n), 1)]
            slot = Slot(tabs, lambda v: F.mul(F.mul(v[0], v[1]), v[2]), 3, 2)
            rw = F.Rng(0xB22 * 1000 + seed * 31 + lkv + 500000)
            alt_p = [rw.fp() for _ in range(1 << logp)]
            alt_v = [rw.fp() for _ in range(1 << logv)]
            alt = Slot([("eq", eq_table_over_cube(r_g, 0, n)),
                        ("priv", priv_table(cp, logp, alt_p, n), 0),
                        ("priv", priv_table(cv, logv, alt_v, n), 1)],
                       lambda v: F.mul(F.mul(v[0], v[1]), v[2]), 3, 2)
            res["miniatures"].append(
                check_slot(slot, rng, "SC_PV %s seed %d" % (tag, seed),
                           wit_slots=[alt]))

    # ---- B. a pad-zero zero-check with a quadratic private clause and hosts
    #
    # The chain is checked with the claimed sum the VERIFIER forms. For a Host
    # slot that is `scalar + sum kappa*scalars[h]`, and the host algebra
    # (argument.rs:345 prover, :379 verifier) makes it equal to
    # `honest total + c * G_host` exactly -- the hosted masks cancel. That
    # cancellation is checked on its own below (P7) and the chain is then run
    # with the same claimed sum a Private slot has.
    for seed in (31, 32, 33):
        rng = F.Rng(0xC33 * 1000 + seed)
        slot, planes = build_padzero_slot(rng, log=4, n_planes=3, inside=True)
        rw = F.Rng(0xC33 * 1000 + seed + 500000)
        alt_planes = [[rw.fp() for _ in pl] for pl in planes]
        alt, _ = build_padzero_slot(F.Rng(0xC33 * 1000 + seed), log=4, n_planes=3,
                                    inside=True, planes=alt_planes)
        res["miniatures"].append(
            check_slot(slot, rng,
                       "pad-zero zero-check (SC_TZC/SC_DZC shape) seed %d" % seed,
                       wit_slots=[alt]))

    # ---- B2. SC_TAB's shape: the pad-zero group spans BOTH commitments
    # (the three A multiplicities [1,4,7] and the three H table helpers
    # [2,5,8], argument.rs:1518-1519), and the closure's `- v[1]` monomial
    # has NO public factor of its own -- only the outer eq(tau).
    for seed in (41, 42):
        rng = F.Rng(0xC44 * 1000 + seed)
        n = 4
        tau = rng.fp2_vec(n)
        alpha = rng.fp2_nonzero()
        mu = rng.fp2_vec(4)
        zeta = rng.fp2_nonzero()
        supp = [F.ONE if (x % 4) != 3 else F.ZERO for x in range(1 << n)]
        coords = [(RHO, k) for k in range(n)]

        def tab_slot(planes):
            tabs = [("eq", eq_table_over_cube(tau, 0, n))]
            for tri in range(3):
                tabs.append(("priv", priv_table(coords, n, planes[2 * tri], n), 0))
                tabs.append(("priv", priv_table(coords, n, planes[2 * tri + 1], n), 0))
                tabs.append(("pub", [F.base((x % 256) + 7 * tri) for x in range(1 << n)]))
            i_supp = len(tabs)
            tabs.append(("pub", supp))

            def poly(v):
                acc = F.ZERO
                for tri in range(3):
                    m, h, val = v[1 + 3 * tri], v[2 + 3 * tri], v[3 + 3 * tri]
                    acc = F.add(acc, F.mul(mu[tri], F.sub(F.mul(h, F.sub(alpha, val)), m)))
                pz = F.ZERO
                p = F.ONE
                for tri in range(3):          # the A group [1, 4, 7]
                    pz = F.add(pz, F.mul(p, v[1 + 3 * tri]))
                    p = F.mul(p, zeta)
                for tri in range(3):          # the H group [2, 5, 8]
                    pz = F.add(pz, F.mul(p, v[2 + 3 * tri]))
                    p = F.mul(p, zeta)
                pz = F.mul(mu[3], F.mul(F.sub(F.ONE, v[i_supp]), pz))
                return F.mul(v[0], F.add(acc, pz))

            return Slot(tabs, poly, 3, 1)

        planes = [[rng.fp() for _ in range(1 << n)] for _ in range(6)]
        rw = F.Rng(0xC44 * 1000 + seed + 500000)
        alt_planes = [[rw.fp() for _ in range(1 << n)] for _ in range(6)]
        res["miniatures"].append(
            check_slot(tab_slot(planes), rng, "SC_TAB shape (A and H in one "
                       "pad-zero group) seed %d" % seed,
                       wit_slots=[tab_slot(alt_planes)]))

    # ---- B3. SC_SZC's shape: TWO pad-zero groups with DIFFERENT indicators
    # (Dom::Ht lifted over the trailing j axis, and Dom::S), and two host
    # terms gated by DIFFERENT indicators (argument.rs:1444-1475).
    for seed in (51, 52):
        rng = F.Rng(0xC55 * 1000 + seed)
        n = 4                                  # (Ht bits | j bits) = 2 | 2
        tau = rng.fp2_vec(n)
        p1, p2 = rng.fp2_vec(n), rng.fp2_vec(n)
        # supp_Ht is constant in the trailing j axis; supp_S is not
        supp_ht = [F.ONE if ((x >> 2) % 4) != 3 else F.ZERO for x in range(1 << n)]
        supp_s = [F.ONE if ((x >> 2) % 4) != 3 and (x % 4) != 3 else F.ZERO
                  for x in range(1 << n)]
        mu = rng.fp2_vec(5)
        nu = [rng.fp2_nonzero(), rng.fp2_nonzero()]
        zeta = rng.fp2_nonzero()
        coords = [(RHO, k) for k in range(n)]

        def szc_slot(planes):
            tabs = [("eq", eq_table_over_cube(tau, 0, n)),
                    ("eq", eq_table_over_cube(p1, 0, n)),
                    ("eq", eq_table_over_cube(p2, 0, n)),
                    ("pub", supp_ht), ("pub", supp_s)]
            fp = len(tabs)
            for pl in planes:
                tabs.append(("priv", priv_table(coords, n, pl, n), 0))

            def poly(v):
                ght, gs = v[3], v[4]
                mx, sm, s8, e = v[fp], v[fp + 1], v[fp + 2], v[fp + 3]
                c0 = F.sub(F.mul(s8, s8), s8)
                c1 = F.sub(F.mul(e, sm), mx)
                zc = F.add(F.mul(mu[0], F.mul(gs, c0)), F.mul(mu[1], F.mul(gs, c1)))
                # group 1: Dom::Ht's two planes under the LIFTED supp_Ht
                pz = F.mul(F.sub(F.ONE, ght),
                           F.add(mx, F.mul(zeta, sm)))
                # group 2: Dom::S's planes, zeta's powers CONTINUING (PadTerm::add)
                z2 = F.mul(zeta, zeta)
                pz = F.add(pz, F.mul(F.sub(F.ONE, gs),
                                     F.add(F.mul(z2, s8), F.mul(F.mul(z2, zeta), e))))
                pz = F.mul(mu[4], pz)
                host_rs = F.mul(nu[0], F.mul(v[1], F.mul(ght, F.add(sm, mu[2]))))
                host_s = F.mul(nu[1], F.mul(v[2], F.mul(gs, F.add(s8, mu[3]))))
                return F.add(F.add(F.mul(v[0], F.add(zc, pz)), host_rs), host_s)

            return Slot(tabs, poly, 4, 1)

        planes = [[rng.fp() for _ in range(1 << n)] for _ in range(4)]
        rw = F.Rng(0xC55 * 1000 + seed + 500000)
        alt_planes = [[rw.fp() for _ in range(1 << n)] for _ in range(4)]
        res["miniatures"].append(
            check_slot(szc_slot(planes), rng,
                       "SC_SZC shape (two indicators, two gated hosts) seed %d" % seed,
                       wit_slots=[szc_slot(alt_planes)]))

    # P7: the host cancellation, at two hosted slots (argument.rs:345, :379)
    rng = F.Rng(0xE77)
    c_h = [rng.fp2_nonzero(), rng.fp2_nonzero()]
    G_h = [rng.fp2(), rng.fp2()]
    s_h = [rng.fp2(), rng.fp2()]
    kappa = [rng.fp2_nonzero(), rng.fp2_nonzero()]
    c_host, G_host, honest = rng.fp2_nonzero(), rng.fp2(), rng.fp2()
    scalar_host = F.mul(c_host, G_host)
    for k, ch, Gh in zip(kappa, c_h, G_h):
        scalar_host = F.sub(scalar_host, F.mul(k, F.mul(ch, Gh)))
    scalars_h = [F.add(s, F.mul(ch, Gh)) for s, ch, Gh in zip(s_h, c_h, G_h)]
    claimed = scalar_host
    for k, sh_ in zip(kappa, scalars_h):
        claimed = F.add(claimed, F.mul(k, sh_))
    want = F.mul(c_host, G_host)
    for k, s in zip(kappa, s_h):
        want = F.add(want, F.mul(k, s))
    res["controls"].append({
        "control": "P7 the host cancellation",
        "claimed_equals_c_G_host_plus_sum_kappa_s": claimed == want,
        "note": "argument.rs:345 subtracts kappa*c_h*G_h from the host's published "
                "scalar and :379 adds back kappa*scalars[h]; the hosted MASK totals "
                "cancel exactly, so the host's claimed sum is (its own honest total) "
                "+ c*G_host and the chain is the Private slot's"})

    # ---- C. controls
    # C1: both private factors extended in the SAME round, with NO public
    # factor -- the toy's own mechanism removed
    rng = F.Rng(0xD01)
    slot, _, _ = build_score_slot(rng, lt=2, lh=2, lkv=1, ldh=2)
    bad = Slot([("priv", slot.tabs[1][1], 0), ("priv", slot.tabs[2][1], 0)],
               lambda v: F.mul(v[0], v[1]), 2, 2)
    r = check_slot(bad, rng, "CONTROL both private factors in extension round 0")
    res["controls"].append({"control": "C1 both factors in one extension round, "
                                       "no public factor",
                            "premise_zero": r["P1_premise_zero"],
                            "chain_holds": r["P2_chain"],
                            "expected": "premise FALSE and chain FALSE"})
    # C1b: the same two factors in DIFFERENT rounds, still with no public
    # factor -- the toy's mechanism, restored
    rng = F.Rng(0xD01)
    slot, _, _ = build_score_slot(rng, lt=2, lh=2, lkv=1, ldh=2)
    good = Slot([("priv", slot.tabs[1][1], 0), ("priv", slot.tabs[2][1], 1)],
                lambda v: F.mul(v[0], v[1]), 2, 2)
    r = check_slot(good, rng, "CONTROL the toy's two-round mechanism")
    res["controls"].append({"control": "C1b the same two factors in rounds 0 and 1",
                            "premise_zero": r["P1_premise_zero"],
                            "chain_holds": r["P2_chain"],
                            "expected": "premise TRUE and chain TRUE"})
    # C2: the group eq dropped (the closure v[1]*v[2] on a cube that sums the
    # shared group bits) -> the slot proves a different sum AND the premise
    # survives only through the different-rounds mechanism
    rng = F.Rng(0xD02)
    slot, pts, planes = build_score_slot(rng, lt=2, lh=2, lkv=1, ldh=2)
    nogeq = Slot(slot.tabs, lambda v: F.mul(v[1], v[2]), 2, 2)
    tgt = true_score_target(planes[0], planes[1], 2, 2, 1, 2, *pts)
    r2 = check_slot(nogeq, rng, "CONTROL group eq dropped")
    res["controls"].append({"control": "C2 the public group eq dropped from the closure",
                            "premise_zero": r2["P1_premise_zero"],
                            "chain_holds": r2["P2_chain"],
                            "honest_sum_equals_target": nogeq.total() == tgt,
                            "expected": "premise TRUE (different rounds), chain TRUE, "
                                        "but the sum is NOT the target: a completeness "
                                        "break, not an (H4) break"})
    # C3: a DEGENERATE witness (every head slot identical) on which the
    # pre-repair definition agrees -- the trap S19-F1 hid behind
    rng = F.Rng(0xD03)
    lt, lh, lkv, ldh = 2, 2, 1, 2
    nt, nh, nc = 1 << lt, 1 << lh, 1 << ldh
    one_head = [rng.fp() for _ in range(nt * nc)]
    deg_q = [one_head[(x // (nh * nc)) * nc + (x % nc)] for x in range(nt * nh * nc)]
    deg_k = [rng.fp() for _ in range(nt * (1 << lkv) * nc)]
    # a key plane that does not vary across groups either
    kv_one = [rng.fp() for _ in range(nt * nc)]
    deg_k = [kv_one[(x // ((1 << lkv) * nc)) * nc + (x % nc)]
             for x in range(nt * (1 << lkv) * nc)]
    rngd = F.Rng(0xD03 + 1)
    s_new, pts3, pl3 = build_score_slot(rngd, lt, lh, lkv, ldh, deg_q, deg_k, True)
    rngd2 = F.Rng(0xD03 + 1)
    s_old, _, _ = build_score_slot(rngd2, lt, lh, lkv, ldh, deg_q, deg_k, False)
    tgt3 = true_score_target(deg_q, deg_k, lt, lh, lkv, ldh, *pts3)
    res["controls"].append({
        "control": "C3 a degenerate witness (no variation across key-value groups)",
        "repaired_equals_target": s_new.total() == tgt3,
        "pre_repair_equals_target": s_old.total() == tgt3,
        "expected": "BOTH true -- which is why a degenerate instance can never "
                    "decide this clause"})
    # C4: the pad-zero term placed OUTSIDE the eq(tau) bracket
    rng = F.Rng(0xD04)
    outside, _ = build_padzero_slot(rng, log=4, n_planes=3, inside=False)
    r4 = check_slot(outside, rng, "CONTROL pad-zero term outside the eq bracket",
                    kind="host")
    res["controls"].append({"control": "C4 the pad-zero term outside eq(tau)",
                            "premise_zero": r4["P1_premise_zero"],
                            "chain_holds": r4["P2_chain"],
                            "expected": "premise FALSE and chain FALSE: the placement "
                                        "inside the bracket is load-bearing for (H4)"})
    # C5: a terminal challenge at 1 (the refusal argument.rs:404-406) kills cd
    res["controls"].append({
        "control": "C5 the refusal on the terminal challenges",
        "note": "argument.rs:404-406 refuses e == 0 and e == 1 for EVERY extension "
                "challenge, so at ext = 2 both cd = (1-e0)(1-e1) and the two pair "
                "coefficients cm_0 = e0(1-e1), cm_1 = e1 are nonzero; at ext = 1 the "
                "same refusal covers the single pair"})

    ok = all(m["P1_premise_zero"] and m["P2_chain"] and m["P3"] and
             m["P4_derived_value"] and m["P5_terminals"] and m["P6"]
             for m in res["miniatures"])
    res["all_miniatures_pass_P1_P6"] = ok
    with open(os.path.join(OUT, "closure_miniatures.json"), "w") as f:
        json.dump(res, f, indent=1)
    for m in res["miniatures"]:
        print("%-52s N=%2d d=%d L=%3d dimC=%3d rank=%3d ker=%d  P1..P6 %s%s%s%s%s%s  "
              "disclosed=%d%s"
              % (m["label"], m["N"], m["degree"], m["L"], m["dim_C"], m["rank_R"],
                 m["ker_R"],
                 "T" if m["P1_premise_zero"] else "F",
                 "T" if m["P2_chain"] else "F",
                 "T" if m["P3"] else "F",
                 "T" if m["P4_derived_value"] else "F",
                 "T" if m["P5_terminals"] else "F",
                 "T" if m["P6"] else "F",
                 m["P6_disclosed_dimension"],
                 ("  target=%s pre-repair-differs=%s"
                  % (m.get("honest_sum_equals_the_score_target"),
                     m.get("pre_repair_sum_differs_on_this_instance")))
                 if "honest_sum_equals_the_score_target" in m else ""))
    print()
    for c in res["controls"]:
        print(json.dumps(c))
    print("\nALL MINIATURES PASS P1..P6:", ok)


if __name__ == "__main__":
    main()
