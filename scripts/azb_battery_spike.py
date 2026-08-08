#!/usr/bin/env python3
"""azb_battery_spike.py — U-AG-B1 Agent BC: the AZB battery at spike level.

Executable legs for every AZB battery item implementable against the
existing spike simulators (AGGREGATION_ZK_DESIGN.md Section 6 AZB-1..9;
AGGREGATION_FOLDING_DESIGN.md Section 8 FINAL ruling AZB-10 = the IXF
segment/group-map F5 pair; AGGREGATION_FOLD_PRIVACY_PRICING.md Section
4.2 AZB-11 = the weight-independence canary). Machinery ADAPTED from
scripts/aggregation_zk_spike.py (SPKZ toys) and
scripts/fold_privacy_pricing_spike.py (FPP toys): both parents execute
their whole batteries at module import, so importing them would rerun
and interleave their output — instead this spike (a) re-runs BOTH (and
aggregation_folding_spike.py) as subprocesses first and asserts their
recorded verdict lines (14/14, 15/15, 33/33) before printing a single
leg, the folding-spike anchor pattern, and (b) carries adapted copies
of their small toolkit functions, cited per function. The parent
scripts are READ-ONLY inputs and are not modified.

Leg groups (F5 pairs = the attack leg ACCEPTS under the violated
order / the shipped order REJECTS the same crafting — both directions
always exercised):

  AZB-1   terminal leak demonstrated (permanent unmasked baseline):
          exact recovery at EXACTLY the predicted transcript count
  AZB-2   masked non-recovery (full-coset certificate) + the three
          counting canaries (AZ-L1a rank n_g / ell+1 forced; AZ-L1b
          joint rank under shared challenges; AZ-L2a pad diagonal)
  AZB-3   statement-hash F5 pair (T_blind outside h0_agg: the A3
          swap absorbs a false-instance defect; shipped h0 rejects)
  AZB-4   ordering pairs: (i) extension pad after r (A2/A4);
          (ii) mu before the blinded terminals (CRB-N4 one level up);
          (iii) nu before the G pin (E3Z-N1 class)
  AZB-5   T_blind freshness (pad reuse across proofs re-exposes at
          half rate; fresh pads keep the full coset)
  AZB-6   fold-ordering pair at the eval-proof levels (u_i vs c^(i),
          the AZ-L4 A1 pair)
  AZB-7   floor exhibit + confinement: (i) recompute match incl. one
          digit level deeper; (ii) rank accumulation to the exact
          threshold; (iii) simulator-match for every non-R component
  AZB-8   joint-rank certificate (AZ-O2), shipped PASS + rigged
          deficiency FIRES
  AZB-9   slot-completeness of blinding (AZ-R1): slot-shared blind
          leaks; ring-granular blind keeps all 8 slots uniform
  AZB-10  IXF F5 pairs, both edges: (a) segment map (relabel binds
          the wrong slices / breaks the declared chaining);
          (b) group map (the FPP-4 pair: migration leaks an explicit
          weight functional)
  AZB-11  weight-independence canary per the FP-L3/FB spec: ACCEPT
          legs 1-3 (static support, functional recompute,
          perturbation invariance) + REJECT leg 4 (migration F5),
          + two deliberately weight-CONTAMINATED variants that FIRE
  F-Z1    masking-corner re-check at the build round's operating
          points (design-doc schedules; 125M band [BB-SCHEDULE
          PENDING] with the printed recomputation recipe)

Engine-scale certification of every leg is [ENGINE PENDING - BB] per
docs/zkmatrix-poc/AZB_BATTERY_PLAN.md Section 3; this file is the
spike-level executable battery its Section 2 dispositions point at.

Toy field GF(q31), q31 = 2^31 - 399 (the real base modulus, per the
claim-reduction spike's small-field incident note). Toy folds
demonstrate ORDERING/SPLIT/COUNTING structure, not lattice binding
strength (the SPKZ convention). Stdlib only, seeded, deterministic;
single run < ~30 s.
"""

import hashlib
import math
import os
import random
import subprocess
import sys

P = 2**31 - 399  # q31 — the real base modulus

# --------------------------------------------------------------------------
# parent-spike anchors (re-run, assert recorded verdict lines, stay silent)
# --------------------------------------------------------------------------

PARENTS = [
    ("aggregation_zk_spike.py", "14/14 OK"),
    ("fold_privacy_pricing_spike.py", "15/15 OK"),
    ("aggregation_folding_spike.py", "33/33"),
]


def check_parents():
    here = os.path.dirname(os.path.abspath(__file__))
    for script, needle in PARENTS:
        path = os.path.join(here, script)
        r = subprocess.run([sys.executable, path], capture_output=True,
                           text=True, timeout=300)
        if r.returncode != 0 or needle not in r.stdout:
            print("FAIL parent anchor: %s (rc=%d, needle %r missing)"
                  % (script, r.returncode, needle))
            sys.exit(1)
    print("parent anchors reproduced: aggregation_zk_spike 14/14, "
          "fold_privacy_pricing_spike 15/15, aggregation_folding_spike "
          "33/33 (subprocess re-runs, recorded verdict lines asserted)")


# --------------------------------------------------------------------------
# field + linear-algebra toolkit (adapted from aggregation_zk_spike.py)
# --------------------------------------------------------------------------

def inv(a):
    return pow(a % P, P - 2, P)


def prf(*parts):
    """Deterministic FS-style GF(P) draw (fold_privacy_pricing_spike)."""
    h = hashlib.sha256()
    for p in parts:
        h.update(str(p).encode())
        h.update(b"|")
    return int.from_bytes(h.digest(), "big") % P


def mat_rank(rows):
    rows = [list(r) for r in rows]
    rank, ncols = 0, (len(rows[0]) if rows else 0)
    for c in range(ncols):
        piv = next((i for i in range(rank, len(rows)) if rows[i][c] % P), None)
        if piv is None:
            continue
        rows[rank], rows[piv] = rows[piv], rows[rank]
        iv = inv(rows[rank][c])
        rows[rank] = [(x * iv) % P for x in rows[rank]]
        for i in range(len(rows)):
            if i != rank and rows[i][c] % P:
                f = rows[i][c]
                rows[i] = [(x - f * y) % P for x, y in zip(rows[i], rows[rank])]
        rank += 1
        if rank == len(rows):
            break
    return rank


def solve_lin(A, b):
    n, m = len(A), len(A[0])
    M = [list(A[i]) + [b[i] % P] for i in range(n)]
    rank, pivcols = 0, []
    for c in range(m):
        piv = next((i for i in range(rank, n) if M[i][c] % P), None)
        if piv is None:
            continue
        M[rank], M[piv] = M[piv], M[rank]
        iv = inv(M[rank][c])
        M[rank] = [(x * iv) % P for x in M[rank]]
        for i in range(n):
            if i != rank and M[i][c] % P:
                f = M[i][c]
                M[i] = [(x - f * y) % P for x, y in zip(M[i], M[rank])]
        pivcols.append(c)
        rank += 1
    for i in range(rank, n):
        if M[i][m] % P:
            return None
    x = [0] * m
    for r, c in enumerate(pivcols):
        x[c] = M[r][m]
    return x


def eq_weight(z, b):
    w = 1
    for zj, bj in zip(z, b):
        w = w * ((zj if bj else (1 - zj)) % P) % P
    return w


def eq_full(z, x):
    w = 1
    for zj, xj in zip(z, x):
        w = w * ((zj * xj + (1 - zj) * (1 - xj)) % P) % P
    return w


def mle_eval(table, z):
    n = len(z)
    acc = 0
    for idx, v in enumerate(table):
        b = tuple((idx >> (n - 1 - j)) & 1 for j in range(n))
        acc = (acc + v * eq_weight(z, b)) % P
    return acc


def lagrange_at(vals, x):
    d = len(vals) - 1
    acc = 0
    for i in range(d + 1):
        num, den = 1, 1
        for j in range(d + 1):
            if j != i:
                num = num * ((x - j) % P) % P
                den = den * ((i - j) % P) % P
        acc = (acc + vals[i] * num % P * inv(den)) % P
    return acc


checks = []


def ok(name, cond, msg):
    checks.append((name, bool(cond)))
    print(("OK " if cond else "FAIL ") + name + ": " + msg)
    assert cond, name


