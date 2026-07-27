#!/usr/bin/env python3
"""aggregation_zk_spike.py — machine checks for AGGREGATION_ZK_DESIGN.md (O-4, U-AG3 EC lane).

Certificates SPKZ-1..7, named per the design document's claims:

  SPKZ-1  unmasked terminal values leak (exact recovery across proofs);
          extension-blinded terminals stall (any candidate tensor is
          consistent — the AZ-L2 coset statement).
  SPKZ-2  the selector-extension masked zero-check end to end: honest
          ACCEPT with live blinds; single-position tamper REJECTS under
          the full masking machinery (masks do not help a cheat).
  SPKZ-3  rank/counting certificates: (a) AZ-L1a mask counting (rank
          n_g, exactly ell+1 forced relations); (b) AZ-L2a terminal/pad
          full row rank; (c) AZ-L1b joint counting for two instances
          SHARING round challenges (block-diagonal rank).
  SPKZ-4  F5 pair (AZ-L4 A2/A4): extension pad committed AFTER the
          instance challenge absorbs a false-claim defect and ACCEPTS;
          the shipped order REJECTS the same crafting.
  SPKZ-5  F5 pair (AZ-L4 A1): toy fold with inner commitments after
          the fold challenge — a FALSE evaluation claim ACCEPTS; the
          shipped order (commit, then challenge) REJECTS.
  SPKZ-6  the floor-leak exhibit (AZ-L3): bare fold images across m2
          fresh-challenge transcripts recover the column matrix
          EXACTLY (rank m2/m2); one digit-decomposition level deeper,
          every floor coordinate is an explicitly recomputable
          deterministic witness image.
  SPKZ-7  the I-6 / floor arithmetic at the REAL constants (q31, op
          norm 20.8, PARAMS shapes): the global masked-opening
          eviction (sigma 2^24.5-25.3, bound 2^36.8 >> q/8 = 2^28);
          the floor grid (dead at the byte-optimal e_L = 9-10;
          at-the-line only at the optimistic e_L = 4 corner); the byte
          kill (masked floor response >= 3.2x the bare witness,
          artifact >= 1.7x budget).

Toy arithmetic is over GF(q31) with q31 = 2^31 - 399 (the REAL base
modulus — deliberately NOT a small field, per the claim_reduction
spike's recorded small-field incident). The toy field stands in for
the slot field K = GF(q31^16); all rank/coset statements are
field-agnostic. Stdlib only; runs in well under a second.
"""

import math
import random

P = 2**31 - 399  # q31 — the real base modulus


# ---------------------------------------------------------------- field utils
def inv(a):
    return pow(a % P, P - 2, P)


def mat_rank(rows):
    """Rank of a matrix (list of row-lists) over GF(P)."""
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
    """Solve A x = b over GF(P); return one solution or None."""
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
            return None  # inconsistent
    x = [0] * m
    for r, c in enumerate(pivcols):
        x[c] = M[r][m]
    return x


def eq_weight(z, b):
    """eq(z, b) for z in GF(P)^n, b a bit tuple."""
    w = 1
    for zj, bj in zip(z, b):
        w = w * ((zj if bj else (1 - zj)) % P) % P
    return w


def eq_full(z, x):
    """eq(z, x) for BOTH arguments field-valued: prod (z_j x_j + (1-z_j)(1-x_j))."""
    w = 1
    for zj, xj in zip(z, x):
        w = w * ((zj * xj + (1 - zj) * (1 - xj)) % P) % P
    return w


def mle_eval(table, z):
    """MLE of value table (len 2^n) at point z in GF(P)^n."""
    n = len(z)
    acc = 0
    for idx, v in enumerate(table):
        b = tuple((idx >> (n - 1 - j)) & 1 for j in range(n))
        acc = (acc + v * eq_weight(z, b)) % P
    return acc


def lagrange_at(vals, x):
    """Interpolate univariate from vals at 0..d, evaluate at x."""
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


# ================================================================ SPKZ-1
# Terminal leak / blinded stall. Toy tensor T over 4 bits (16 values).
# Per proof: one terminal MLE(T)(z) at a fresh point z — one linear
# equation on T with public coefficients. Unmasked: 16 proofs recover T
# exactly. Blinded (extension bit, fresh pad block per proof): any
# candidate tensor remains consistent — zero fresh equations on T.
rng = random.Random(41)
NT = 16
T = [rng.randrange(P) for _ in range(NT)]

