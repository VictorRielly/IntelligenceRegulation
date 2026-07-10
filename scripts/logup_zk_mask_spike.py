#!/usr/bin/env python3
"""E3-Z spike: machine checks for the ZK masking of the LogUp-GKR transcript.

Companion to docs/zkmatrix-poc/M4_LOOKUP_ZK_DESIGN.md (tranche U-K5, the
E3-Z design round of M4_LOOKUP_DESIGN.md Section 8). Style and conventions
follow scripts/logup_gkr_spike.py (imported below): pure stdlib, exact
arithmetic, one OK line per machine-checked claim, F5 pairs for every
ordering edge (attack ACCEPTS under the violated order, shipped order
REJECTS the same crafting).

The masked protocol implemented here is EXACTLY the one specified in
M4_LOOKUP_ZK_DESIGN.md Section 3 (single-instance form; the instance
eq-batching adds sumcheck variables but changes no mask shape):

  M1  per-layer-sumcheck round masks g^(j) (Libra Construction 1 shape:
      a0 + sum of univariates, degrees matching the round degrees), with
      the combination challenge nu_j and the hypercube sum G_j pinned by
      an E4-class functional of the committed coefficients;
  M2  per-layer boundary masks: the layer-j MLE pair is replaced by
      p^dot_j(z) := p_j(z) + z_2(1 - z_2) * SP_j(z_1), SP_j(z1) :=
      sum_{w in {0,1}} Rp_j(z1, w), Rp_j of degree (1, 2) in (z1, w),
      committed; each layer sumcheck gains one dummy variable w carrying
      the correction summand, and Rp_j/Rq_j are opened at (mu, c) via
      E4-class claims;
  M3  blinding leaves: per tree, two TOP blinder leaves (one per half)
      and two FINAL blinder leaves (one per low-bit parity), each a
      committed pair (a, u) placed at public dummy positions; blinder
      fractional masses are equal across the two trees by construction
      (one table-side value solved), and constant-in-alpha masses cannot
      alias table poles, so soundness is untouched.

Checks (every OK line asserts):
  Z1  the leak, demonstrated: the UNMASKED table descent's transcript is
      affine in the multiplicity column m with public coefficients; m is
      recovered EXACTLY from one transcript (rank T/T) -- the Q4.3e
      analogue one level up.  Plus the direct root identity leak.
  Z2  completeness of the masked equations exactly as written: the fully
      masked protocol (both descents, blinders, corrections, openings,
      pinned masks, root cross-check, leaf pins) ACCEPTS an honest
      witness, and the sent boundary values differ from the true MLEs.
  Z3  hiding, machine-checked four ways: (a) the Z1 recovery pipeline
      FAILS against the masked transcript; (b/c) exposure/pad rank
      certificates: leaf-layer exposures vs blinder dims, middle-layer
      boundary+opening exposures vs Rp/Rq dims, and the Libra counting
      for one layer's round polynomials (rank = #mask coefficients,
      forced relations = #rounds + 1); (d) a witness-free SIMULATOR
      produces transcripts the verifier accepts (E4 pins modelled by the
      engine's existing [PROVEN] ct-claim simulator, hence checked with
      pin=False -- stated honestly).
  Z4  mask-ordering F5 pair: with the mask claim OUTSIDE the statement
      hash (G unpinned, nu known first), a false lookup is doctored to
      ACCEPT; the shipped order (G pinned to the pre-committed mask)
      REJECTS the same crafting.
  Z5  soundness under masking: a false lookup with honestly-ordered
      masks and blinders still REJECTS (root cross-check).
  Z6  blinder-ordering F5 pair: blinder mass solved at a KNOWN alpha
      ACCEPTS the same false lookup; a fresh alpha REJECTS the same
      committed blinders.

PROGRESS (updated as sections land, for rate-limit resilience):
  [x] mask/blinder machinery (g-masks, R-masks, blinder leaves, tapes)
  [x] masked prover / verifier (prove_descent / verify_descent)
  [x] Z1 recovery of m from the unmasked transcript
  [x] Z2 masked completeness end-to-end
  [x] Z3 recovery failure + rank certificates + simulator
  [x] Z4 mask-order F5 pair
  [x] Z5 masked soundness negative
  [x] Z6 blinder-order F5 pair

Run from the repo root:  python3 scripts/logup_zk_mask_spike.py
"""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from logup_gkr_spike import (GF, build_tree, fuse, histogram, mle_eval,
                             rand_alpha)

# ---------------------------------------------------------------------------
# Small field / polynomial helpers on top of the imported GF.


class Tape:
    """The Fiat-Shamir tape at toy scale: challenges are drawn in a fixed
    order from a seeded stream (the same modelling as logup_gkr_spike's
    rng arguments).  Ordering attacks are modelled by letting the
    adversary READ the tape before crafting (the 'known first' side of
    each F5 pair), exactly as OK-2c/2e did."""

    def __init__(self, seed):
        self.rng = random.Random(seed)

    def draw(self, F):
        return F.rand(self.rng)

    def draw_nonzero(self, F):
        while True:
            v = F.rand(self.rng)
            if v != F.zero:
                return v


def lagrange_eval(F, ys, r):
    """Degree-(len(ys)-1) polynomial through (i, ys[i]), i = 0.., at r."""
    n = len(ys)
    acc = F.zero
    for i in range(n):
        num, den = F.one, F.one
        for j in range(n):
            if j != i:
                num = F.mul(num, F.sub(r, F.embed(j)))
                den = F.mul(den, F.sub(F.embed(i), F.embed(j)))
        acc = F.add(acc, F.mul(ys[i], F.mul(num, F.inv(den))))
    return acc


def eq_eval(F, z, b):
    """eq(z, b) = prod_t (z_t b_t + (1-z_t)(1-b_t))."""
    acc = F.one
    for zt, bt in zip(z, b):
        acc = F.mul(acc, F.add(F.mul(zt, bt),
                               F.mul(F.sub(F.one, zt), F.sub(F.one, bt))))
    return acc


def fold2(F, pair, mu):
    return F.add(pair[0], F.mul(mu, F.sub(pair[1], pair[0])))


# ---------------------------------------------------------------------------
# Mask objects (the committed data of E3-Z).
#
# g-mask (M1):  {'a0': K, 'uni': [[a_{t,1}..a_{t,d_t}] per variable]}
#   g(pt) = a0 + sum_t sum_i a_{t,i} pt_t^i   (no per-variable constant).
# R-mask (M2):  6 coefficients c[i][j], i in {0,1} (z1-degree),
#   j in {0,1,2} (w-degree):  R(z1, w) = sum c[i][j] z1^i w^j.