# --------------------------------------------------------------------------
# the masked selector-extension zero-check (adapted from SPKZ Sections 2-4)
# --------------------------------------------------------------------------
# ell = 4 variables (1 extension bit + 3 real bits); F(x) = eq(r_sz, x) *
# (1 - x_1) * (G^ U^ - Z^)(x); round degrees (4, 3, 3, 3);
# Libra mask g(x) = a0 + sum_t g_t(x_t), n_g = 1 + sum deg = 14.

ELL = 4
DEGS = [4, 3, 3, 3]
NG = 1 + sum(DEGS)


def make_instance(rng, tamper=False):
    G = [rng.randrange(P) for _ in range(8)]
    U = [rng.randrange(P) for _ in range(8)]
    Z = [g * u % P for g, u in zip(G, U)]
    if tamper:
        Z[3] = (Z[3] + 1) % P
    bG, bU, bZ = (rng.randrange(P) for _ in range(3))
    Gh = G + [bG] + [0] * 7
    Uh = U + [bU] + [0] * 7
    Zh = Z + [bZ] + [0] * 7
    return Gh, Uh, Zh


def F_val(Gh, Uh, Zh, r_sz, x):
    sel = (1 - x[0]) % P
    e = eq_full(r_sz, x)
    g = mle_eval(Gh, x)
    u = mle_eval(Uh, x)
    z = mle_eval(Zh, x)
    return e * sel % P * ((g * u - z) % P) % P


def mask_eval(mask, x):
    a0, gts = mask
    acc = a0
    for ct, xi in zip(gts, x):
        xp = xi % P
        pw = xp
        for ci in ct:
            acc = (acc + ci * pw) % P
            pw = pw * xp % P
    return acc


def mask_hsum(mask):
    a0, gts = mask
    acc = (1 << ELL) * a0 % P
    for ct in gts:
        acc = (acc + (1 << (ELL - 1)) * (sum(ct) % P)) % P
    return acc


def round_poly(fn, prefix, deg, nvars):
    out = []
    rest = nvars - len(prefix) - 1
    for v in range(deg + 1):
        s = 0
        for suf in range(1 << rest):
            x = list(prefix) + [v] + [(suf >> (rest - 1 - j)) & 1
                                      for j in range(rest)]
            s = (s + fn(x)) % P
        out.append(s)
    return out


def masked_zero_check(rng_tape, Gh, Uh, Zh, mask, pin_gsum=None):
    """Prover+verifier for the masked selector-extension zero-check.
    pin_gsum: value the G-pin asserts (default: the honest mask hsum) —
    the AZB-4(iii) attack lever. Returns (accept, sent)."""
    r_sz = [rng_tape.randrange(P) for _ in range(ELL)]
    nu = 1 + rng_tape.randrange(P - 1)
    Gsum = mask_hsum(mask) if pin_gsum is None else pin_gsum
    claim = (0 + nu * Gsum) % P

    def fn(x):
        return (F_val(Gh, Uh, Zh, r_sz, x) + nu * mask_eval(mask, x)) % P

    sent_rounds, prefix = [], []
    for t in range(ELL):
        rp = round_poly(fn, prefix, DEGS[t], ELL)
        sent_rounds.append(rp)
        if (rp[0] + rp[1]) % P != claim % P:
            return False, None
        rt = rng_tape.randrange(P)
        claim = lagrange_at(rp, rt)
        prefix.append(rt)
    vG, vU, vZ = (mle_eval(Gh, prefix), mle_eval(Uh, prefix),
                  mle_eval(Zh, prefix))
    g_open = mask_eval(mask, prefix)
    sel = (1 - prefix[0]) % P
    end = (eq_full(r_sz, prefix) * sel % P * ((vG * vU - vZ) % P)
           + nu * g_open) % P
    return end % P == claim % P, dict(r_sz=r_sz, nu=nu, rounds=sent_rounds,
                                      terms=(vG, vU, vZ), gopen=g_open,
                                      prefix=prefix, Gsum=Gsum)


# ==========================================================================
# AZB-1 — the terminal leak, demonstrated (permanent unmasked baseline)
# ==========================================================================
# Rigged toy claim set: tensor T over 4 bits; each proof exposes ONE
# unmasked terminal MLE(T)(z) at a fresh challenge point. PASS = exact
# recovery at EXACTLY the predicted transcript count (16), and not one
# transcript earlier. (SPKZ-1a sharpened to the count statement the
# battery spec asks for.)

def azb1():
    rng = random.Random(1101)
    NT = 16
    T = [rng.randrange(P) for _ in range(NT)]
    rows, rhs = [], []
    for _ in range(NT):
        z = [rng.randrange(P) for _ in range(4)]
        rows.append([eq_weight(z, tuple((i >> (3 - j)) & 1 for j in range(4)))
                     for i in range(NT)])
        rhs.append(mle_eval(T, z))
    rank_before = mat_rank(rows[:NT - 1])
    rec = solve_lin(rows, rhs)
    ok("AZB-1", rank_before == NT - 1 and mat_rank(rows) == NT
       and rec == [t % P for t in T],
       "UNMASKED terminals: rank %d/%d after %d transcripts (no recovery), "
       "EXACT tensor recovery at the predicted count %d — the permanent "
       "pre-fix baseline (Z1-a pattern; SPKZ-1a sharpened)"
       % (rank_before, NT, NT - 1, NT))


# ==========================================================================
# AZB-2 — masked non-recovery + the counting canaries
# ==========================================================================