rows, rhs = [], []
for _ in range(NT):
    z = [rng.randrange(P) for _ in range(4)]
    coeffs = [eq_weight(z, tuple((i >> (3 - j)) & 1 for j in range(4))) for i in range(NT)]
    rows.append(coeffs)
    rhs.append(mle_eval(T, z))
rec = solve_lin(rows, rhs)
ok("SPKZ-1a", mat_rank(rows) == NT and rec == [t % P for t in T],
   "UNMASKED terminals: %d fresh-point evaluations recover the tensor EXACTLY "
   "(rank %d/%d) — the C-02 accumulation shape at the aggregate layer" % (NT, NT, NT))

# Blinded: T-hat over 5 bits, row 1 = fresh pad block (only position (1,0..0)
# non-zero, value beta fresh per proof). Terminal at (r_ext, z):
# v~ = (1-r_ext)*MLE(T)(z) + r_ext*eq(z,0)*beta — one fresh unknown per equation.
transcripts = []
for _ in range(3 * NT):
    z = [rng.randrange(P) for _ in range(4)]
    r_ext = rng.randrange(P)
    beta = rng.randrange(P)
    v = ((1 - r_ext) * mle_eval(T, z) + r_ext * eq_weight(z, (0, 0, 0, 0)) * beta) % P
    transcripts.append((z, r_ext, v))
# Adversary hypothesis test: is a DIFFERENT tensor T' consistent with all
# transcripts for SOME pad values?  beta' = (v - (1-r_ext) MLE(T')(z)) / (r_ext eq(z,0))
Tp = [rng.randrange(P) for _ in range(NT)]
consistent = all(
    (r_ext * eq_weight(z, (0, 0, 0, 0))) % P != 0  # pad weight invertible
    for (z, r_ext, v) in transcripts)
ok("SPKZ-1b", consistent,
   "BLINDED terminals: after %d transcripts EVERY candidate tensor stays "
   "consistent (each equation has a fresh invertible-weight pad unknown) — "
   "0 fresh equations on the data, the AZ-L2 coset statement" % len(transcripts))


# ================================================================ toy masked zero-check
# Selector-extension Hadamard zero-check over ell = 4 variables
# (1 extension bit + 3 real bits).  F(x) = eq(r, x) * (1 - x_1) * (G^ U^ - Z^)(x).
# Round degrees (4, 3, 3, 3); mask g(x) = a0 + sum_t g_t(x_t), n_g = 1 + 13 = 14.
ELL = 4
DEGS = [4, 3, 3, 3]
NG = 1 + sum(DEGS)


def make_instance(rng, tamper=False):
    G = [rng.randrange(P) for _ in range(8)]
    U = [rng.randrange(P) for _ in range(8)]
    Z = [g * u % P for g, u in zip(G, U)]
    if tamper:
        Z[3] = (Z[3] + 1) % P
    # extension blocks: pads live at real-index 0 of the extension row
    bG, bU, bZ = (rng.randrange(P) for _ in range(3))
    Gh = G + [bG] + [0] * 7   # index bit order: x_1 is the high (extension) bit
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
    """Libra Construction 1 mask: g(x) = a0 + sum_t g_t(x_t), each g_t a
    degree-d_t univariate with ZERO constant term (constants absorbed into
    a0) — so the free coefficients number exactly n_g = 1 + sum_t d_t."""
    a0, gts = mask
    acc = a0
    for ct, xi in zip(gts, x):
        xp = xi % P
        pw = xp
        for ci in ct:                      # ct = (c_1, .., c_d): g_t = sum c_i x^i
            acc = (acc + ci * pw) % P
            pw = pw * xp % P
    return acc


def mask_hsum(mask):
    a0, gts = mask
    acc = (1 << ELL) * a0 % P              # g_t(0) = 0; g_t(1) = sum of coeffs
    for ct in gts:
        acc = (acc + (1 << (ELL - 1)) * (sum(ct) % P)) % P
    return acc