def draw_gmask(F, rng, degs):
    return {'a0': F.rand(rng),
            'uni': [[F.rand(rng) for _ in range(d)] for d in degs]}


def g_eval(F, gm, pt):
    acc = gm['a0']
    for coeffs, x in zip(gm['uni'], pt):
        xp = x
        for a in coeffs:
            acc = F.add(acc, F.mul(a, xp))
            xp = F.mul(xp, x)
    return acc


def g_hypersum(F, gm, ell):
    """sum over {0,1}^ell of g = 2^ell a0 + 2^(ell-1) sum_t g_t(1)."""
    acc = F.mul(F.embed(2 ** ell), gm['a0'])
    half = F.embed(2 ** (ell - 1))
    for coeffs in gm['uni']:
        s = F.zero
        for a in coeffs:
            s = F.add(s, a)
        acc = F.add(acc, F.mul(half, s))
    return acc


def draw_rmask(F, rng):
    return [[F.rand(rng) for _ in range(3)] for _ in range(2)]


def zero_rmask(F):
    return [[F.zero] * 3 for _ in range(2)]


def zero_gmask(F, degs):
    return {'a0': F.zero, 'uni': [[F.zero] * d for d in degs]}


def eval_R(F, R, z1, w):
    acc = F.zero
    z1p = F.one
    for i in range(2):
        wp = F.one
        for j in range(3):
            acc = F.add(acc, F.mul(R[i][j], F.mul(z1p, wp)))
            wp = F.mul(wp, w)
        z1p = F.mul(z1p, z1)
    return acc


def eval_SP(F, R, z1):
    """SP(z1) = R(z1, 0) + R(z1, 1) -- the boundary pad polynomial."""
    return F.add(eval_R(F, R, z1, F.zero), eval_R(F, R, z1, F.one))


def child_eval(F, table, pt, R):
    """Masked child MLE p^dot(pt) = MLE(table)(pt) + pt_2(1-pt_2)*SP(pt_1);
    the vanishing factor z_2(1-z_2) kills the mask on the hypercube and at
    any point whose SECOND coordinate is Boolean, so summed relations see
    the true tree while boundary points (c, r) (second coordinate r_1,
    random) see a one-time pad."""
    v = mle_eval(F, table, pt)
    if R is not None:
        assert len(pt) >= 2, "R-mask needs a suffix coordinate"
        zz = F.mul(pt[1], F.sub(F.one, pt[1]))
        v = F.add(v, F.mul(zz, eval_SP(F, R, pt[0])))
    return v


def sc_degrees(j, masked, child_masked):
    """Per-variable round-poly degrees of the layer-j sumcheck.
    Unmasked: degree 3 everywhere (eq * p * q). Masked: the child mask's
    z_2(1-z_2) factor rides variable b_1 only (degree +2), and the dummy
    variable w carries degree 2 (the R-masks' w-degree)."""
    if not masked:
        return [3] * j
    return [5 if child_masked else 3] + [3] * (j - 1) + [2]


def make_summand(F, z, lam, cp, cq, Rp_c, Rq_c, corr, wvar):
    """The layer-j sumcheck summand.  Variables: b_1..b_j then (masked
    only) w.  corr = (E, Rp_j, Rq_j, mu_prev) carries the incoming
    claim's own boundary-mask correction (M2), supported on b = 0 via
    eq(b, 0)."""
    def S(pt):
        if wvar:
            b, w = pt[:-1], pt[-1]
        else:
            b, w = pt, None
        eqz = eq_eval(F, z, b)
        pt0, pt1 = [F.zero] + list(b), [F.one] + list(b)
        p0 = child_eval(F, cp, pt0, Rp_c)
        p1 = child_eval(F, cp, pt1, Rp_c)
        q0 = child_eval(F, cq, pt0, Rq_c)
        q1 = child_eval(F, cq, pt1, Rq_c)
        wire = F.add(F.add(F.mul(p0, q1), F.mul(p1, q0)),
                     F.mul(lam, F.mul(q0, q1)))
        term = F.mul(eqz, wire)
        if wvar:
            term = F.mul(F.sub(F.one, w), term)
        if corr is not None:
            E, Rp_j, Rq_j, mu_prev = corr
            eqb0 = F.one
            for bt in b:
                eqb0 = F.mul(eqb0, F.sub(F.one, bt))
            cv = F.add(eval_R(F, Rp_j, mu_prev, w),
                       F.mul(lam, eval_R(F, Rq_j, mu_prev, w)))
            term = F.add(term, F.mul(eqb0, F.mul(E, cv)))
        return term
    return S


def draw_masks(F, rng, K):
    """One mask set per descent: g^(j) for sumchecks j = 1..K-1 (M1) and
    (Rp_j, Rq_j) for interior layers j = 2..K-1 (M2).  All committed in
    the statement wave, before alpha."""
    masks = {'g': {}, 'R': {}}
    for j in range(1, K):
        degs = sc_degrees(j, True, j <= K - 2)
        masks['g'][j] = draw_gmask(F, rng, degs)
    for j in range(2, K):
        masks['R'][j] = (draw_rmask(F, rng), draw_rmask(F, rng))
    return masks


def zero_masks(F, K):
    masks = {'g': {}, 'R': {}}
    for j in range(1, K):
        degs = sc_degrees(j, True, j <= K - 2)
        masks['g'][j] = zero_gmask(F, degs)
    for j in range(2, K):
        masks['R'][j] = (zero_rmask(F), zero_rmask(F))
    return masks


# ---------------------------------------------------------------------------
# Blinding leaves (M3) and leaf-vector construction.
#
# Leaf layout (public): honest values at the front; two TOP blinders (one
# per half -- they randomize the layer-1 values and hence the roots); two
# FINAL blinders, one with low bit 0 and one with low bit 1 (they pad the
# last sumcheck's boundary values, whose eq-weights vanish on the other
# parity); dummies (0, 1) elsewhere.  Every blinder is a committed pair
# (a, u), leaf (p, q) = (a, u): its fractional mass a/u is CONSTANT in
# alpha, so it can never cancel a table pole (soundness, doc Section 5).


def draw_blinders(F, rng):
    bl = {}
    for tag in ('tL', 'tR', 'f0', 'f1'):
        while True:
            u = F.rand(rng)
            if u != F.zero:
                break
        bl[tag] = {'a': F.rand(rng), 'u': u}
    return bl


def blinder_positions(N):
    """tL in the left half, tR in the right half, f0 with low bit 0,
    f1 with low bit 1 (placed left/right for symmetric mass)."""
    return {'tL': N // 2 - 4, 'f0': N // 2 - 2,
            'tR': N - 4, 'f1': N - 3}