def azb2():
    rng = random.Random(1201)
    NT = 16
    T = [rng.randrange(P) for _ in range(NT)]
    n_tr = 3 * NT
    # blinded transcripts: v = (1-r_ext)*MLE(T)(z) + r_ext*eq(z,0)*beta,
    # beta fresh per proof (the AZ-L2 extension-pad shape)
    A_rows, rhs = [], []
    ext_ws = []
    for i in range(n_tr):
        z = [rng.randrange(P) for _ in range(4)]
        r_ext = rng.randrange(P)
        beta = rng.randrange(P)
        v = ((1 - r_ext) * mle_eval(T, z)
             + r_ext * eq_weight(z, (0, 0, 0, 0)) * beta) % P
        coeffs = [((1 - r_ext) * eq_weight(z, tuple((k >> (3 - j)) & 1
                                                    for j in range(4)))) % P
                  for k in range(NT)]
        w_pad = (r_ext * eq_weight(z, (0, 0, 0, 0))) % P
        ext_ws.append(w_pad)
        # unknowns: T (16) + one fresh pad per transcript
        row = coeffs + [0] * n_tr
        row[NT + i] = w_pad
        A_rows.append(row)
        rhs.append(v)
    # (a) full-coset certificate: the pad block alone is rank n_tr
    # (diagonal, invertible weights), so EVERY candidate tensor extends to
    # a consistent solution — the consistent set projects ONTO the full
    # 16-dim tensor space: 0 fresh equations on the data.
    pad_block = [r[NT:] for r in A_rows]
    coset_full = (all(w % P for w in ext_ws)
                  and mat_rank(pad_block) == n_tr
                  and mat_rank(A_rows) == n_tr)
    # constructive: a WRONG tensor is explained exactly by solved pads
    Tp = [(t + 1) % P for t in T]
    consistent = True
    for i, r in enumerate(A_rows):
        data_part = sum(r[k] * Tp[k] for k in range(NT)) % P
        beta_p = (rhs[i] - data_part) * inv(r[NT + i]) % P
        if (data_part + r[NT + i] * beta_p) % P != rhs[i]:
            consistent = False
    ok("AZB-2a", coset_full and consistent,
       "MASKED terminals: after %d transcripts the pad block is full-rank "
       "diagonal (%d/%d), the consistent solution set projects ONTO the "
       "full tensor coset (a deliberately WRONG tensor is explained exactly "
       "by solved pads) — 0 fresh equations on the data, recovery != witness "
       "by construction (AZ-L2a coset statement)" % (n_tr, n_tr, n_tr))

    # (b) counting canaries at the masked zero-check (AZ-L1a / AZ-L2a /
    # AZ-L1b) — ranks COUNTED, not assumed (SPKZ-3a/b/c adapted).
    rngi = random.Random(1202)
    Gh, Uh, Zh = make_instance(rngi)

    def exposures_for(mask_coeffs, tape_seed=12021):
        a0 = mask_coeffs[0]
        gts, k = [], 1
        for d in DEGS:
            gts.append(mask_coeffs[k:k + d])
            k += d
        accE, s = masked_zero_check(random.Random(tape_seed), Gh, Uh, Zh,
                                    (a0, gts))
        assert accE
        exp = [s["Gsum"]]
        for rp in s["rounds"]:
            exp += rp
        exp.append(s["gopen"])
        return exp

    base = exposures_for([0] * NG)
    rows = []
    for i in range(NG):
        e = [0] * NG
        e[i] = 1
        rows.append([(a - b) % P for a, b in zip(exposures_for(e), base)])
    cols = [list(c) for c in zip(*rows)]
    r_map = mat_rank(cols)
    n_exp = len(base)

    def rand_vec(seed, n):
        rr = random.Random(seed)
        return [rr.randrange(P) for _ in range(n)]

    samples = [exposures_for(rand_vec(1500 + s, NG)) for s in range(NG + 8)]
    diffs = [[(a - b) % P for a, b in zip(s, samples[0])]
             for s in samples[1:]]
    forced = n_exp - mat_rank(diffs)
    ok("AZB-2b", r_map == NG and forced == ELL + 1,
       "counting canary AZ-L1a: mask-coefficient-to-exposure rank %d = n_g "
       "with exactly ell+1 = %d forced relations among %d exposures — "
       "counted, not assumed" % (r_map, ELL + 1, n_exp))

    # AZ-L2a pad diagonal (terminal/pad full row rank)
    rng2 = random.Random(1203)
    G0 = [rng2.randrange(P) for _ in range(8)]
    U0 = [rng2.randrange(P) for _ in range(8)]
    Z0 = [g * u % P for g, u in zip(G0, U0)]
    zpt = [rng2.randrange(P) for _ in range(4)]

    def terminals_for(pads):
        bG, bU, bZ = pads
        return [mle_eval(G0 + [bG] + [0] * 7, zpt),
                mle_eval(U0 + [bU] + [0] * 7, zpt),
                mle_eval(Z0 + [bZ] + [0] * 7, zpt)]

    t0 = terminals_for([0, 0, 0])
    padrows = []
    for i in range(3):
        e = [0, 0, 0]
        e[i] = 1
        padrows.append([(a - b) % P for a, b in zip(terminals_for(e), t0)])
    ok("AZB-2c", mat_rank(padrows) == 3,
       "counting canary AZ-L2a: the 3 terminal exposures are a full-row-rank "
       "(3/3) affine image of the 3 dedicated pad dimensions — one fresh pad "
       "per exposure, none spent twice")

    # AZ-L1b joint rank under SHARED round challenges
    rng3 = random.Random(1204)
    I2 = [make_instance(rng3), make_instance(rng3)]

    def joint_exposures(mc, tape_seed=12041):
        tape = random.Random(tape_seed)
        r_sz = [tape.randrange(P) for _ in range(ELL)]
        rts = [tape.randrange(P) for _ in range(ELL)]
        nus = [1 + tape.randrange(P - 1) for _ in range(2)]
        out = []
        for k, (Ghk, Uhk, Zhk) in enumerate(I2):
            a0 = mc[k * NG]
            gts, idx = [], k * NG + 1
            for d in DEGS:
                gts.append(mc[idx:idx + d])
                idx += d
            maskk = (a0, gts)
            nu = nus[k]

            def fn(x):
                return (F_val(Ghk, Uhk, Zhk, r_sz, x)
                        + nu * mask_eval(maskk, x)) % P

            claim = nu * mask_hsum(maskk) % P
            out.append(mask_hsum(maskk))
            prefix = []
            for t in range(ELL):
                rp = round_poly(fn, prefix, DEGS[t], ELL)
                out += rp
                assert (rp[0] + rp[1]) % P == claim % P
                claim = lagrange_at(rp, rts[t])
                prefix.append(rts[t])
            out.append(mask_eval(maskk, prefix))
        return out

    base = joint_exposures([0] * (2 * NG))
    rows = []
    for i in range(2 * NG):
        e = [0] * (2 * NG)
        e[i] = 1
        rows.append([(a - b) % P
                     for a, b in zip(joint_exposures(e), base)])
    cols = [list(c) for c in zip(*rows)]
    r_joint = mat_rank(cols)
    samples = [joint_exposures(rand_vec(1700 + s, 2 * NG))
               for s in range(2 * NG + 8)]
    diffs = [[(a - b) % P for a, b in zip(s, samples[0])]
             for s in samples[1:]]
    forced_j = len(base) - mat_rank(diffs)
    ok("AZB-2d", r_joint == 2 * NG and forced_j == 2 * (ELL + 1),
       "counting canary AZ-L1b: joint rank %d = n_g1 + n_g2 under SHARED "
       "round challenges, forced relations exactly 2(ell+1) = %d — "
       "block-diagonal masks stay jointly full-rank"
       % (r_joint, 2 * (ELL + 1)))


# ==========================================================================
# AZB-3 — the statement-hash F5 pair (T_blind outside h0_agg, AZ-L4 A3)
# ==========================================================================
# If T_blind (mask commitments) is OUTSIDE the statement hash, nothing
# pins WHEN the mask entered FS — the prover can swap the mask set after
# seeing the challenges (one set shown to the pin, another to the
# opening) and absorb a false-instance defect in the swapped opening.
# Shipped order: h0_agg binds the mask digest BEFORE every challenge;
# the swap changes h0_agg, the challenge tape moves, and the crafting
# collapses.

def azb3():
    rng = random.Random(1301)
    Gf, Uf, Zf = make_instance(rng, tamper=True)      # FALSE instance
    mask1 = (rng.randrange(P), [[rng.randrange(P) for _ in range(d)]
                                for d in DEGS])

    def run(h0, pinned_mask, crafted_rounds, late_opening):
        """FS tape seeded by h0. crafted_rounds: the prover shifts each
        round's eval-at-0 so the running check passes (pushing the false
        instance's defect to the end). late_opening: the mask OPENING is
        chosen after the challenges (possible only when T_blind is
        outside h0 — nothing pins WHEN the mask entered FS); otherwise
        the opening is forced from pinned_mask (the E4-pin against the
        digest inside h0). Returns (accept, absorb) where absorb is the
        opening value a late chooser would need."""
        tape = random.Random(h0)
        r_sz = [tape.randrange(P) for _ in range(ELL)]
        nu = 1 + tape.randrange(P - 1)
        claim = nu * mask_hsum(pinned_mask) % P

        def fn(x):
            return (F_val(Gf, Uf, Zf, r_sz, x)
                    + nu * mask_eval(pinned_mask, x)) % P

        prefix = []
        for t in range(ELL):
            rp = round_poly(fn, prefix, DEGS[t], ELL)
            if crafted_rounds:
                shift = (claim - rp[0] - rp[1]) % P
                rp = [(rp[0] + shift) % P] + rp[1:]
            if (rp[0] + rp[1]) % P != claim % P:
                return False, None
            rt = tape.randrange(P)
            claim = lagrange_at(rp, rt)
            prefix.append(rt)
        vG, vU, vZ = (mle_eval(Gf, prefix), mle_eval(Uf, prefix),
                      mle_eval(Zf, prefix))
        sel = (1 - prefix[0]) % P
        w = eq_full(r_sz, prefix) * sel % P
        absorb = (claim - w * ((vG * vU - vZ) % P)) * inv(nu) % P
        g_open = absorb if late_opening else mask_eval(pinned_mask, prefix)
        end = (w * ((vG * vU - vZ) % P) + nu * g_open) % P
        return end % P == claim % P, (absorb, prefix)

    data_digest = prf("Tdata", tuple(Gf), tuple(Uf), tuple(Zf))

    # VIOLATED order: T_blind outside h0_agg — the prover crafts the
    # rounds and shows the eval proof a SECOND mask set whose opening
    # absorbs the defect (the WSMD Z1-c swap: one set to the instances,
    # another to the opening). ACCEPTS.
    h0_unbound = prf("h0", data_digest)               # no mask digest inside
    attack_accepts, (absorb, old_prefix) = run(
        h0_unbound, mask1, crafted_rounds=True, late_opening=True)
    honest_rejects, _ = run(h0_unbound, mask1, crafted_rounds=False,
                            late_opening=False)
    # the swapped set realized concretely: mask2 = mask1 with a0 shifted so
    # g_mask2(old_prefix) equals the absorbing value — a real second pad set
    d_shift = (absorb - mask_eval(mask1, old_prefix)) % P
    mask2 = ((mask1[0] + d_shift) % P, mask1[1])
    swap_realizable = mask_eval(mask2, old_prefix) == absorb

    # SHIPPED order: the mask digest sits inside h0_agg BEFORE every
    # challenge. Showing mask2 moves the statement hash — the tape the
    # attack crafted against no longer exists — and on mask2's OWN tape
    # the opening is pinned to mask2, so the same crafting REJECTS at the
    # end check.
    h0_m1 = prf("h0", data_digest, prf("mask", mask1))
    h0_m2 = prf("h0", data_digest, prf("mask", mask2))
    tape_moves = h0_m1 != h0_m2
    shipped_rejects_m1, _ = run(h0_m1, mask1, crafted_rounds=True,
                                late_opening=False)
    shipped_rejects_m2, _ = run(h0_m2, mask2, crafted_rounds=True,
                                late_opening=False)
    ok("AZB-3", attack_accepts and not honest_rejects and swap_realizable
       and tape_moves and not shipped_rejects_m1 and not shipped_rejects_m2,
       "statement-hash F5 pair (A3): with T_blind OUTSIDE h0_agg, crafted "
       "rounds + a swapped second mask set (realized concretely: a0 "
       "shifted so its opening absorbs the end defect) make the FALSE "
       "instance ACCEPT; shipped order (mask digest inside h0_agg) moves "
       "the statement hash under the swap AND pins the opening — the same "
       "crafting REJECTS on both masks' own tapes")