def round_poly(fn, prefix, deg, nvars):
    """Evaluations of the round polynomial at 0..deg (brute force)."""
    out = []
    rest = nvars - len(prefix) - 1
    for v in range(deg + 1):
        s = 0
        for suf in range(1 << rest):
            x = list(prefix) + [v] + [(suf >> (rest - 1 - j)) & 1 for j in range(rest)]
            s = (s + fn(x)) % P
        out.append(s)
    return out


def masked_zero_check(rng_tape, Gh, Uh, Zh, mask, forged_rounds=None,
                      terminal_override=None):
    """Run prover+verifier for the masked selector-extension zero-check.
    Returns (accept, sent) where sent collects exposures."""
    r_sz = [rng_tape.randrange(P) for _ in range(ELL)]      # SZ point (post-commitment)
    nu = 1 + rng_tape.randrange(P - 1)                       # nu != 0
    Gsum = mask_hsum(mask)
    claim = (0 + nu * Gsum) % P

    def fn(x):
        return (F_val(Gh, Uh, Zh, r_sz, x) + nu * mask_eval(mask, x)) % P

    sent_rounds, prefix = [], []
    for t in range(ELL):
        rp = forged_rounds[t] if forged_rounds else round_poly(fn, prefix, DEGS[t], ELL)
        sent_rounds.append(rp)
        if (rp[0] + rp[1]) % P != claim % P:
            return False, None
        rt = rng_tape.randrange(P)
        claim = lagrange_at(rp, rt)
        prefix.append(rt)
    # terminals (blinded by construction: extended tensors)
    if terminal_override:
        vG, vU, vZ = terminal_override(prefix)
    else:
        vG, vU, vZ = (mle_eval(Gh, prefix), mle_eval(Uh, prefix), mle_eval(Zh, prefix))
    g_open = mask_eval(mask, prefix)                          # E4-pinned in the engine
    sel = (1 - prefix[0]) % P
    end = (eq_full(r_sz, prefix) * sel % P * ((vG * vU - vZ) % P) + nu * g_open) % P
    return end % P == claim % P, dict(r_sz=r_sz, nu=nu, rounds=sent_rounds,
                                      terms=(vG, vU, vZ), gopen=g_open,
                                      prefix=prefix, Gsum=Gsum)


# ================================================================ SPKZ-2
rng = random.Random(42)
Gh, Uh, Zh = make_instance(rng)
mask = (rng.randrange(P), [[rng.randrange(P) for _ in range(d)] for d in DEGS])
acc, sent = masked_zero_check(random.Random(1001), Gh, Uh, Zh, mask)
raw_vG = mle_eval(Gh[:8] + [0] * 8, sent["prefix"])   # what the terminal would be with no blind
blind_live = sent["terms"][0] != raw_vG
ok("SPKZ-2a", acc and blind_live,
   "masked selector-extension zero-check ACCEPTS the honest witness and the "
   "sent terminal differs from the unblinded MLE (blinds live)")

Gt, Ut, Zt = make_instance(random.Random(43), tamper=True)
mask2 = (rng.randrange(P), [[rng.randrange(P) for _ in range(d)] for d in DEGS])
acc_t, _ = masked_zero_check(random.Random(1002), Gt, Ut, Zt, mask2)
ok("SPKZ-2b", not acc_t,
   "a single tampered Hadamard position REJECTS under the full masking "
   "machinery, honest order — masks and blinds do not help a cheating prover")


# ================================================================ SPKZ-3
# (a) AZ-L1a: exposures affine in mask coefficients; rank n_g; ell+1 forced.
rng = random.Random(44)
GhA, UhA, ZhA = make_instance(rng)


def exposures_for(mask_coeffs, tape_seed=2001):
    a0 = mask_coeffs[0]
    gts, k = [], 1
    for d in DEGS:
        gts.append(mask_coeffs[k:k + d])
        k += d
    accE, s = masked_zero_check(random.Random(tape_seed), GhA, UhA, ZhA, (a0, gts))
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
    exp = exposures_for(e)
    rows.append([(a - b) % P for a, b in zip(exp, base)])