def blinder_mass(F, bl):
    beta = F.zero
    for v in bl.values():
        beta = F.add(beta, F.mul(v['a'], F.inv(v['u'])))
    return beta


def solve_table_mass(F, bl_w, bl_t):
    """Honest prover: solve the table-side a_tR so that the two trees'
    blinder masses agree (the completeness condition of the modified
    root cross-check)."""
    beta_w = blinder_mass(F, bl_w)
    rest = F.zero
    for tag in ('tL', 'f0', 'f1'):
        rest = F.add(rest, F.mul(bl_t[tag]['a'], F.inv(bl_t[tag]['u'])))
    bl_t['tR']['a'] = F.mul(bl_t['tR']['u'], F.sub(beta_w, rest))
    return bl_t


def witness_leaves(F, alpha, xs, ys, kappa, bl, N):
    pos = blinder_positions(N)
    pvec, qvec = [F.zero] * N, [F.one] * N
    for i, (x, y) in enumerate(zip(xs, ys)):
        pvec[i] = F.one
        qvec[i] = F.sub(alpha, fuse(F, x, y, kappa))
    for tag, p in pos.items():
        if bl is not None:
            pvec[p], qvec[p] = bl[tag]['a'], bl[tag]['u']
    return pvec, qvec


def table_leaves(F, alpha, table_v, table_y, kappa, m, bl, N):
    pos = blinder_positions(N)
    pvec, qvec = [F.zero] * N, [F.one] * N
    for j, (v, t) in enumerate(zip(table_v, table_y)):
        pvec[j] = F.embed(m[j]) if not isinstance(m[j], tuple) else m[j]
        qvec[j] = F.sub(alpha, fuse(F, v, t, kappa))
    for tag, p in pos.items():
        if bl is not None:
            pvec[p], qvec[p] = bl[tag]['a'], bl[tag]['u']
    return pvec, qvec


# ---------------------------------------------------------------------------
# The descent: prover and verifier.  The transcript is a plain dict so the
# ordering attacks (Z4, Z6) are literal transcript surgery.


def prove_descent(F, seed, p_layers, q_layers, masks):
    tape = Tape(seed)
    K = len(p_layers) - 1
    masked = masks is not None
    tr = {'layer1': (p_layers[1][0], p_layers[1][1],
                     q_layers[1][0], q_layers[1][1]),
          'sc': []}
    mu = tape.draw(F)
    lam = tape.draw(F)
    z = [mu]
    C = F.add(fold2(F, (p_layers[1][0], p_layers[1][1]), mu),
              F.mul(lam, fold2(F, (q_layers[1][0], q_layers[1][1]), mu)))
    for j in range(1, K):
        cp, cq = p_layers[j + 1], q_layers[j + 1]
        child_masked = masked and (j <= K - 2)
        Rp_c, Rq_c = (masks['R'][j + 1] if child_masked else (None, None))
        corr = None
        if masked and j >= 2:
            E = F.mul(z[1], F.sub(F.one, z[1]))
            assert E != F.zero, "degenerate suffix challenge (restart)"
            corr = (E, masks['R'][j][0], masks['R'][j][1], z[0])
        S = make_summand(F, z, lam, cp, cq, Rp_c, Rq_c, corr, masked)
        ell = j + (1 if masked else 0)
        degs = sc_degrees(j, masked, child_masked)
        if masked:
            nu = tape.draw_nonzero(F)
            gm = masks['g'][j]
            G = g_hypersum(F, gm, ell)
            Stot = (lambda S=S, gm=gm, nu=nu:
                    (lambda pt: F.add(S(pt), F.mul(nu, g_eval(F, gm, pt)))))()
            Crun = F.add(C, F.mul(nu, G))
        else:
            G, Stot, Crun = None, S, C
        polys, rs = [], []
        for t in range(ell):
            evals = []
            for x in range(degs[t] + 1):
                acc = F.zero
                for bits in range(2 ** (ell - t - 1)):
                    suffix = [F.embed((bits >> s) & 1)
                              for s in range(ell - t - 1)]
                    acc = F.add(acc, Stot(rs + [F.embed(x)] + suffix))
                evals.append(acc)
            assert F.add(evals[0], evals[1]) == Crun, "honest round broke"
            polys.append(evals)
            r = tape.draw(F)
            rs.append(r)
            Crun = lagrange_eval(F, evals, r)
        r_b = rs[:-1] if masked else rs
        c_w = rs[-1] if masked else None
        vp0 = child_eval(F, cp, [F.zero] + r_b, Rp_c)
        vp1 = child_eval(F, cp, [F.one] + r_b, Rp_c)
        vq0 = child_eval(F, cq, [F.zero] + r_b, Rq_c)
        vq1 = child_eval(F, cq, [F.one] + r_b, Rq_c)
        opens = {}
        if masked:
            opens['g'] = g_eval(F, masks['g'][j], rs)
            if corr is not None:
                opens['Rp'] = eval_R(F, masks['R'][j][0], z[0], c_w)
                opens['Rq'] = eval_R(F, masks['R'][j][1], z[0], c_w)
        tr['sc'].append({'G': G, 'polys': polys,
                         'boundary': (vp0, vp1, vq0, vq1), 'opens': opens})
        mu = tape.draw(F)
        lam = tape.draw(F)
        z = [mu] + r_b
        C = F.add(fold2(F, (vp0, vp1), mu),
                  F.mul(lam, fold2(F, (vq0, vq1), mu)))
    tr['zstar'] = z
    return tr