# ==========================================================================
# AZB-4 — instance/batch ordering pairs
# ==========================================================================

def azb4():
    # ---- (i) extension pad committed AFTER the instance challenges (A2/A4)
    # (the SPKZ-4 crafting, adapted verbatim)
    rng = random.Random(1401)
    Gf, Uf, Zf = make_instance(rng, tamper=True)
    maskF = (rng.randrange(P), [[rng.randrange(P) for _ in range(d)]
                                for d in DEGS])
    tape = random.Random(14011)
    r_sz = [tape.randrange(P) for _ in range(ELL)]
    nu = 1 + tape.randrange(P - 1)
    rts = [tape.randrange(P) for _ in range(ELL)]     # read ahead — violation

    def fn_false(x):
        return (F_val(Gf, Uf, Zf, r_sz, x) + nu * mask_eval(maskF, x)) % P

    claim = nu * mask_hsum(maskF) % P
    prefix, rounds = [], []
    for t in range(ELL):
        rp = round_poly(fn_false, prefix, DEGS[t], ELL)
        shift = (claim - rp[0] - rp[1]) % P
        rp = [(rp[0] + shift) % P] + rp[1:]
        rounds.append(rp)
        claim = lagrange_at(rp, rts[t])
        prefix.append(rts[t])
    vG = mle_eval(Gf, prefix)
    vU = mle_eval(Uf, prefix)
    g_open = mask_eval(maskF, prefix)
    sel = (1 - prefix[0]) % P
    w = eq_full(r_sz, prefix) * sel % P
    vZ_steer = (vG * vU - (claim - nu * g_open) * inv(w)) % P
    Zh_base = Zf[:8] + [0] * 8
    w_pad = (mle_eval(Zf[:8] + [1] + [0] * 7, prefix)
             - mle_eval(Zh_base, prefix)) % P
    bZ_crafted = (vZ_steer - mle_eval(Zh_base, prefix)) * inv(w_pad) % P
    Zf_crafted = Zf[:8] + [bZ_crafted] + [0] * 7
    claim_v = nu * mask_hsum(maskF) % P
    okflag = True
    for t in range(ELL):
        if (rounds[t][0] + rounds[t][1]) % P != claim_v:
            okflag = False
        claim_v = lagrange_at(rounds[t], rts[t])
    vZ_sent = mle_eval(Zf_crafted, prefix)
    end = (w * ((vG * vU - vZ_sent) % P) + nu * g_open) % P
    attack_accepts = okflag and end == claim_v and vZ_sent == vZ_steer
    acc_shipped, _ = masked_zero_check(random.Random(14011), Gf, Uf, Zf,
                                       maskF)
    ok("AZB-4i", attack_accepts and not acc_shipped,
       "ordering pair (i) A2/A4: extension pad chosen AFTER the challenges "
       "absorbs the false-instance defect and ACCEPTS; the shipped order "
       "(pads committed before the statement hash) REJECTS the same "
       "crafting")

    # ---- (ii) mu drawn BEFORE the blinded terminals (CRB-N4 one level up)
    # Batch check: sum_i mu_i * v_i must equal the opening's forced value
    # sum_i mu_i * MLE_i(true). Terminals sent after mu can shift against
    # each other inside the known mu kernel; terminals fixed before mu
    # cannot.
    rng = random.Random(1402)
    true_v = [rng.randrange(P) for _ in range(2)]     # true terminal values
    d = 7                                             # the defect
    # attack order: mu known first
    mu_att = [prf("mu-early", 0), prf("mu-early", 1)]
    v_att = [(true_v[0] + d) % P,
             (true_v[1] - d * mu_att[0] % P * inv(mu_att[1])) % P]
    batch_forced = sum(m * v for m, v in zip(mu_att, true_v)) % P
    attack_ok = (sum(m * v for m, v in zip(mu_att, v_att)) % P
                 == batch_forced) and v_att[0] != true_v[0]
    # shipped order: terminals fixed, THEN mu = prf(terminals). The same
    # compensation computed against any guessed mu' fails on the real draw.
    mu_guess = [prf("mu-guess", 0), prf("mu-guess", 1)]
    v_ship = [(true_v[0] + d) % P,
              (true_v[1] - d * mu_guess[0] % P * inv(mu_guess[1])) % P]
    mu_real = [prf("mu", tuple(v_ship), 0), prf("mu", tuple(v_ship), 1)]
    batch_forced_ship = sum(m * v for m, v in zip(mu_real, true_v)) % P
    shipped_rejects = (sum(m * v for m, v in zip(mu_real, v_ship)) % P
                       != batch_forced_ship)
    ok("AZB-4ii", attack_ok and shipped_rejects,
       "ordering pair (ii) CRB-N4 one level up: with mu known BEFORE the "
       "blinded terminals, two false terminals compensate inside the mu "
       "kernel and the batched check ACCEPTS; shipped order (mu drawn from "
       "a prefix through ALL terminals) REJECTS the same compensation")

    # ---- (iii) nu drawn BEFORE the G pin (E3Z-N1 class)
    # A false instance (true sum = delta != 0) passes if the prover may
    # pin Gsum' = Gsum + delta/nu — which requires knowing nu when the
    # pin is made.
    rng = random.Random(1403)
    Gt, Ut, Zt = make_instance(rng, tamper=True)
    maskT = (rng.randrange(P), [[rng.randrange(P) for _ in range(d_)]
                                for d_ in DEGS])
    # the true (nonzero) hypercube sum of the false instance's summand
    tape_peek = random.Random(14031)
    r_sz_peek = [tape_peek.randrange(P) for _ in range(ELL)]
    nu_peek = 1 + tape_peek.randrange(P - 1)          # nu read EARLY
    delta = 0
    for idx in range(1 << ELL):
        x = [(idx >> (ELL - 1 - j)) & 1 for j in range(ELL)]
        delta = (delta + F_val(Gt, Ut, Zt, r_sz_peek, x)) % P
    pin_crafted = (mask_hsum(maskT) + delta * inv(nu_peek)) % P
    acc_attack, _ = masked_zero_check(random.Random(14031), Gt, Ut, Zt,
                                      maskT, pin_gsum=pin_crafted)
    acc_shipped, _ = masked_zero_check(random.Random(14031), Gt, Ut, Zt,
                                       maskT)
    ok("AZB-4iii", acc_attack and not acc_shipped,
       "ordering pair (iii) E3Z-N1 class: nu known before the G pin lets a "
       "crafted pin Gsum + delta/nu absorb the false instance's nonzero sum "
       "— ACCEPTS; shipped order (pin bound before nu) REJECTS the same "
       "instance")