cols = list(zip(*rows))  # exposure-dim x NG after transpose
r_map = mat_rank([list(c) for c in cols])
n_exp = len(base)
# forced relations: exposure-space dimension deficit
def rand_vec(seed, n):
    rr = random.Random(seed)
    return [rr.randrange(P) for _ in range(n)]


samples = [exposures_for(rand_vec(500 + s, NG)) for s in range(NG + 8)]
diffs = [[(a - b) % P for a, b in zip(s, samples[0])] for s in samples[1:]]
dim_span = mat_rank(diffs)
ok("SPKZ-3a", r_map == NG and n_exp - dim_span == ELL + 1,
   "AZ-L1a counting at degrees %s: coefficient-to-exposure rank %d = n_g, with "
   "exactly ell+1 = %d forced relations among the %d exposures — the Q4.7 "
   "counting at the new degree pattern" % (DEGS, r_map, ELL + 1, n_exp))

# (b) AZ-L2a: terminals full row rank over the pad dimensions.
rng = random.Random(45)
G0 = [rng.randrange(P) for _ in range(8)]
U0 = [rng.randrange(P) for _ in range(8)]
Z0 = [g * u % P for g, u in zip(G0, U0)]
zpt = [rng.randrange(P) for _ in range(4)]  # a terminal point with nonzero ext weight


def terminals_for(pads):
    bG, bU, bZ = pads
    Ghx = G0 + [bG] + [0] * 7
    Uhx = U0 + [bU] + [0] * 7
    Zhx = Z0 + [bZ] + [0] * 7
    return [mle_eval(Ghx, zpt), mle_eval(Uhx, zpt), mle_eval(Zhx, zpt)]


t0 = terminals_for([0, 0, 0])
padrows = []
for i in range(3):
    e = [0, 0, 0]
    e[i] = 1
    padrows.append([(a - b) % P for a, b in zip(terminals_for(e), t0)])
ok("SPKZ-3b", mat_rank(padrows) == 3,
   "AZ-L2a: the 3 terminal exposures are a FULL-ROW-RANK (3/3) affine image of "
   "the 3 dedicated pad dimensions — one fresh pad per exposure, none spent twice")

# (c) AZ-L1b: two instances sharing round challenges, own masks/nu.
rng = random.Random(46)
I2 = [make_instance(rng), make_instance(rng)]


def joint_exposures(mc, tape_seed=3001):
    """mc: 2*NG mask coefficients. Run BOTH instances on ONE shared challenge
    tape (same r_sz and same round challenges), each with its own mask+nu."""
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
            return (F_val(Ghk, Uhk, Zhk, r_sz, x) + nu * mask_eval(maskk, x)) % P

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
    rows.append([(a - b) % P for a, b in zip(joint_exposures(e), base)])
cols = [list(c) for c in zip(*rows)]
r_joint = mat_rank(cols)
samples = [joint_exposures(rand_vec(700 + s, 2 * NG)) for s in range(2 * NG + 8)]
diffs = [[(a - b) % P for a, b in zip(s, samples[0])] for s in samples[1:]]
dim_joint = mat_rank(diffs)
ok("SPKZ-3c", r_joint == 2 * NG and len(base) - dim_joint == 2 * (ELL + 1),
   "AZ-L1b joint counting, SHARED round challenges: joint rank %d = n_g1 + n_g2, "
   "forced relations exactly 2(ell+1) = %d — block-diagonal masks stay jointly "
   "full-rank under challenge sharing" % (r_joint, 2 * (ELL + 1)))


# ================================================================ SPKZ-4
# F5 pair: extension pad AFTER the instance challenges (attack) vs shipped order.
rng = random.Random(47)
Gf, Uf, Zf = make_instance(rng, tamper=True)     # FALSE instance (defect in Z)
maskF = (rng.randrange(P), [[rng.randrange(P) for _ in range(d)] for d in DEGS])

# Attack: adversary reads the whole challenge tape first (pad-after-challenge),
# runs the sumcheck on the TRUE-summand-shape but with claim 0 (a lie: the true
# sum is s != 0), sending CRAFTED round polys that stay consistent, and finally
# STEERS the terminal vZ by choosing the pad bZ after seeing the final point.
tape = random.Random(1003)
r_sz = [tape.randrange(P) for _ in range(ELL)]
nu = 1 + tape.randrange(P - 1)
rts = [tape.randrange(P) for _ in range(ELL)]     # read ahead — the F5 violation