def verify_descent(F, seed, tr, K, masks_committed, pin=True):
    """Recompute the tape, walk the transcript, return
    (ok, reason, roots, zstar, leaf_claims)."""
    tape = Tape(seed)
    masked = masks_committed is not None
    p10, p11, q10, q11 = tr['layer1']
    roots = (F.add(F.mul(p10, q11), F.mul(p11, q10)), F.mul(q10, q11))
    mu = tape.draw(F)
    lam = tape.draw(F)
    z = [mu]
    C = F.add(fold2(F, (p10, p11), mu),
              F.mul(lam, fold2(F, (q10, q11), mu)))
    for j in range(1, K):
        sc = tr['sc'][j - 1]
        child_masked = masked and (j <= K - 2)
        ell = j + (1 if masked else 0)
        degs = sc_degrees(j, masked, child_masked)
        if masked:
            nu = tape.draw_nonzero(F)
            if pin:
                if sc['G'] != g_hypersum(F, masks_committed['g'][j], ell):
                    return False, ('G-pin', j), roots, None, None
            Crun = F.add(C, F.mul(nu, sc['G']))
        else:
            Crun = C
        rs = []
        for t in range(ell):
            evals = sc['polys'][t]
            if len(evals) != degs[t] + 1:
                return False, ('shape', j, t), roots, None, None
            if F.add(evals[0], evals[1]) != Crun:
                return False, ('roundsum', j, t), roots, None, None
            r = tape.draw(F)
            rs.append(r)
            Crun = lagrange_eval(F, evals, r)
        r_b = rs[:-1] if masked else rs
        c_w = rs[-1] if masked else None
        vp0, vp1, vq0, vq1 = sc['boundary']
        eqzr = eq_eval(F, z, r_b)
        wire = F.add(F.add(F.mul(vp0, vq1), F.mul(vp1, vq0)),
                     F.mul(lam, F.mul(vq0, vq1)))
        if masked:
            expect = F.mul(F.sub(F.one, c_w), F.mul(eqzr, wire))
            if j >= 2:
                E = F.mul(z[1], F.sub(F.one, z[1]))
                eqb0 = F.one
                for rt in r_b:
                    eqb0 = F.mul(eqb0, F.sub(F.one, rt))
                if pin:
                    rp = eval_R(F, masks_committed['R'][j][0], z[0], c_w)
                    rq = eval_R(F, masks_committed['R'][j][1], z[0], c_w)
                    if sc['opens']['Rp'] != rp or sc['opens']['Rq'] != rq:
                        return False, ('open-pin', j), roots, None, None
                cv = F.add(sc['opens']['Rp'],
                           F.mul(lam, sc['opens']['Rq']))
                expect = F.add(expect, F.mul(eqb0, F.mul(E, cv)))
            if pin:
                gv = g_eval(F, masks_committed['g'][j], rs)
                if sc['opens']['g'] != gv:
                    return False, ('open-pin-g', j), roots, None, None
            expect = F.add(expect, F.mul(nu, sc['opens']['g']))
        else:
            expect = F.mul(eqzr, wire)
        if Crun != expect:
            return False, ('endcheck', j), roots, None, None
        mu = tape.draw(F)
        lam = tape.draw(F)
        z = [mu] + r_b
        C = F.add(fold2(F, (vp0, vp1), mu),
                  F.mul(lam, fold2(F, (vq0, vq1), mu)))
    vp0, vp1, vq0, vq1 = tr['sc'][-1]['boundary']
    leaf = (fold2(F, (vp0, vp1), z[0]), fold2(F, (vq0, vq1), z[0]))
    return True, None, roots, z, leaf


def verify_pass(F, seeds, tr_w, tr_t, Kw, Kt, masks_w, masks_t,
                leaves_w, leaves_t, pin=True, leafpin=True):
    """The full lookup verification: both descents, the root cross-check,
    and the leaf pins (the E4 aggregate claims, modelled by exact
    recomputation from the committed leaf vectors)."""
    okw, rw, roots_w, zw, leaf_w = verify_descent(
        F, seeds[0], tr_w, Kw, masks_w, pin)
    if not okw:
        return False, ('witness', rw)
    okt, rt, roots_t, zt, leaf_t = verify_descent(
        F, seeds[1], tr_t, Kt, masks_t, pin)
    if not okt:
        return False, ('table', rt)
    if roots_w[1] == F.zero or roots_t[1] == F.zero:
        return False, ('Qzero',)
    if F.mul(roots_w[0], roots_t[1]) != F.mul(roots_t[0], roots_w[1]):
        return False, ('crosscheck',)
    if leafpin:
        pw, qw = leaves_w
        if leaf_w[0] != mle_eval(F, pw, zw):
            return False, ('leafpin-p-w',)
        if leaf_w[1] != mle_eval(F, qw, zw):
            return False, ('leafpin-q-w',)
        pt_, qt_ = leaves_t
        if leaf_t[0] != mle_eval(F, pt_, zt):
            return False, ('leafpin-p-t',)
        if leaf_t[1] != mle_eval(F, qt_, zt):
            return False, ('leafpin-q-t',)
    return True, None


# ---------------------------------------------------------------------------
# Scenario plumbing shared by the checks.

SEED_W, SEED_T = 1001, 1002  # per-descent FS tapes


def make_scenario(F, rng, N=32, T=8, n_honest=12):
    table_v = list(range(T))
    table_y = [(3 * v + 5) % 31 for v in table_v]
    xs = [table_v[rng.randrange(T)] for _ in range(n_honest)]
    ys = [table_y[x] for x in xs]
    m = histogram(xs, table_v)
    kappa = F.gen
    wf = [fuse(F, x, y, kappa) for x, y in zip(xs, ys)]
    tf = [fuse(F, v, t, kappa) for v, t in zip(table_v, table_y)]
    alpha = rand_alpha(F, rng, wf + tf)
    return dict(table_v=table_v, table_y=table_y, xs=xs, ys=ys, m=m,
                kappa=kappa, alpha=alpha, N=N, T=T)


def build_all(F, sc, ys, bl_w, bl_t, masks_w, masks_t, alpha=None):
    """Build leaf vectors, trees and transcripts for a witness ys
    (possibly corrupted) with the given blinders/masks (None = unmasked
    base protocol)."""
    a = sc['alpha'] if alpha is None else alpha
    pw, qw = witness_leaves(F, a, sc['xs'], ys, sc['kappa'], bl_w, sc['N'])
    pt_, qt_ = table_leaves(F, a, sc['table_v'], sc['table_y'], sc['kappa'],
                            sc['m'], bl_t, sc['N'])
    plw, qlw = build_tree(F, pw, qw)
    plt_, qlt_ = build_tree(F, pt_, qt_)
    tr_w = prove_descent(F, SEED_W, plw, qlw, masks_w)
    tr_t = prove_descent(F, SEED_T, plt_, qlt_, masks_t)
    return (pw, qw), (pt_, qt_), tr_w, tr_t


def flatten_transcript(tr):
    out = list(tr['layer1'])
    for sc in tr['sc']:
        if sc['G'] is not None:
            out.append(sc['G'])
        for evals in sc['polys']:
            out.extend(evals)
        out.extend(sc['boundary'])
        for k in sorted(sc['opens']):
            out.append(sc['opens'][k])
    return out


# ---------------------------------------------------------------------------
# Z1: the leak, demonstrated (the Q4.3e analogue one level up).