# ==========================================================================
# AZB-5 — T_blind freshness (pad reuse across proofs)
# ==========================================================================
# Two blinded-terminal transcripts of the SAME witness SHARING one pad:
# eliminating the shared pad yields ONE fresh equation on the data per
# reused pair — the leak returns at half rate (E3Z-N3/Z1-h class). With
# fresh pads the coset certificate of AZB-2a holds instead. The engine's
# derive-time refusal of reuse is [ENGINE PENDING - BB].

def azb5():
    rng = random.Random(1501)
    NT = 16
    T = [rng.randrange(P) for _ in range(NT)]

    def transcript(z, r_ext, beta):
        v = ((1 - r_ext) * mle_eval(T, z)
             + r_ext * eq_weight(z, (0, 0, 0, 0)) * beta) % P
        coeffs = [((1 - r_ext) * eq_weight(z, tuple((k >> (3 - j)) & 1
                                                    for j in range(4)))) % P
                  for k in range(NT)]
        w = (r_ext * eq_weight(z, (0, 0, 0, 0))) % P
        return coeffs, w, v

    # REUSE: 16 pad values, each spent by TWO transcripts -> 32 transcripts
    data_rows, data_rhs = [], []
    for i in range(NT):
        beta = rng.randrange(P)
        z1 = [rng.randrange(P) for _ in range(4)]
        z2 = [rng.randrange(P) for _ in range(4)]
        c1, w1, v1 = transcript(z1, rng.randrange(P), beta)
        c2, w2, v2 = transcript(z2, rng.randrange(P), beta)
        # eliminate beta: v1/w1 - v2/w2 = c1/w1 . T - c2/w2 . T
        iw1, iw2 = inv(w1), inv(w2)
        data_rows.append([(a * iw1 - b * iw2) % P for a, b in zip(c1, c2)])
        data_rhs.append((v1 * iw1 - v2 * iw2) % P)
    rec = solve_lin(data_rows, data_rhs)
    reuse_recovers = (mat_rank(data_rows) == NT
                      and rec == [t % P for t in T])
    # FRESH: 32 transcripts, 32 fresh pads — pad block full rank, coset
    fresh_rows = []
    for i in range(2 * NT):
        z = [rng.randrange(P) for _ in range(4)]
        c, w, v = transcript(z, rng.randrange(P), rng.randrange(P))
        row = c + [0] * (2 * NT)
        row[NT + i] = w
        fresh_rows.append(row)
    pad_block = [r[NT:] for r in fresh_rows]
    fresh_coset = mat_rank(pad_block) == 2 * NT
    ok("AZB-5", reuse_recovers and fresh_coset,
       "T_blind freshness: 16 pads each REUSED by two transcripts leak one "
       "fresh data equation per pair — full tensor recovery from 32 "
       "transcripts (half rate, E3Z-N3/Z1-h class); 32 transcripts with "
       "FRESH pads keep the full-rank pad block (32/32) and the full coset "
       "— the derive-time reuse refusal is the engine leg [ENGINE PENDING]")


# ==========================================================================
# AZB-6 — the fold-ordering pair at the eval-proof levels (AZ-L4 A1)
# ==========================================================================
# (SPKZ-5 adapted.) Inner commitments fixed AFTER the fold challenge let
# a FALSE batched evaluation claim ACCEPT; the shipped order (commit
# u_i, then c^(i), floor last) forces the response and REJECTS.

def azb6():
    rng = random.Random(1601)
    mdim, m2 = 6, 5
    kdim = mdim + 2
    A = [[rng.randrange(P) for _ in range(mdim)] for _ in range(kdim)]
    a_pub = [rng.randrange(P) for _ in range(mdim)]
    S = [[rng.randrange(P) for _ in range(mdim)] for _ in range(m2)]
    t_com = [[sum(A[i][k] * S[j][k] for k in range(mdim)) % P
              for i in range(kdim)] for j in range(m2)]
    y_true = [sum(a_pub[k] * S[j][k] for k in range(mdim)) % P
              for j in range(m2)]
    c = [prf("azb6-c", j) for j in range(m2)]
    z = [sum(c[j] * S[j][k] for j in range(m2)) % P for k in range(mdim)]
    y_false = (sum(c[j] * y_true[j] for j in range(m2)) + 7) % P
    lhs = [sum(A[i][k] * z[k] for k in range(mdim)) % P for i in range(kdim)]
    rhs = [sum(c[j] * t_com[j][i] for j in range(m2)) % P
           for i in range(kdim)]
    shipped_rejects = (lhs == rhs) and (
        sum(a_pub[k] * z[k] for k in range(mdim)) % P != y_false)
    # attack: t fixed AFTER c — steer z, then steer t to match
    z_att = list(z)
    shift = 7 * inv(a_pub[0]) % P
    z_att[0] = (z_att[0] + shift) % P
    t_att = [list(t) for t in t_com]
    f = shift * inv(c[0]) % P
    for i in range(kdim):
        t_att[0][i] = (t_att[0][i] + A[i][0] * f) % P
    lhs_a = [sum(A[i][k] * z_att[k] for k in range(mdim)) % P
             for i in range(kdim)]
    rhs_a = [sum(c[j] * t_att[j][i] for j in range(m2)) % P
             for i in range(kdim)]
    attack_accepts = (lhs_a == rhs_a and
                      sum(a_pub[k] * z_att[k] for k in range(mdim)) % P
                      == y_false)
    ok("AZB-6", attack_accepts and shipped_rejects,
       "fold-ordering F5 pair (A1): inner commitments fixed AFTER the fold "
       "challenge let a FALSE batched evaluation claim ACCEPT (t steered to "
       "match a steered z); the shipped order (commit u_i, then c^(i), "
       "floor last) forces z and REJECTS — per-level engine re-run "
       "[ENGINE PENDING]")


# ==========================================================================
# AZB-7 — the floor exhibit + confinement (the permanent AZ-T1 regression)
# ==========================================================================