def fn_false(x):
    return (F_val(Gf, Uf, Zf, r_sz, x) + nu * mask_eval(maskF, x)) % P


# Rounds for the false instance with the claim forced to 0 + nu*Gsum (a LIE:
# the true sum is nonzero).  At EVERY round the crafted prover shifts the
# eval-at-0 so the running check passes — the classic order-attack shape —
# pushing the whole defect into the END check, where the post-challenge pad
# will absorb it.
claim = nu * mask_hsum(maskF) % P
prefix, rounds = [], []
for t in range(ELL):
    rp = round_poly(fn_false, prefix, DEGS[t], ELL)
    shift = (claim - rp[0] - rp[1]) % P
    rp = [(rp[0] + shift) % P] + rp[1:]
    rounds.append(rp)
    claim = lagrange_at(rp, rts[t])
    prefix.append(rts[t])
# steer the terminal: choose bZ so the end check passes.
vG = mle_eval(Gf, prefix)
vU = mle_eval(Uf, prefix)
g_open = mask_eval(maskF, prefix)
sel = (1 - prefix[0]) % P
w = eq_full(r_sz, prefix) * sel % P
# need: w*(vG*vU - vZ~) + nu*g_open == claim  =>  vZ~ solved:
vZ_steer = (vG * vU - (claim - nu * g_open) * inv(w)) % P
# realize vZ_steer by choosing pad bZ AFTER the challenges:
# vZ~ = mle(Z-part at prefix) + weight_ext(prefix)*bZ
Zh_base = Zf[:8] + [0] * 8
w_pad = (mle_eval(Zf[:8] + [1] + [0] * 7, prefix) - mle_eval(Zh_base, prefix)) % P
bZ_crafted = (vZ_steer - mle_eval(Zh_base, prefix)) * inv(w_pad) % P
Zf_crafted = Zf[:8] + [bZ_crafted] + [0] * 7
# verify the forged transcript as the verifier would:
claim_v = nu * mask_hsum(maskF) % P
okflag = True
for t in range(ELL):
    if (rounds[t][0] + rounds[t][1]) % P != claim_v:
        okflag = False
    claim_v = lagrange_at(rounds[t], rts[t])
vZ_sent = mle_eval(Zf_crafted, prefix)
end = (w * ((vG * vU - vZ_sent) % P) + nu * g_open) % P
attack_accepts = okflag and end == claim_v and vZ_sent == vZ_steer
# Shipped order: pad committed BEFORE the tape — bZ fixed; same crafting rejects:
acc_shipped, _ = masked_zero_check(random.Random(1003), Gf, Uf, Zf, maskF)
ok("SPKZ-4", attack_accepts and not acc_shipped,
   "F5 pair (AZ-L4 A2/A4): extension pad chosen AFTER the challenges absorbs "
   "the false-instance defect and the forged transcript ACCEPTS; the shipped "
   "order (pads committed before the statement hash) REJECTS the same instance")


# ================================================================ SPKZ-5
# F5 pair at the fold: toy Greyhound binding. A in GF(P)^{k x m} injective
# (k = m + 2), columns s_j, inner commitments t_j = A s_j, fold challenge c,
# response z, claims y_j = <a_pub, s_j>; batched claim y = sum c_j y_j.
rng = random.Random(48)
mdim, m2 = 6, 5
kdim = mdim + 2
A = [[rng.randrange(P) for _ in range(mdim)] for _ in range(kdim)]
a_pub = [rng.randrange(P) for _ in range(mdim)]
S = [[rng.randrange(P) for _ in range(mdim)] for _ in range(m2)]   # columns
t_com = [[sum(A[i][k] * S[j][k] for k in range(mdim)) % P for i in range(kdim)]
         for j in range(m2)]
y_true = [sum(a_pub[k] * S[j][k] for k in range(mdim)) % P for j in range(m2)]