def table_transcript_for_m(F, sc, m_vec, masked_ctx=None):
    """Unmasked base protocol (masked_ctx None): plain table tree of the
    original design, T rows padded to 2T leaves.  With masked_ctx =
    (blinders, masks): the masked layout, used by the attacker's basis
    with its own guessed blinders/masks."""
    if masked_ctx is None:
        Nt = 2 * sc['T']
        pvec, qvec = table_leaves(F, sc['alpha'], sc['table_v'],
                                  sc['table_y'], sc['kappa'], m_vec,
                                  None, Nt)
        pl, ql = build_tree(F, pvec, qvec)
        return prove_descent(F, SEED_T, pl, ql, None)
    bl, masks = masked_ctx
    pvec, qvec = table_leaves(F, sc['alpha'], sc['table_v'], sc['table_y'],
                              sc['kappa'], m_vec, bl, sc['N'])
    pl, ql = build_tree(F, pvec, qvec)
    return prove_descent(F, SEED_T, pl, ql, masks)


def recover_m(F, sc, observed_flat, masked_ctx=None):
    """The attacker's pipeline: the transcript is affine in m with public
    coefficients (q-side of the table tree is public), so probe the map
    with unit multiplicity vectors and solve the linear system mod q."""
    T = sc['T']
    base = flatten_transcript(table_transcript_for_m(
        F, sc, [0] * T, masked_ctx))
    cols = []
    for j in range(T):
        ej = [0] * T
        ej[j] = 1
        tj = flatten_transcript(table_transcript_for_m(F, sc, ej,
                                                       masked_ctx))
        cols.append([F.sub(a, b) for a, b in zip(tj, base)])
    rhs = [F.sub(a, b) for a, b in zip(observed_flat, base)]
    # Every K-element is F.e base-field equations (coordinates).
    q = F.q
    rows, target = [], []
    for i in range(len(base)):
        for c in range(F.e):
            rows.append([cols[j][i][c] for j in range(T)])
            target.append(rhs[i][c])
    # Gaussian elimination mod q.
    aug = [row + [t] for row, t in zip(rows, target)]
    rank, piv_cols, r = 0, [], 0
    for col in range(T):
        piv = next((i for i in range(r, len(aug)) if aug[i][col] % q), None)
        if piv is None:
            continue
        aug[r], aug[piv] = aug[piv], aug[r]
        inv = pow(aug[r][col], q - 2, q)
        aug[r] = [(x * inv) % q for x in aug[r]]
        for i in range(len(aug)):
            if i != r and aug[i][col] % q:
                f = aug[i][col]
                aug[i] = [(x - f * y) % q for x, y in zip(aug[i], aug[r])]
        piv_cols.append(col)
        r += 1
        if r == T:
            break
    rank = r
    sol = [0] * T
    for r_i, col in enumerate(piv_cols):
        sol[col] = aug[r_i][T] % q
    return rank, sol


def check_z1(F, sc):
    tr = table_transcript_for_m(F, sc, sc['m'])
    flat = flatten_transcript(tr)
    # Affineness sanity: T(m) == T(0) + sum m_j (T(e_j) - T(0)).
    base = flatten_transcript(table_transcript_for_m(F, sc, [0] * sc['T']))
    recon = list(base)
    for j in range(sc['T']):
        ej = [0] * sc['T']
        ej[j] = 1
        tj = flatten_transcript(table_transcript_for_m(F, sc, ej))
        for i in range(len(recon)):
            delta = F.sub(tj[i], base[i])
            for _ in range(sc['m'][j]):
                recon[i] = F.add(recon[i], delta)
    assert recon == flat, "table transcript is not affine in m"
    print("OK Z1a: the unmasked table-descent transcript is an AFFINE "
          "function of the multiplicity column m with public "
          "coefficients (probe-reconstructed, %d K-values)" % len(flat))
    rank, sol = recover_m(F, sc, flat)
    assert rank == sc['T'], "recovery rank %d" % rank
    assert sol == sc['m'], "recovered m mismatch"
    print("OK Z1b: m RECOVERED EXACTLY from one unmasked transcript "
          "(rank %d/%d) -- the activation histogram leaks, the Q4.3e "
          "analogue one level up" % (rank, sc['T']))
    # The direct root identity: P_t/Q_t equals the m-weighted pole sum.
    _, _, roots, _, _ = verify_descent(F, SEED_T, tr, 4, None, pin=False)
    tf = [fuse(F, v, t, sc['kappa'])
          for v, t in zip(sc['table_v'], sc['table_y'])]
    S_t = F.zero
    for mj, tj in zip(sc['m'], tf):
        S_t = F.add(S_t, F.mul(F.embed(mj),
                               F.inv(F.sub(sc['alpha'], tj))))
    assert F.mul(roots[0], F.inv(roots[1])) == S_t
    print("OK Z1c: the unmasked table root pair satisfies P_t/Q_t = "
          "sum_j m_j/(alpha - t_j) exactly -- the root values are "
          "deterministic witness statistics, as graded in Section 3.5")


# ---------------------------------------------------------------------------
# Z2: masked completeness, exactly the doc's equations.


def masked_setup(F, seed, sc):
    rng = random.Random(seed)
    bl_w = draw_blinders(F, rng)
    bl_t = draw_blinders(F, rng)
    solve_table_mass(F, bl_w, bl_t)
    K = sc['N'].bit_length() - 1
    masks_w = draw_masks(F, rng, K)
    masks_t = draw_masks(F, rng, K)
    return bl_w, bl_t, masks_w, masks_t


def check_z2(F, sc):
    # Baseline sanity: the unmasked protocol accepts (OK-3b class).
    lw, lt, tw, tt = build_all(F, sc, sc['ys'], None, None, None, None)
    Kw = sc['N'].bit_length() - 1
    Kt = Kw
    # unmasked table used 2T leaves in Z1; here use the same N for both.
    ok, why = verify_pass(F, (SEED_W, SEED_T), tw, tt, Kw, Kt, None, None,
                          lw, lt, pin=False)
    assert ok, "unmasked baseline rejected: %s" % (why,)
    bl_w, bl_t, masks_w, masks_t = masked_setup(F, 71, sc)
    lw, lt, tw, tt = build_all(F, sc, sc['ys'], bl_w, bl_t,
                               masks_w, masks_t)
    ok, why = verify_pass(F, (SEED_W, SEED_T), tw, tt, Kw, Kt,
                          masks_w, masks_t, lw, lt,
                          pin=True, leafpin=True)
    assert ok, "masked protocol rejected an honest witness: %s" % (why,)
    # The masks are live: a sent boundary value differs from the true MLE.
    plw, qlw = build_tree(F, *lw)
    sc1 = tw['sc'][0]
    tape = Tape(SEED_W)
    _ = [tape.draw(F) for _ in range(2)]
    _ = tape.draw_nonzero(F)
    rs = []
    for t in range(2):  # j = 1 masked: ell = 2 rounds
        r = tape.draw(F)
        rs.append(r)
    true_vp0 = mle_eval(F, plw[2], [F.zero] + rs[:-1])
    assert sc1['boundary'][0] != true_vp0, "boundary mask inactive"
    print("OK Z2: the fully masked protocol (round masks g/nu/G, boundary "
          "masks Rp/Rq with the w-variable correction, blinder leaves "
          "with solved mass equality, pinned openings, root cross-check, "
          "leaf pins) ACCEPTS the honest witness, and sent boundary "
          "values differ from the true MLEs (masks live)")
    return bl_w, bl_t, masks_w, masks_t, (lw, lt, tw, tt)