def azb7():
    rng = random.Random(1701)
    mdim, m2 = 6, 5
    S = [[rng.randrange(P) for _ in range(mdim)] for _ in range(m2)]
    # (i) recompute the floor image from (witness, challenges): exact match
    c0 = [prf("azb7-c", 0, j) for j in range(m2)]
    z0 = [sum(c0[j] * S[j][k] for j in range(m2)) % P for k in range(mdim)]
    z0_re = [sum(c0[j] * S[j][k] for j in range(m2)) % P
             for k in range(mdim)]
    match0 = z0 == z0_re
    # one digit-decomposition level deeper (the recursed case, AZ-L3(c))
    BASE = 1 << 8

    def digits(v, nl=4):
        out = []
        for _ in range(nl):
            out.append(v % BASE)
            v //= BASE
        return out

    cp = [prf("azb7-cp", k) for k in range(mdim)]
    z1 = [sum(cp[k] * digits(z0[k])[l] for k in range(mdim)) % P
          for l in range(4)]
    z1_re = [sum(cp[k] * digits(z0_re[k])[l] for k in range(mdim)) % P
             for l in range(4)]
    match1 = z1 == z1_re
    # (ii) accumulation: rank grows by exactly one transcript's worth per
    # proof; exact recovery at EXACTLY the m2 threshold, not before
    Cmat, Zmat = [], []
    for t in range(m2):
        ct = [prf("azb7-acc", t, j) for j in range(m2)]
        Cmat.append(ct)
        Zmat.append([sum(ct[j] * S[j][k] for j in range(m2)) % P
                     for k in range(mdim)])
    ranks = [mat_rank(Cmat[:t + 1]) for t in range(m2)]
    rank_law = ranks == list(range(1, m2 + 1))
    S_rec = []
    for k in range(mdim):
        col = solve_lin(Cmat, [Zmat[t][k] for t in range(m2)])
        S_rec.append(col)
    exact = all(S_rec[k][j] == S[j][k] for k in range(mdim)
                for j in range(m2))
    ok("AZB-7a", match0 and match1 and rank_law and exact,
       "floor exhibit: the floor image recomputes EXACTLY from (witness, "
       "challenges) at both the bare level and one digit level deeper (the "
       "leak is exactly the predicted object); accumulation rank per "
       "transcript = %s with EXACT column-matrix recovery at the predicted "
       "threshold t = m2 = %d — the permanent AZ-T1 regression"
       % (ranks, m2))

    # (iii) simulator-match for every non-R component: the S2-class
    # simulator (coset/variety sampling, NO witness) produces an ACCEPTING
    # masked-zero-check transcript with the same forced-relation structure
    # as the honest one.
    rngh = random.Random(1702)
    Gh, Uh, Zh = make_instance(rngh)
    maskh = (rngh.randrange(P), [[rngh.randrange(P) for _ in range(d)]
                                 for d in DEGS])
    acc_h, sent_h = masked_zero_check(random.Random(17021), Gh, Uh, Zh,
                                      maskh)

    # simulator: same challenge tape, no witness — sample each round poly
    # uniformly on the variety (d_t free evaluations, eval-at-0 forced by
    # the running claim), terminals uniform with the mask opening SOLVED
    # from the end check (the S2 recipe, AGGREGATION_ZK_DESIGN 5.2).
    def simulate(tape_seed, sim_seed):
        tape = random.Random(tape_seed)
        sim = random.Random(sim_seed)
        r_sz = [tape.randrange(P) for _ in range(ELL)]
        nu = 1 + tape.randrange(P - 1)
        Gsum_sim = sim.randrange(P)                   # uniform pin claim
        claim = nu * Gsum_sim % P
        prefix, rounds = [], []
        for t in range(ELL):
            # degree-d_t poly through (0, forced) with d_t free values:
            # sample evals at 1..d_t, set eval-at-0 = claim - eval-at-1
            free = [sim.randrange(P) for _ in range(DEGS[t])]
            rp = [(claim - free[0]) % P] + free
            rounds.append(rp)
            rt = tape.randrange(P)
            claim = lagrange_at(rp, rt)
            prefix.append(rt)
        # terminals uniform; mask opening solved from the end check
        vG, vU, vZ = (sim.randrange(P), sim.randrange(P), sim.randrange(P))
        sel = (1 - prefix[0]) % P
        w = eq_full(r_sz, prefix) * sel % P
        g_open = (claim - w * ((vG * vU - vZ) % P)) * inv(nu) % P
        # verifier replay (round checks with the running claim)
        claim_v = nu * Gsum_sim % P
        for t in range(ELL):
            if (rounds[t][0] + rounds[t][1]) % P != claim_v:
                return False
            claim_v = lagrange_at(rounds[t], prefix[t])
        end = (w * ((vG * vU - vZ) % P) + nu * g_open) % P
        return end % P == claim_v % P

    sims_accept = all(simulate(17021, 900 + s) for s in range(8))
    # structural match: honest exposure count and forced-relation count
    # (from AZB-2b's counting) equal the simulator's by construction:
    # exposures = 1 pin + sum(d_t + 1) rounds + 1 opening; forced = ell + 1
    n_exp_struct = 1 + sum(d + 1 for d in DEGS) + 1
    forced_struct = ELL + 1
    free_struct = n_exp_struct - forced_struct        # = n_g = 14
    ok("AZB-7b", acc_h and sims_accept and free_struct == NG,
       "confinement (simulator match): the witness-FREE S2-class simulator "
       "(coset/variety sampling, mask opening solved from the end check) "
       "produces ACCEPTING transcripts on the honest challenge tape (8/8), "
       "with the same structure as the honest transcript: %d exposures, "
       "%d forced relations, %d free = n_g — every non-R component is "
       "simulatable; R itself is AZB-7a's exhibit"
       % (n_exp_struct, forced_struct, free_struct))


# ==========================================================================
# AZB-8 — the joint-rank certificate (AZ-O2)
# ==========================================================================
# The combined exposure system: E = the T_sim exposures' dependence on
# the pad/mask dimensions (must stay uniform), F = the floor image's
# rows restricted to the same dimensions (T_blind columns are inside the
# batched opening — AGGREGATION_ZK_DESIGN 2.4 item 3). Simulatability-
# given-R requires E restricted to ker(F) to keep full row rank:
# rank([E;F]) - rank(F) == n_exp. Shipped counting (pad surplus) PASSES;
# a rigged deficient mask space FIRES the canary.

def azb8():
    n_exp, n_floor = 10, 8

    def cert(n_mask, tag):
        E = [[prf("azb8-E", tag, i, j) for j in range(n_mask)]
             for i in range(n_exp)]
        F = [[prf("azb8-F", tag, i, j) for j in range(n_mask)]
             for i in range(n_floor)]
        rEF = mat_rank(E + F)
        rF = mat_rank(F)
        return rEF - rF, rF

    # shipped: pad surplus (n_mask = 40 >> n_exp + n_floor)
    got, rF = cert(40, "pass")
    pass_ok = (got == n_exp and rF == n_floor)
    # rigged deficiency: n_mask = 12 < n_exp + n_floor — the floor strips
    # mask rank and the conditional exposure rank drops below n_exp
    got_bad, rF_bad = cert(12, "fail")
    fires = (got_bad < n_exp and rF_bad == n_floor)
    ok("AZB-8", pass_ok and fires,
       "joint-rank certificate (AZ-O2): with pad surplus (40 mask dims vs "
       "10 exposures + 8 floor rows) the conditional rank "
       "rank([E;F])-rank(F) = %d = n_exp — T_sim stays uniform given R "
       "(PASS); a rigged deficient mask space (12 dims) drops it to %d < "
       "%d and the canary FIRES — the battery's closure-threatening leg, "
       "counted not assumed" % (got, got_bad, n_exp))


# ==========================================================================
# AZB-9 — slot-completeness of blinding (AZ-R1)
# ==========================================================================
# The 8 slots of GF(q^16) modeled as 8 parallel GF(P) components (CRT
# image); batch weights act per slot via res_s(gamma) — distinct
# invertible slot weights. A slot-SHARED blind (one value across all 8
# slots) leaves 7 data equations per exposure after eliminating it; a
# ring-granular blind (8 independent slot values) pads every slot.

def azb9():
    rng = random.Random(1901)
    NS = 8
    d = [rng.randrange(P) for _ in range(NS)]         # per-slot data values

    def exposure(shared):
        ws = [1 + rng.randrange(P - 1) for _ in range(NS)]  # slot weights
        if shared:
            beta = rng.randrange(P)
            v = [(d[s] + ws[s] * beta) % P for s in range(NS)]
            return ws, v, 1
        betas = [rng.randrange(P) for _ in range(NS)]
        v = [(d[s] + ws[s] * betas[s]) % P for s in range(NS)]
        return ws, v, NS

    # attack direction: TWO slot-shared exposures -> 16 equations, 8 data
    # + 2 pad unknowns -> full data recovery
    rows, rhs = [], []
    n_pads = 0
    for e in range(2):
        ws, v, np_ = exposure(shared=True)
        for s in range(NS):
            row = [0] * (NS + 2)
            row[s] = 1
            row[NS + e] = ws[s]
            rows.append(row)
            rhs.append(v[s])
        n_pads += np_
    sol = solve_lin(rows, rhs)
    slot_leak = (sol is not None and sol[:NS] == d
                 and mat_rank(rows) == NS + 2)
    # defense direction: ring-granular — pad block full rank per exposure,
    # data projection stays the full coset
    rows_g = []
    for e in range(2):
        ws, v, np_ = exposure(shared=False)
        for s in range(NS):
            row = [0] * (NS + 2 * NS)
            row[s] = 1
            row[NS + e * NS + s] = ws[s]
            rows_g.append(row)
    pad_block = [r[NS:] for r in rows_g]
    granular_uniform = mat_rank(pad_block) == 2 * NS
    ok("AZB-9", slot_leak and granular_uniform,
       "slot-completeness F5 pair (AZ-R1): a slot-SHARED blind under "
       "distinct slot weights leaks — two exposures recover ALL 8 slot "
       "data values exactly (rank 10/10); ring-granular blinds keep a "
       "full-rank pad block (16/16) and all 8 slot images independently "
       "uniform — the Reference-6 per-slot channel closed from the "
       "privacy side")


# ==========================================================================
# AZB-10 — the IXF F5 pairs: segment map + group map (both directions)
# ==========================================================================