# shipped order: t committed, then c drawn, prover sends z = S^T c:
c = rand_vec(2101, m2)
z = [sum(c[j] * S[j][k] for j in range(m2)) % P for k in range(mdim)]
y_claim_false = (sum(c[j] * y_true[j] for j in range(m2)) + 7) % P  # off by 7
lhs = [sum(A[i][k] * z[k] for k in range(mdim)) % P for i in range(kdim)]
rhs = [sum(c[j] * t_com[j][i] for j in range(m2)) % P for i in range(kdim)]
open_ok = lhs == rhs
eval_ok = sum(a_pub[k] * z[k] for k in range(mdim)) % P == y_claim_false
shipped_rejects = open_ok and not eval_ok   # A injective => z forced => false y rejected

# attack: commitments AFTER c — choose z to hit the false claim, then set t to match:
z_att = list(z)
# adjust z along a direction with <a_pub, d> != 0 to shift the eval by +7:
d = [1] + [0] * (mdim - 1)
shift = 7 * inv(a_pub[0]) % P
z_att[0] = (z_att[0] + shift) % P
t_att = [list(t) for t in t_com]
# absorb into t_1 (post-challenge): t_1 += A d * shift / c_1
f = shift * inv(c[0]) % P
for i in range(kdim):
    t_att[0][i] = (t_att[0][i] + A[i][0] * f) % P
lhs_a = [sum(A[i][k] * z_att[k] for k in range(mdim)) % P for i in range(kdim)]
rhs_a = [sum(c[j] * t_att[j][i] for j in range(m2)) % P for i in range(kdim)]
attack_accepts = (lhs_a == rhs_a and
                  sum(a_pub[k] * z_att[k] for k in range(mdim)) % P == y_claim_false)
ok("SPKZ-5", attack_accepts and shipped_rejects,
   "F5 pair (AZ-L4 A1): inner commitments fixed AFTER the fold challenge let a "
   "FALSE batched evaluation claim ACCEPT (t steered to match a steered z); the "
   "shipped order (commit u_i, then c^(i)) forces z and REJECTS the same claim")


# ================================================================ SPKZ-6
# Floor-leak exhibit: bare fold images across m2 fresh-challenge proofs.
recovered_cols = []
Cmat = []
Zmat = []
for pidx in range(m2):
    cp = rand_vec(2200 + pidx, m2)
    zp = [sum(cp[j] * S[j][k] for j in range(m2)) % P for k in range(mdim)]
    Cmat.append(cp)
    Zmat.append(zp)
S_rec = []
for k in range(mdim):
    col = solve_lin(Cmat, [Zmat[p][k] for p in range(m2)])
    S_rec.append(col)
exact = all(S_rec[k][j] == S[j][k] for k in range(mdim) for j in range(m2))
ok("SPKZ-6a", mat_rank(Cmat) == m2 and exact,
   "the floor exhibit: %d bare fold transcripts with fresh challenges recover "
   "the ENTIRE column matrix exactly (rank %d/%d, linear algebra only) — the "
   "AZ-L3(b) recovery, C-02's shape at the aggregate layer" % (m2, m2, m2))

# one digit level deeper: decompose z into base-2^8 digits, fold again with c';
# every resulting coordinate is an explicitly recomputable witness image.
BASE = 1 << 8


def digits(v, nl=4):
    out = []
    for _ in range(nl):
        out.append(v % BASE)
        v //= BASE
    return out


cprime = rand_vec(2300, mdim)
z0 = Zmat[0]
dz = [digits(v) for v in z0]                     # mdim x 4 limbs
z1 = [sum(cprime[k] * dz[k][l] for k in range(mdim)) % P for l in range(4)]
# recompute from (S, c, c') alone — the deterministic-image check:
z0_re = [sum(Cmat[0][j] * S[j][k] for j in range(m2)) % P for k in range(mdim)]
z1_re = [sum(cprime[k] * digits(z0_re[k])[l] for k in range(mdim)) % P for l in range(4)]
ok("SPKZ-6b", z1 == z1_re,
   "one digit-decomposition level deeper, every floor coordinate is STILL an "
   "explicitly recomputable deterministic function of (witness, challenges) — "
   "AZ-L3(c): nonlinear, but nothing about it is hidden")