# ---------------------------------------------------------------------------
# Z3: the recovery fails; rank certificates; the witness-free simulator.


def check_z3(F, sc, z2_ctx):
    bl_w, bl_t, masks_w, masks_t, built = z2_ctx
    lw, lt, tw, tt = built
    Kw = sc['N'].bit_length() - 1
    # (a) the Z1 pipeline against the masked transcript.  The attacker
    # does not know masks or blinders; its best affine model probes the
    # masked layout with zero masks and benign (a, u) = (0, 1) blinders.
    guess_bl = {tag: {'a': F.zero, 'u': F.one}
                for tag in ('tL', 'tR', 'f0', 'f1')}
    guess_masks = zero_masks(F, Kw)
    rank, sol = recover_m(F, sc, flatten_transcript(tt),
                          masked_ctx=(guess_bl, guess_masks))
    assert sol != sc['m'], "masked transcript still leaks m"
    print("OK Z3a: the SAME recovery pipeline against the masked "
          "transcript returns a wrong histogram (recovered != m) -- "
          "the Z1b leak is closed")
    # (b) leaf-layer exposure/pad rank certificates.  Exposures are the
    # last sumcheck's boundary values; they are affine in the blinder
    # values; the pad map must have full row rank.
    tape = Tape(SEED_W)
    _ = [tape.draw(F) for _ in range(2)]
    r_b = None
    for j in range(1, Kw):  # replay the tape to the last b-challenges
        _ = tape.draw_nonzero(F)
        rs = [tape.draw(F) for _ in range(j + 1)]
        _ = tape.draw(F)
        _ = tape.draw(F)
        r_b = rs[:-1]

    def leaf_exposures(bl):
        pv, qv = witness_leaves(F, sc['alpha'], sc['xs'], sc['ys'],
                                sc['kappa'], bl, sc['N'])
        return [mle_eval(F, pv, [F.zero] + r_b),
                mle_eval(F, pv, [F.one] + r_b),
                mle_eval(F, qv, [F.zero] + r_b),
                mle_eval(F, qv, [F.one] + r_b)]

    dims = [('tL', 'a'), ('tR', 'a'), ('f0', 'a'), ('f1', 'a'),
            ('tL', 'u'), ('tR', 'u'), ('f0', 'u'), ('f1', 'u')]
    base_bl = {tag: {'a': F.zero, 'u': F.one}
               for tag in ('tL', 'tR', 'f0', 'f1')}
    E0 = leaf_exposures(base_bl)
    cols = []
    for tag, field in dims:
        bl_probe = {t: dict(v) for t, v in base_bl.items()}
        bl_probe[tag][field] = F.add(bl_probe[tag][field], F.one)
        Ei = leaf_exposures(bl_probe)
        cols.append([F.sub(a, b) for a, b in zip(Ei, E0)])
    rows = [[cols[d][i] for d in range(len(dims))] for i in range(4)]
    rank_leaf = k_rank_kmat(F, rows)
    assert rank_leaf == 4, "leaf exposure map rank %d" % rank_leaf
    print("OK Z3b: leaf-layer exposure/pad rank certificate: the 4 final "
          "boundary values are a FULL-RANK affine image of the blinder "
          "pads (rank 4/4) -- jointly one-time-padded")
    # (c) middle-layer certificate: layer-3 boundary values + the layer-3
    # R-openings vs the 12 coefficients of (Rp_3, Rq_3); and the Libra
    # counting for layer 2's round polynomials.
    rank_mid, n_exp = middle_layer_rank(F, sc, lw, masks_w, Kw)
    assert rank_mid == 6 and n_exp == 6, (rank_mid, n_exp)
    n_g, rank_g, n_rel = gmask_rank(F, sc, lw, masks_w, Kw)
    assert rank_g == n_g, "g exposure rank %d != %d" % (rank_g, n_g)
    print("OK Z3c: mask-saturation certificates: middle-layer boundary + "
          "opening exposures have rank %d/6 over the R-mask coefficients;"
          " one layer's round-poly/G/opening exposures have rank %d = "
          "#mask coefficients with exactly %d forced check relations -- "
          "the Libra Thm 4.1 counting, machine-checked" %
          (rank_mid, rank_g, n_rel))
    # (d) the witness-free simulator.
    sim_w, sim_t = simulate_pass(F, sc, Kw)
    ok, why = verify_pass(F, (SEED_W, SEED_T), sim_w, sim_t, Kw, Kw,
                          masks_w, masks_t, None, None,
                          pin=False, leafpin=False)
    assert ok, "simulator rejected: %s" % (why,)
    print("OK Z3d: a WITNESS-FREE simulator (uniform samples + forced "
          "values only) produces transcripts the verifier ACCEPTS "
          "(descent checks, corrections, root cross-check); the E4 pin "
          "layer is the engine's existing [PROVEN] ct-claim simulator")


def k_rank_kmat(F, rows):
    """Rank of a matrix whose entries are K-elements, over K."""
    rows = [list(r) for r in rows]
    rank, r = 0, 0
    ncols = len(rows[0])
    for col in range(ncols):
        piv = next((i for i in range(r, len(rows))
                    if rows[i][col] != F.zero), None)
        if piv is None:
            continue
        rows[r], rows[piv] = rows[piv], rows[r]
        inv = F.inv(rows[r][col])
        rows[r] = [F.mul(x, inv) for x in rows[r]]
        for i in range(len(rows)):
            if i != r and rows[i][col] != F.zero:
                f = rows[i][col]
                rows[i] = [F.sub(x, F.mul(f, y))
                           for x, y in zip(rows[i], rows[r])]
        r += 1
        if r == len(rows):
            break
    return r