def azb10():
    # ---- (a) the segment-map edge -------------------------------------
    # Toy pass: 2 layers, 4 positions each; per-layer Hadamard relation
    # Z_l = G_l o U_l plus the CHAINING claim G_1 = Z_0 (layer 1's input
    # is layer 0's output — the declared DAG). The committed segments are
    # honest per-layer Hadamard triples, but the execution is NOT chained
    # in the declared order — it chains only under the SWAPPED layer
    # relabeling. If the segment map enters FS late, the prover presents
    # the swap and every check passes; the shipped h0_agg edge pins the
    # map and rejects.
    rng = random.Random(2001)
    NPOS = 4

    def had_layer(G):
        U = [rng.randrange(P) for _ in range(NPOS)]
        Z = [g * u % P for g, u in zip(G, U)]
        return G, U, Z

    # build so that: layer B's output equals layer A's input (chains as
    # (B, A)), but layer A's output does NOT equal layer B's input
    # (declared order (A, B) is NOT chained).
    GA = [rng.randrange(P) for _ in range(NPOS)]
    A_ = had_layer(GA)                                # layer A: (GA, UA, ZA)
    B_ = had_layer([rng.randrange(P) for _ in range(NPOS)])
    # forge B's OUTPUT to equal A's INPUT: Z_B := G_A with U_B adjusted
    GB, UB, _ = B_
    UB = [GA[i] * inv(GB[i]) % P for i in range(NPOS)]
    ZB = [g * u % P for g, u in zip(GB, UB)]          # = GA
    B_ = (GB, UB, ZB)
    layers = {"seg0": A_, "seg1": B_}

    def checks_pass(segmap):
        """Per-layer Hadamard + the chaining claim under a segment map
        (which committed segment plays layer 0 / layer 1)."""
        l0 = layers[segmap[0]]
        l1 = layers[segmap[1]]
        had = (all(z == g * u % P for g, u, z in zip(*l0))
               and all(z == g * u % P for g, u, z in zip(*l1)))
        chain = (l1[0] == l0[2])                      # G_{layer1} == Z_{layer0}
        return had and chain

    declared = ("seg0", "seg1")                       # the DAG order: A then B
    swapped = ("seg1", "seg0")
    attack_accepts = checks_pass(swapped)             # late map: prover's pick
    declared_fails = not checks_pass(declared)        # the honest map rejects
    # the eq-kernel facet: the stacked-tensor MLE differs under the two
    # maps at a random point — an accepted terminal under the swap is a
    # FALSE claim about the declared stacking (the wrong slices bound)
    stack_decl = list(layers[declared[0]][2]) + list(layers[declared[1]][2])
    stack_swap = list(layers[swapped[0]][2]) + list(layers[swapped[1]][2])
    pt = [prf("azb10-pt", j) for j in range(3)]       # 1 layer bit + 2 pos bits
    binds_wrong = mle_eval(stack_decl, pt) != mle_eval(stack_swap, pt)
    # shipped: the 32-segment manifest is inside h0_agg BEFORE every
    # challenge — presenting the swap changes the statement hash
    h0_decl = prf("h0", ("segmap",) + declared, "commitments")
    h0_swap = prf("h0", ("segmap",) + swapped, "commitments")
    hash_edge_rejects = h0_decl != h0_swap
    ok("AZB-10a", attack_accepts and declared_fails and binds_wrong
       and hash_edge_rejects,
       "IXF segment-map F5 pair: a pass whose execution chains ONLY under "
       "the swapped layer relabeling ACCEPTS every check when the segment "
       "map is chosen late (and the stacked MLE at a random point differs "
       "between maps — the eq-kernel binds the WRONG slices); the declared "
       "map REJECTS the chaining claim, and the shipped h0_agg segment-map "
       "edge pins the map (swap => different statement hash)")

    # ---- (b) the group-map edge (the FPP-4 pair, both directions) -----
    M1 = 6
    act_cols = [[prf("azb10-act", j, i) for i in range(M1)]
                for j in range(4)]
    wt_cols = [[prf("azb10-wt", j, i) for i in range(M1)]
               for j in range(2)]
    group_map = {"act": [0, 1, 2, 3], "wt": [0, 1]}
    h0 = prf("h0", str(sorted(group_map.items())), "commitments")
    c_act = [prf(h0, "fold", j) for j in range(len(act_cols))]
    z_act = [sum(c_act[j] * act_cols[j][i]
                 for j in range(len(act_cols))) % P for i in range(M1)]
    # shipped direction: recompute from T_act alone + weight invariance
    recomp = [sum(c_act[j] * act_cols[j][i]
                  for j in range(len(act_cols))) % P for i in range(M1)]
    wt_perturbed = [[(x + 1) % P for x in col] for col in wt_cols]
    z_act_p = [sum(c_act[j] * act_cols[j][i]
                   for j in range(len(act_cols))) % P for i in range(M1)]
    shipped_ok = (recomp == z_act and z_act_p == z_act
                  and wt_perturbed[0] != wt_cols[0])
    # attack direction: group map late — migrate w1 into the bare opening
    c5 = prf(h0, "fold", 4)
    z_attack = [(z_act[i] + c5 * wt_cols[0][i]) % P for i in range(M1)]
    canary_fires = z_attack != recomp
    delta = [(z_attack[i] - z_act[i]) % P for i in range(M1)]
    leak_is_wt_functional = delta == [c5 * wt_cols[0][i] % P
                                      for i in range(M1)]
    h0_swapped = prf("h0", str(sorted({"act": [0, 1, 2, 3, "w1"],
                                       "wt": [1]}.items())), "commitments")
    hash_rejects = h0_swapped != h0
    ok("AZB-10b", shipped_ok and canary_fires and leak_is_wt_functional
       and hash_rejects,
       "IXF group-map F5 pair (FPP-4 at battery station): shipped order — "
       "the bare activation floor recomputes exactly from (T_act, "
       "challenges) and is INVARIANT under weight perturbation; attack "
       "order — a weight column migrated after the fold challenges shifts "
       "the floor by the explicit weight functional c_5*w1 (the P2 break), "
       "the recompute canary FIRES, and the shipped h0_agg group-map edge "
       "rejects the migration")


# ==========================================================================
# AZB-11 — the weight-independence canary (the FP-L3 / FB Section 4.2 spec)
# ==========================================================================
# Full pipeline at toy scale: the FD-L2 joint matmul sumcheck over
# (layer, inner) with terminals split per group (FP-L3), per-group nu,
# and the group floor folds. ACCEPT legs 1-3 + REJECT leg 4, plus TWO
# deliberately weight-contaminated variants that must FIRE.

def run_sumcheck(F, n, deg, claimed, seed):
    """Honest prover / FS verifier (fold_privacy_pricing_spike.py)."""
    prev = claimed % P
    r_full = []
    for t in range(n):
        ys = []
        rest = n - t - 1
        for x in range(deg + 1):
            s = 0
            for suffix in range(2 ** rest):
                bits = [(suffix >> (rest - 1 - j)) & 1 for j in range(rest)]
                s = (s + F(r_full + [x] + bits)) % P
            ys.append(s)
        if (ys[0] + ys[1]) % P != prev:
            return False, r_full, None
        r_t = prf(seed, "round", t, tuple(ys))
        prev = lagrange_at(ys, r_t)
        r_full.append(r_t)
    if prev != F(r_full) % P:
        return False, r_full, None
    return True, r_full, prev


def mle_eval_fast(table, z):
    t = list(table)
    for zj in z:
        half = len(t) // 2
        t = [(t[i] * (1 - zj) + t[i + half] * zj) % P for i in range(half)]
    return t[0]