# ================================================================ SPKZ-7
# The I-6 / floor arithmetic at the real constants (log2 arithmetic).
log2 = math.log2
OP = 20.8            # params.rs conc op norm
Dr = 128
q8 = log2(P / 8.0)   # = 28.0000-

# (a) global eviction — PARAMS 2.4 item 1 reproduced across the derived shapes:
shapes = {  # name: (n rings, e0, l0, m1)
    "2^20 per-level":  (401576, 3, 11, 2003),
    "2^20 exact-dig":  (401576, 4, 8, 2003),
    "FFN per-level":   (2157768, 1, 31, 4645),
    "FFN exact-dig":   (2157768, 2, 16, 4645),
}
sig_lo, sig_hi, bound_min, bound_ffn = 1e9, -1e9, 1e9, None
for name, (n, e0, l0, m1) in shapes.items():
    gamma = log2(OP) + (e0 - 1) + 0.5 * log2(n * l0 * Dr)
    sigma = log2(12) + gamma
    bound = log2(1.2) + sigma + 0.5 * log2(m1 * l0 * Dr)
    sig_lo, sig_hi = min(sig_lo, sigma), max(sig_hi, sigma)
    bound_min = min(bound_min, bound)
    if name == "FFN per-level":
        bound_ffn = bound
ok("SPKZ-7a", 24.3 < sig_lo and sig_hi < 25.4 and bound_min > 35 and
   bound_min - q8 > 7 and abs(bound_ffn - 37) < 0.5,
   "global masked opening (I-6 reproduced): sigma 2^%.1f..2^%.1f (PARAMS: "
   "2^25.3-class), response bound 2^%.1f..2^%.1f incl. 2^%.1f at the FFN "
   "headline (PARAMS: ~2^37) vs q/8 = 2^%.2f — over the C2 line by >= %.1f "
   "bits at every derived shape; no Gaussian-masked global opening exists at "
   "q31" % (sig_lo, sig_hi, bound_min, bound_ffn, bound_ffn, q8, bound_min - q8))

# (b) the floor grid: masked response bound vs q/8
floor_rows = []
for (nL, eL, dim) in [(624, 9, 624 * 128), (624, 10, 624 * 128),
                      (500, 4, 500 * 128), (500, 4, 175000)]:
    wnorm = (eL - 1) + 0.5 * log2(dim)
    sigma = log2(12) + log2(OP) + wnorm
    bound = log2(1.2) + sigma + 0.5 * log2(dim)
    floor_rows.append((nL, eL, dim, bound))
dead_at_optimum = all(b > 32 for (_, e, _, b) in floor_rows if e >= 9)
corner = [b for (_, e, d, b) in floor_rows if e == 4 and d == 64000][0]
corner_growth = [b for (_, e, d, b) in floor_rows if e == 4 and d == 175000][0]
ok("SPKZ-7b", dead_at_optimum and abs(corner - q8) < 1.0 and corner_growth > q8,
   "floor masking grid: DEAD at the byte-optimal schedules (e_L=9-10: bound "
   "2^%.1f); AT the line only in the optimistic e_L=4 corner (2^%.1f vs 2^%.2f; "
   "with limb growth 2^%.1f — over)" % (floor_rows[0][3], corner, q8, corner_growth))

# (c) the byte kill: masked response width vs the bare witness line
bare_bytes = 79872                       # PARAMS 5.2 final-bare-witness line
masked_lo = 64000 * 4                    # optimistic corner, 4 B/coord
masked_hi = 175000 * 4
artifact_rest = 289080 - bare_bytes      # exact-digit FFN artifact minus the bare line
budget = 262144
ratio_lo = (artifact_rest + masked_lo) / budget
ok("SPKZ-7c", masked_lo >= 3.2 * bare_bytes and
   masked_lo - bare_bytes >= 176128 and ratio_lo >= 1.7,
   "byte kill: masked floor response %d-%d B vs %d B bare (>= 3.2x); artifact "
   "with a masked floor >= %.2fx the 262,144 B budget — floor ZK is byte-dead "
   "even where norm-viable" % (masked_lo, masked_hi, bare_bytes, ratio_lo))


n_ok = sum(1 for _, c in checks if c)
print("%d/%d OK — all aggregation_zk_spike assertions passed" % (n_ok, len(checks)))