def middle_layer_rank(F, sc, lw, masks_w, Kw):
    """Exposures of the layer-3 R-masks: the layer-2 sumcheck's boundary
    values (padded by SP_3/SQ_3(0/1)) and the layer-3 sumcheck's openings
    Rp_3(mu, c), Rq_3(mu, c) -- affine in the 12 coefficients."""
    pl, ql = build_tree(F, *lw)

    def exposures(masks):
        tr = prove_descent(F, SEED_W, pl, ql, masks)
        sc2 = tr['sc'][1]      # layer-2 sumcheck -> layer-3 boundary
        sc3 = tr['sc'][2]      # layer-3 sumcheck -> opens Rp_3/Rq_3
        return list(sc2['boundary']) + [sc3['opens']['Rp'],
                                        sc3['opens']['Rq']]

    E0 = exposures(masks_w)
    rows = [[] for _ in range(len(E0))]
    for side in range(2):
        for i in range(2):
            for j in range(3):
                probe = {'g': masks_w['g'],
                         'R': dict(masks_w['R'])}
                Rp, Rq = masks_w['R'][3]
                Rp2 = [list(r) for r in Rp]
                Rq2 = [list(r) for r in Rq]
                (Rp2 if side == 0 else Rq2)[i][j] = F.add(
                    (Rp2 if side == 0 else Rq2)[i][j], F.one)
                probe['R'][3] = (Rp2, Rq2)
                Ei = exposures(probe)
                for k in range(len(E0)):
                    rows[k].append(F.sub(Ei[k], E0[k]))
    return k_rank_kmat(F, rows), len(E0)


def gmask_rank(F, sc, lw, masks_w, Kw):
    """The Libra counting for layer j0 = 2: exposures = G, all round-poly
    evaluations, and the opening g(r).  Affine in the n_g coefficients of
    g^(2); rank must equal n_g and the number of forced relations must be
    #rounds + 1 (each round's g(0)+g(1) = C plus the end check)."""
    j0 = 2
    pl, ql = build_tree(F, *lw)
    degs = sc_degrees(j0, True, j0 <= Kw - 2)
    n_g = 1 + sum(degs)

    def exposures(masks):
        tr = prove_descent(F, SEED_W, pl, ql, masks)
        sc_ = tr['sc'][j0 - 1]
        out = [sc_['G']]
        for evals in sc_['polys']:
            out.extend(evals)
        out.append(sc_['opens']['g'])
        return out

    E0 = exposures(masks_w)
    n_exp = len(E0)
    rows = [[] for _ in range(n_exp)]
    for t in range(-1, len(degs)):
        idxs = [0] if t == -1 else range(len(masks_w['g'][j0]['uni'][t]))
        for i in idxs:
            gm2 = {'a0': masks_w['g'][j0]['a0'],
                   'uni': [list(u) for u in masks_w['g'][j0]['uni']]}
            if t == -1:
                gm2['a0'] = F.add(gm2['a0'], F.one)
            else:
                gm2['uni'][t][i] = F.add(gm2['uni'][t][i], F.one)
            probe = {'g': dict(masks_w['g']), 'R': masks_w['R']}
            probe['g'][j0] = gm2
            Ei = exposures(probe)
            for k in range(n_exp):
                rows[k].append(F.sub(Ei[k], E0[k]))
    rank = k_rank_kmat(F, rows)
    n_rel = n_exp - rank
    ell = len(degs)
    assert n_rel == ell + 1, "forced relations %d != %d" % (n_rel, ell + 1)
    return n_g, rank, n_rel


def simulate_pass(F, sc, K):
    """The simulator: samples every exposed value uniform (or on its
    forced variety) and solves the g-openings from the end checks.  Uses
    NO witness data (xs, ys, m never touched)."""
    srng = random.Random(999)

    def sim_descent(seed, layer1):
        tape = Tape(seed)
        tr = {'layer1': layer1, 'sc': []}
        p10, p11, q10, q11 = layer1
        mu = tape.draw(F)
        lam = tape.draw(F)
        z = [mu]
        C = F.add(fold2(F, (p10, p11), mu),
                  F.mul(lam, fold2(F, (q10, q11), mu)))
        for j in range(1, K):
            ell = j + 1
            degs = sc_degrees(j, True, j <= K - 2)
            nu = tape.draw_nonzero(F)
            G = F.rand(srng)
            Crun = F.add(C, F.mul(nu, G))
            polys, rs = [], []
            for t in range(ell):
                e0 = F.rand(srng)
                evals = [e0, F.sub(Crun, e0)]
                for _ in range(degs[t] - 1):
                    evals.append(F.rand(srng))
                polys.append(evals)
                r = tape.draw(F)
                rs.append(r)
                Crun = lagrange_eval(F, evals, r)
            r_b, c_w = rs[:-1], rs[-1]
            boundary = tuple(F.rand(srng) for _ in range(4))
            vp0, vp1, vq0, vq1 = boundary
            eqzr = eq_eval(F, z, r_b)
            wire = F.add(F.add(F.mul(vp0, vq1), F.mul(vp1, vq0)),
                         F.mul(lam, F.mul(vq0, vq1)))
            expect = F.mul(F.sub(F.one, c_w), F.mul(eqzr, wire))
            opens = {}
            if j >= 2:
                E = F.mul(z[1], F.sub(F.one, z[1]))
                eqb0 = F.one
                for rt in r_b:
                    eqb0 = F.mul(eqb0, F.sub(F.one, rt))
                opens['Rp'] = F.rand(srng)
                opens['Rq'] = F.rand(srng)
                cv = F.add(opens['Rp'], F.mul(lam, opens['Rq']))
                expect = F.add(expect, F.mul(eqb0, F.mul(E, cv)))
            opens['g'] = F.mul(F.sub(Crun, expect), F.inv(nu))
            tr['sc'].append({'G': G, 'polys': polys,
                             'boundary': boundary, 'opens': opens})
            mu = tape.draw(F)
            lam = tape.draw(F)
            z = [mu] + r_b
            C = F.add(fold2(F, (vp0, vp1), mu),
                      F.mul(lam, fold2(F, (vq0, vq1), mu)))
        return tr

    def nz():
        while True:
            v = F.rand(srng)
            if v != F.zero:
                return v

    l1w = (F.rand(srng), F.rand(srng), nz(), nz())
    Pw = F.add(F.mul(l1w[0], l1w[3]), F.mul(l1w[1], l1w[2]))
    Qw = F.mul(l1w[2], l1w[3])
    q10t, q11t, p10t = nz(), nz(), F.rand(srng)
    Qt = F.mul(q10t, q11t)
    # solve p11t from the cross-check Pw*Qt == Pt*Qw
    Pt = F.mul(Pw, F.mul(Qt, F.inv(Qw)))
    p11t = F.mul(F.sub(Pt, F.mul(p10t, q11t)), F.inv(q10t))
    l1t = (p10t, p11t, q10t, q11t)
    return sim_descent(SEED_W, l1w), sim_descent(SEED_T, l1t)