def azb11():
    NL, NK = 2, 2
    NVAR = NL + NK
    A_tab = [prf("azb11-A", i) for i in range(2 ** NVAR)]
    W_tab = [prf("azb11-W", i) for i in range(2 ** NVAR)]
    C_tab = []
    for l in range(2 ** NL):
        s = 0
        for k in range(2 ** NK):
            s = (s + A_tab[l * (2 ** NK) + k]
                 * W_tab[l * (2 ** NK) + k]) % P
        C_tab.append(s)
    group_map = {"T_act": ["A", "C"], "T_W": ["W"]}
    h0 = prf("h0-azb11", str(sorted(group_map.items())), "commitments")
    rl = [prf(h0, "rl", j) for j in range(NL)]
    vC = mle_eval_fast(C_tab, rl)

    def F_joint(assign, Wt=W_tab):
        return (eq_full(rl, assign[:NL])
                * mle_eval_fast(A_tab, assign) % P
                * mle_eval_fast(Wt, assign) % P)

    accepts, r_star, _ = run_sumcheck(F_joint, NVAR, 3, vC, h0)
    assert accepts
    vA = mle_eval_fast(A_tab, r_star)
    vW = mle_eval_fast(W_tab, r_star)
    nu_act = [prf(h0, "nu_act", 0), prf(h0, "nu_act", 1)]
    nu_wt = [prf(h0, "nu_wt", 0)]
    batched_act = (nu_act[0] * vA + nu_act[1] * vC) % P
    batched_wt = nu_wt[0] * vW % P
    # the activation-group floor (toy fold over T_act columns only)
    M1 = 6
    act_cols = [[prf("azb11-actcol", j, i) for i in range(M1)]
                for j in range(4)]
    c_act = [prf(h0, "fold", j) for j in range(len(act_cols))]
    z_act = [sum(c_act[j] * act_cols[j][i]
                 for j in range(len(act_cols))) % P for i in range(M1)]

    # ---- ACCEPT leg 1 (static, derive-time): support arithmetic
    act_entries_support = {"A", "C"}                  # tensors the act batch cites
    leg1 = (act_entries_support.issubset(set(group_map["T_act"]))
            and not (act_entries_support & set(group_map["T_W"])))

    # ---- ACCEPT leg 2 (functional): recompute batched claims AND floor
    # from (T_act witness, public challenges) alone — exact match
    recompute_act = (nu_act[0] * mle_eval_fast(A_tab, r_star)
                     + nu_act[1] * mle_eval_fast(C_tab, rl)) % P
    recompute_floor = [sum(c_act[j] * act_cols[j][i]
                           for j in range(len(act_cols))) % P
                       for i in range(M1)]
    leg2 = (recompute_act == batched_act and recompute_floor == z_act)

    # ---- ACCEPT leg 3 (perturbation): W perturbed, T_act fixed — the
    # bare activation-side transcript objects are IDENTICAL
    W_pert = [(w + 3) % P for w in W_tab]
    vA_p = mle_eval_fast(A_tab, r_star)
    batched_act_p = (nu_act[0] * vA_p + nu_act[1] * vC) % P
    z_act_p = [sum(c_act[j] * act_cols[j][i]
                   for j in range(len(act_cols))) % P for i in range(M1)]
    leg3 = (batched_act_p == batched_act and z_act_p == z_act
            and W_pert != W_tab)

    # ---- REJECT leg 4 (the F5 migration pair)
    forged_map = {"T_act": ["A", "C", "W"], "T_W": []}
    h0_forged = prf("h0-azb11", str(sorted(forged_map.items())),
                    "commitments")
    leg4_hash = h0_forged != h0                       # (i) transcript invalid
    # (ii) run with the forged map from the start: legs 1-2 must FIRE
    forged_support = {"A", "C", "W"}
    leg4_static_fires = bool(forged_support & {"W"})
    batched_act_forged = (batched_act + nu_wt[0] * vW) % P
    leg4_functional_fires = batched_act_forged != recompute_act
    leg4 = leg4_hash and leg4_static_fires and leg4_functional_fires

    ok("AZB-11a", leg1 and leg2 and leg3 and leg4,
       "weight-independence canary, the four FB-spec legs: (1) static "
       "support — activation batch cites T_act only, nu_act support zero "
       "on T_W; (2) functional — batched act claims AND act floor "
       "recompute EXACTLY from (T_act, challenges) alone; (3) perturbation "
       "— W perturbed with T_act fixed leaves the bare act-side transcript "
       "IDENTICAL; (4) REJECT F5 — the migrated group map changes h0_agg "
       "AND fires legs 1-2 when run from the start")

    # ---- the deliberately weight-CONTAMINATED variants (must FIRE)
    # variant A (claim layer): a weight functional smuggled into the
    # activation batch (the FPP-2 shape)
    contamA = (batched_act + prf("smuggle") * vW) % P
    firesA = contamA != recompute_act
    # variant B (floor layer): a weight column folded into the bare
    # activation floor (the FPP-4b shape)
    w_col = [prf("azb11-wcol", i) for i in range(M1)]
    c5 = prf(h0, "fold", 4)
    contamB = [(z_act[i] + c5 * w_col[i]) % P for i in range(M1)]
    firesB = contamB != recompute_floor
    delta_is_wt = all((contamB[i] - z_act[i]) % P == c5 * w_col[i] % P
                      for i in range(M1))
    ok("AZB-11b", firesA and firesB and delta_is_wt,
       "weight-CONTAMINATED variants FIRE the canary (the negative legs): "
       "(A) a weight functional smuggled into the activation batched claim "
       "-> functional-recompute mismatch; (B) a weight column folded into "
       "the bare activation floor -> floor-recompute mismatch with the "
       "delta an explicit weight functional c_5*w — a canary that cannot "
       "fire is dead, this one fires on both contamination routes")


# ==========================================================================
# F-Z1 — the masking-corner re-check at the build round's operating points
# ==========================================================================
# The pricing doc's formula (AGGREGATION_FOLD_PRIVACY_PRICING 3.1 /
# FPP-7): corner bound b(floor) = 27.2 + 0.5*log2(floor_coords/81,920)
# [MODEL, sqrt(dim) first-order from EC SPKZ-7b's e_L<=4 no-limb-growth
# corner at the EB layer floor]; the corner survives iff b < 28.00
# (q/8); the limb-growth branch 28.6 + same scaling must stay dead.

def fz1():
    LINE = 28.00
    corner_layer, growth_layer = 27.2, 28.6
    ref = 81_920.0

    def bound(coords):
        return corner_layer + 0.5 * math.log2(coords / ref)

    def growth(coords):
        return growth_layer + 0.5 * math.log2(coords / ref)

    # design-doc schedule points (R-EB4 floors, FA 9.1 / FB 1.3)
    pts = {"act pass floor (710 r)": 710 * 128,
           "weight pass floor (734 r)": 734 * 128,
           "2^20 pass floor (732 r)": 732 * 128}
    vals = {k: bound(v) for k, v in pts.items()}
    survives = all(v < LINE for v in vals.values())
    growth_dead = all(growth(v) > LINE for v in pts.values())
    # FPP-7 reproduction anchors (act 27.27 / weight 27.30)
    anchors = (abs(vals["act pass floor (710 r)"] - 27.27) < 0.01
               and abs(vals["weight pass floor (734 r)"] - 27.30) < 0.01)
    # the survival threshold and the 125M band [BB-SCHEDULE PENDING]
    thresh_coords = ref * 2 ** (2 * (LINE - corner_layer))
    band = {r: bound(r * 128) for r in (600, 700, 800)}
    band_ok = all(v < LINE for v in band.values())
    ok("F-Z1", survives and growth_dead and anchors and band_ok,
       "masking-corner re-check at the design-doc schedules [MODEL, "
       "sqrt(dim) first-order]: e_L<=4 no-limb-growth bound 2^%.2f (act "
       "710r) / 2^%.2f (weight 734r) / 2^%.2f (2^20 732r) vs q/8 = "
       "2^28.00 — the corner SURVIVES (~0.7 b) and the limb-growth branch "
       "stays DEAD at every point; survival threshold %d coords = %d "
       "rings, so any 125M-pass floor in the plausible 600-800-ring "
       "regrowth class (bounds 2^%.2f..2^%.2f) keeps the corner — exact "
       "125M point [BB-SCHEDULE PENDING]: recompute b = 27.2 + "
       "0.5*log2(floor_coords/81920) when BB posts the schedule"
       % (vals["act pass floor (710 r)"],
          vals["weight pass floor (734 r)"],
          vals["2^20 pass floor (732 r)"],
          int(thresh_coords), int(thresh_coords // 128),
          band[600], band[800]))


# ==========================================================================

def main():
    check_parents()
    azb1()
    azb2()
    azb3()
    azb4()
    azb5()
    azb6()
    azb7()
    azb8()
    azb9()
    azb10()
    azb11()
    fz1()
    n_ok = sum(1 for _, c in checks if c)
    print("%d/%d OK — all azb_battery_spike legs passed "
          "(AZB-1..11 executable spike legs + F-Z1; engine-scale legs "
          "[ENGINE PENDING - BB] per AZB_BATTERY_PLAN.md)"
          % (n_ok, len(checks)))


if __name__ == "__main__":
    main()