# ---------------------------------------------------------------------------
# Z4/Z5/Z6: the ordering F5 pairs and the masked soundness negative.


def bad_witness(sc):
    ys_bad = list(sc['ys'])
    ys_bad[5] = (ys_bad[5] + 1) % 97
    return ys_bad


def check_z456(F, sc):
    Kw = sc['N'].bit_length() - 1
    ys_bad = bad_witness(sc)
    bl_w, bl_t, masks_w, masks_t = masked_setup(F, 73, sc)

    # Z5 first: honest order, honest masks/blinders, false lookup.
    lw, lt, tw, tt = build_all(F, sc, ys_bad, bl_w, bl_t, masks_w, masks_t)
    ok, why = verify_pass(F, (SEED_W, SEED_T), tw, tt, Kw, Kw,
                          masks_w, masks_t, lw, lt)
    assert not ok and why == ('crosscheck',), why
    print("OK Z5: a false lookup (one wrong y) under the FULL masking "
          "machinery, honest order, still REJECTS at the root "
          "cross-check -- masking does not help a cheating prover")

    # Z4: the mask-ordering F5 pair.  Attack: doctor the witness layer-1
    # values so the cross-check passes, and absorb the resulting claim
    # defect into a G_1 chosen AFTER nu_1 (mask claim outside the
    # statement hash).
    roots_w = roots_from(F, tw['layer1'])
    roots_t = roots_from(F, tt['layer1'])
    sigma_w = F.mul(roots_w[0], F.inv(roots_w[1]))
    sigma_t = F.mul(roots_t[0], F.inv(roots_t[1]))
    delta = F.sub(sigma_t, sigma_w)
    assert delta != F.zero
    p10, p11, q10, q11 = tw['layer1']
    p10_d = F.add(p10, F.mul(delta, q10))
    # verifier-side folds under the same tape
    tape = Tape(SEED_W)
    mu0 = tape.draw(F)
    lam1 = tape.draw(F)
    nu1 = tape.draw_nonzero(F)
    C_true = F.add(fold2(F, (p10, p11), mu0),
                   F.mul(lam1, fold2(F, (q10, q11), mu0)))
    C_doc = F.add(fold2(F, (p10_d, p11), mu0),
                  F.mul(lam1, fold2(F, (q10, q11), mu0)))
    tw_atk = {'layer1': (p10_d, p11, q10, q11),
              'sc': [dict(s) for s in tw['sc']], 'zstar': tw['zstar']}
    tw_atk['sc'][0] = dict(tw_atk['sc'][0])
    tw_atk['sc'][0]['G'] = F.add(tw['sc'][0]['G'],
                                 F.mul(F.sub(C_true, C_doc), F.inv(nu1)))
    ok_atk, _ = verify_pass(F, (SEED_W, SEED_T), tw_atk, tt, Kw, Kw,
                            masks_w, masks_t, lw, lt, pin=False)
    assert ok_atk, "mask-order attack should ACCEPT with G unpinned"
    ok_ship, why = verify_pass(F, (SEED_W, SEED_T), tw_atk, tt, Kw, Kw,
                               masks_w, masks_t, lw, lt, pin=True)
    assert not ok_ship and why == ('witness', ('G-pin', 1)), why
    print("OK Z4: mask-ordering F5 pair: a mask claim OUTSIDE the "
          "statement hash (G chosen after nu) absorbs the doctored "
          "layer-1 defect and the false lookup ACCEPTS; the shipped "
          "order (G pinned to the pre-committed mask, E4 class) REJECTS "
          "the same crafting")

    # Z6: the blinder-ordering F5 pair.  Attack: with alpha KNOWN, solve
    # the witness-side blinder mass so the blinded roots cross-check.
    bl_w2, bl_t2, masks_w2, masks_t2 = masked_setup(F, 79, sc)
    # compute the defect at the known alpha and absorb it into a_tL
    lw2, lt2, tw2, tt2 = build_all(F, sc, ys_bad, bl_w2, bl_t2,
                                   masks_w2, masks_t2)
    rw = roots_from(F, tw2['layer1'])
    rt = roots_from(F, tt2['layer1'])
    d2 = F.sub(F.mul(rt[0], F.inv(rt[1])), F.mul(rw[0], F.inv(rw[1])))
    # sigma_w gains a_delta/u_tL when a_tL += a_delta: solve a_delta
    bl_w2['tL']['a'] = F.add(bl_w2['tL']['a'],
                             F.mul(d2, bl_w2['tL']['u']))
    lw2, lt2, tw2, tt2 = build_all(F, sc, ys_bad, bl_w2, bl_t2,
                                   masks_w2, masks_t2)
    ok_atk, why = verify_pass(F, (SEED_W, SEED_T), tw2, tt2, Kw, Kw,
                              masks_w2, masks_t2, lw2, lt2)
    assert ok_atk, "blinder-after-alpha attack should ACCEPT: %s" % (why,)
    # Shipped order: the same committed blinders against a FRESH alpha.
    rng2 = random.Random(83)
    wf_bad = [fuse(F, x, y, sc['kappa'])
              for x, y in zip(sc['xs'], ys_bad)]
    tf = [fuse(F, v, t, sc['kappa'])
          for v, t in zip(sc['table_v'], sc['table_y'])]
    alpha2 = rand_alpha(F, rng2, wf_bad + tf)
    lw3, lt3, tw3, tt3 = build_all(F, sc, ys_bad, bl_w2, bl_t2,
                                   masks_w2, masks_t2, alpha=alpha2)
    ok_ship, why = verify_pass(F, (SEED_W, SEED_T), tw3, tt3, Kw, Kw,
                               masks_w2, masks_t2, lw3, lt3)
    assert not ok_ship and why == ('crosscheck',), why
    print("OK Z6: blinder-ordering F5 pair: a blinder mass solved at a "
          "KNOWN alpha ACCEPTS the same false lookup (blinders must be "
          "bound by h0_lkp before alpha); a fresh alpha REJECTS the "
          "same committed blinders")


def roots_from(F, layer1):
    p10, p11, q10, q11 = layer1
    return (F.add(F.mul(p10, q11), F.mul(p11, q10)), F.mul(q10, q11))


# ---------------------------------------------------------------------------

if __name__ == '__main__':
    F = GF(97, 3)
    rng = random.Random(61)
    sc = make_scenario(F, rng)
    check_z1(F, sc)
    ctx = check_z2(F, sc)
    check_z3(F, sc, ctx)
    check_z456(F, sc)
    print("all logup_zk_mask_spike assertions passed")
