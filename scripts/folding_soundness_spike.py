#!/usr/bin/env python3
"""folding_soundness_spike.py — U-AG4 Agent FC lane (O-8 soundness).

Executable checks for docs/zkmatrix-poc/AGGREGATION_FOLDING_SOUNDNESS.md.
Checks the ARITHMETIC of that document, not the proofs:

  OK1  ring/challenge dictionary at q31 (splitting, set sizes, pigeonhole cap)
  OK2  LS18/C0' hypothesis of [LF] Lemma 2.3 at our ring (margin 1.30x) +
       [LF] paper-instantiation self-checks (their Section 5 numbers)
  OK3  quinary l1-expansion MC (worst 256, mean ~153.6, l1-cap accept rate)
  OK4  norm-growth law over chained folds at toy scale (l_inf closed form,
       depth independence over 20 rounds) + l2 operator-norm convention check
  OK5  knowledge-error accumulation table reproduced from formulas
       (pre-FS union, post-FS x 2(Q+1), headline + margin)
  OK6  challenge-set entropy margins per fold surface (S1/S3/S4 re-derived)
       + LF+ mu*|S|-union arithmetic (single vs double sumcheck at GF(q^16))
  OK7  AFS-L6 fold-binding envelope (l2 route vs naive l_inf-costed route)
       against the R-EB4 validity line 2^30.5
  OK8  NEGATIVE demo A: RLC defect survival = 1/|slot field| — the
       2026-04-30 break reproduced at a fully-split toy ring (rate ~1/17)
       and suppressed at a partially-split one (rate ~1/625)
  OK9  NEGATIVE demo B: fold challenges from a slot-degenerate subset —
       differences non-invertible, a FALSE evaluation claim accepts for
       EVERY challenge in the subset (extraction impossible); the healthy
       set rejects the same forgery except at the per-slot rate

stdlib only; seconds; tiny memory (shared-box rules honored).
"""

import math
import random

random.seed(20260727)

L2 = math.log2
ok_count = 0


def ok(msg):
    global ok_count
    ok_count += 1
    print(f"OK{ok_count}: {msg}")


def fail(msg):
    raise SystemExit(f"FAIL: {msg}")


# ----------------------------------------------------------------------------
# House constants (sources cited in the doc; re-derived here where possible)
# ----------------------------------------------------------------------------
Q31 = 2**31 - 399          # mod.rs Q8
D = 128                    # ring degree
TAU = 16                   # slot-field extension degree (derived below)
NSLOTS = 8
LOG_CS = 128 * L2(5)       # |quinary C| = 5^128
LOG_CK = 16 * L2(Q31)      # |slot-diagonal K set| = q^16
T_CAP = 33                 # R-EB1 (l2 op-norm cap, EB lane MC)
KAPPA = 11                 # R-EB4/kappa correction (EB lane)
REB4_LINE = 30.5           # log2 validity cap on binding bounds (R-EB4)
LOG_Q31 = L2(Q31)
Q_GRIND = 64               # house Q = 2^64 grinding convention (Q-conv)
FS_LOSS = Q_GRIND + 1      # log2(2(Q+1)) ~ 65

# ----------------------------------------------------------------------------
# check 1 — ring / challenge dictionary
# ----------------------------------------------------------------------------
assert Q31 == 2147483249
if Q31 % 256 != 113:
    fail("q31 mod 256 != 113")
if Q31 % 32 != 17:
    fail("q31 mod 32 != 17")
# ord_256(q31): splitting of X^128+1 mod q into (128/ord) factors of deg ord
o, x = 0, 1
for i in range(1, 257):
    x = (x * Q31) % 256
    if x == 1:
        o = i
        break
if o != 16:
    fail(f"ord_256(q31) = {o} != 16")
nslots = 128 // o
if nslots != 8:
    fail("slot count != 8")
if abs(LOG_CS - 297.19) > 0.05:
    fail("quinary set size arithmetic off")
if abs(LOG_CK - 496.0) > 0.01:
    fail("K-set size arithmetic off")
ok(f"dictionary: q31 = 2^31-399, q=113 mod 256, ord_256(q)=16 -> {nslots} "
   f"slots GF(q^16) (2^{LOG_CK:.1f} each); |quinary C| = 5^128 = "
   f"2^{LOG_CS:.1f}; slot-diagonal K-set = q^16 = 2^{LOG_CK:.1f}; "
   f"pigeonhole cap (AFS-L0(c)): ANY strong sampling set <= 2^{LOG_CK:.1f} "
   f"here, <= 2^{LOG_Q31:.1f} at a fully-split ring (the break regime)")

# ----------------------------------------------------------------------------
# check 2 — LS18 / C0' at our ring, and [LF]'s own instantiation
# ----------------------------------------------------------------------------
ls18_bound = Q31 ** (1.0 / 8) / math.sqrt(8)   # [LF] Lemma 2.3 at t=8
max_diff = 4                                    # quinary difference l_inf
margin = ls18_bound / max_diff
if not (1.28 < margin < 1.32):
    fail(f"LS18 margin {margin:.3f} not ~1.30")
# [LF] Section 5 instantiation self-checks (their d=64, q ~ 2^64, t=16)
lf_q = 2**64
lf_ls18 = lf_q ** (1.0 / 16) / math.sqrt(16)
if abs(lf_ls18 - 4.0) > 1e-9:
    fail("[LF] q^{1/16}/4 = 4 reproduction failed")
if abs(64 * L2(4) - 128) > 1e-9:
    fail("[LF] |C_small| = 4^64 = 2^128 reproduction failed")
lf_expansion = 2 * 64  # d*max|coeff| = 64*2
if lf_expansion != 128:
    fail("[LF] expansion bound reproduction failed")
lf_interactive_err = L2(32) - 128  # their 2k/|C_small| at k=16
ok(f"LS18/C0': [LF] Lemma 2.3 at (t=8, q31) needs ||diff||_inf < "
   f"{ls18_bound:.3f}; quinary diff max 4 -> margin {margin:.3f}x = the "
   f"frozen house 1.30x. [LF] Sec.5 self-checks: q^(1/16)/4 = "
   f"{lf_ls18:.1f} > 3, |C_small| = 2^128, expansion <= 128 all reproduced "
   f"(note their own interactive fold term 2k/|C_small| = 2^{lf_interactive_err:.0f})")

# ----------------------------------------------------------------------------
# check 3 — quinary l1 expansion MC (l_inf-route cap candidate)
# ----------------------------------------------------------------------------
N_MC = 20000
CAP_L1 = 160
tot, worst, acc = 0.0, 0, 0
for _ in range(N_MC):
    l1 = sum(abs(random.randint(-2, 2)) for _ in range(D))
    tot += l1
    worst = max(worst, l1)
    if l1 <= CAP_L1:
        acc += 1
mean_l1 = tot / N_MC
rate = acc / N_MC
if not (152.0 < mean_l1 < 155.5):
    fail(f"quinary E||rho||_1 = {mean_l1:.1f} not ~153.6")
if not (0.70 < rate < 0.85):
    fail(f"l1-cap {CAP_L1} accept rate {rate:.3f} outside [0.70, 0.85]")
ok(f"quinary l1 MC ({N_MC} draws): E||rho||_1 = {mean_l1:.1f} (theory "
   f"153.6), observed max {worst} (worst-case 256 = house op_norm(worst) "
   f"= 2D), l1-cap {CAP_L1} accepts {100*rate:.1f}% (~77% CLT) [MODEL row]")

# ----------------------------------------------------------------------------
# toy negacyclic ring helpers
# ----------------------------------------------------------------------------
def ring_mul(a, b, q, d):
    """negacyclic product in Z_q[X]/(X^d+1), centered output."""
    out = [0] * d
    for i, ai in enumerate(a):
        if ai == 0:
            continue
        for j, bj in enumerate(b):
            k = i + j
            if k < d:
                out[k] = (out[k] + ai * bj) % q
            else:
                out[k - d] = (out[k - d] - ai * bj) % q
    return [c if c <= q // 2 else c - q for c in out]


def linf(vec_of_rings):
    return max(abs(c) for r in vec_of_rings for c in r)


def l2norm(vec_of_rings):
    return math.sqrt(sum(c * c for r in vec_of_rings for c in r))


def op2(rho, d):
    """l2 operator norm of negacyclic mult by rho = max |rho(w_j)| over
    primitive 2d-th roots of unity (odd powers)."""
    best = 0.0
    for j in range(1, 2 * d, 2):
        z = complex(0.0)
        for i, c in enumerate(rho):
            ang = math.pi * j * i / d
            z += c * complex(math.cos(ang), math.sin(ang))
        best = max(best, abs(z))
    return best


# ----------------------------------------------------------------------------
# check 4 — norm-growth law over chained folds (AFS-L4), toy scale
# ----------------------------------------------------------------------------
TD, TQ = 16, 12289           # toy ring degree/modulus (12289 = 12*1024+1)
TB = 4                       # digit bound b: digits in (-4, 4)
NINST = 4                    # instances folded per round
MRINGS = 8                   # witness length in ring elements
ROUNDS = 20


def rand_digits():
    return [[random.randint(-(TB - 1), TB - 1) for _ in range(TD)]
            for _ in range(MRINGS)]


def decompose(vec, b, q, d):
    """balanced base-b digit split of a ring vector (AFS-L3 / split_{b,k})."""
    digs = []
    rem = [list(r) for r in vec]
    while any(c != 0 for r in rem for c in r):
        layer = []
        for r in rem:
            row = []
            for c in r:
                dd = c % b
                if dd > b // 2:
                    dd -= b
                row.append(dd)
            layer.append(row)
        digs.append(layer)
        rem = [[(c - lc) // b for c, lc in zip(r, lr)]
               for r, lr in zip(rem, layer)]
    return digs if digs else [[[0] * d for _ in range(MRINGS)]]


max_ratio = 0.0
bounds_seen = set()
wit = [rand_digits() for _ in range(NINST)]
for rnd in range(ROUNDS):
    rhos = [[random.randint(-2, 2) for _ in range(TD)] for _ in range(NINST)]
    fold = [[0] * TD for _ in range(MRINGS)]
    for rho, w in zip(rhos, wit):
        for m in range(MRINGS):
            prod = ring_mul(rho, w[m], TQ, TD)
            fold[m] = [a + b_ for a, b_ in zip(fold[m], prod)]
    # sharp per-sample l_inf bound: sum_i ||rho_i||_1 * (b-1)
    sharp = sum(sum(abs(c) for c in rho) for rho in rhos) * (TB - 1)
    # closed-form worst bound: n_inst * min(2d, 2d) * (b-1)  (l1 worst = 2d)
    closed = NINST * (2 * TD) * (TB - 1)
    got = linf(fold)
    if got > sharp or sharp > closed:
        fail(f"round {rnd}: l_inf {got} > sharp bound {sharp} or "
             f"sharp > closed {closed}")
    max_ratio = max(max_ratio, got / closed)
    bounds_seen.add(closed)
    # re-decompose (F-C4) and feed digits forward: depth-independence
    digs = decompose(fold, TB, TQ, TD)
    wit = (digs + [rand_digits() for _ in range(NINST)])[:NINST]
if len(bounds_seen) != 1:
    fail("round-boundary bound varied with depth — depth-independence broken")
# l2 operator-norm convention (AFS-L6's inequality) on random pairs
for _ in range(50):
    rho = [random.randint(-2, 2) for _ in range(TD)]
    f = rand_digits()
    lhs = l2norm([ring_mul(rho, r, TQ, TD) for r in f])
    rhs = op2(rho, TD) * l2norm(f)
    if lhs > rhs * (1 + 1e-9):
        fail("l2 op-norm inequality violated")
ok(f"norm law (AFS-L4) at toy scale (d={TD}, b={TB}, n_inst={NINST}, "
   f"{ROUNDS} chained fold+decompose rounds): l_inf <= sharp l1 bound <= "
   f"closed form n_inst*2d*(b-1) = {NINST * 2 * TD * (TB - 1)} at EVERY "
   f"round, bound depth-INDEPENDENT (max observed/closed = {max_ratio:.3f}); "
   f"l2 convention ||rho*f||_2 <= op2(rho)*||f||_2 verified on 50 pairs")

# ----------------------------------------------------------------------------
# check 5 — knowledge-error accumulation table (Section 6)
# ----------------------------------------------------------------------------
N_FOLD = 31            # 32 leaves, binary tree or sequential 2-ary
N_INST_MAX = 64        # parametric worst case used in the doc
B_DIGIT = 65           # e<=7 digits: range (-65, 65) class
LOG_M = 22             # witness index bits (2^22 cap class)
B_CLAIMS = 16          # SC-L6 batching count

def log2sum(logs):
    m = max(logs)
    return m + L2(sum(2 ** (x - m) for x in logs))

row1 = L2(N_FOLD * N_INST_MAX) - LOG_CS                      # fold RLC
row2 = L2(N_FOLD * ((2 * B_DIGIT + 1) * LOG_M + 2 * N_INST_MAX)) - LOG_CK
mu_lfp = 3 + D * 1                                           # LF+ mu, k=1
# LF+ mu*|S|-union, TWO-parallel-sumcheck form (the REQUIRED form at our
# ring under FS — see check 6): mu*|S| * ((log k)^2 + (2 log n)^2)/|C|^2
row4 = (L2(mu_lfp) + LOG_CS + L2(L2(KAPPA) ** 2 + (2 * LOG_M) ** 2)
        - 2 * LOG_CK + L2(N_FOLD))
row5 = L2(B_CLAIMS) - LOG_CS                                 # SC-L6
row6 = -285.0   # decide, exact-digit column pre-FS (SC 3.3 table [MODEL])
row7 = -485.0   # GKR/sumcheck SZ class (DB 10.4)
pre_fs = log2sum([row1, row2, row4, row5, row6, row7])
post_fs = pre_fs + FS_LOSS
margin_bits = -post_fs - 128
if not (-288 < pre_fs < -283):
    fail(f"pre-FS union 2^{pre_fs:.1f} outside expected band")
if margin_bits < 85:
    fail(f"post-FS margin {margin_bits:.1f} < 85 bits")
# folding cost vs unfolded pass (2^-220-class post-FS per SC 3.3):
# positive = folded error is larger (bits of margin given up)
unfolded_post = -285.0 + FS_LOSS
fold_cost_bits = post_fs - unfolded_post
ok(f"knowledge-error table: rows (log2 pre-FS) fold-RLC {row1:.1f}, "
   f"fold-SZ {row2:.1f}, LF+-union {row4:.1f}, batching {row5:.1f}, "
   f"decide {row6:.1f}, GKR {row7:.1f}; pre-FS union 2^{pre_fs:.1f}; "
   f"post-FS (x2(Q+1), Q=2^64) 2^{post_fs:.1f} -> PASS vs 2^-128 with "
   f"{margin_bits:.1f} bits margin; folding 32 layers costs "
   f"{fold_cost_bits:.1f} bits vs the unfolded pass [MODEL]")

# ----------------------------------------------------------------------------
# check 6 — entropy margins per fold surface + LF+ union arithmetic
# ----------------------------------------------------------------------------
s1 = FS_LOSS + L2(N_FOLD * 2 * N_INST_MAX) - LOG_CS
s3 = FS_LOSS + L2(N_FOLD) + (L2((2 * B_DIGIT + 1) * LOG_M + 2 * N_INST_MAX)
                             - LOG_CK)
s4_need = 128 + FS_LOSS + 7      # class need incl. count slack
s4_room = LOG_CK - s4_need
s4_broken = LOG_Q31 - s4_need    # fully-split cap vs need (negative = dead)
m1, m3 = -s1 - 128, -s3 - 128
if m1 < 85 or m3 < 250:
    fail(f"surface margins S1 {m1:.1f} / S3 {m3:.1f} below expectation")
if s4_broken > -100:
    fail("fully-split cap not clearly broken?!")
# LF+ mu|S|-union: single vs double sumcheck at GF(q^16). NOTE the |S|
# union does NOT cancel against |C| at our ring (|S| = 2^297.2 != |C| =
# 2^496, unlike their |S| = |C| setting): the single-sumcheck per-round
# term is 2^-185-class — fine interactively, but under the house Q = 2^64
# FS charging it lands ABOVE the 2^-128 line. Two-parallel is REQUIRED.
union_single = (L2(mu_lfp) + LOG_CS
                + L2(L2(KAPPA) + 2 * LOG_M + 10) - LOG_CK)   # per round
union_double = (L2(mu_lfp) + LOG_CS
                + L2(L2(KAPPA) ** 2 + (2 * LOG_M) ** 2) - 2 * LOG_CK)
single_pass_total = union_single + L2(N_FOLD)
single_post_fs = single_pass_total + FS_LOSS
double_post_fs = union_double + L2(N_FOLD) + FS_LOSS
if single_pass_total > -128:
    fail("single-sumcheck union fails even interactively?!")
if single_post_fs < -128:
    fail(f"expected the single-sumcheck FS failure, got 2^{single_post_fs:.1f}")
if double_post_fs > -400:
    fail(f"two-sumcheck union unexpectedly large 2^{double_post_fs:.1f}")
ok(f"entropy margins (re-derived, not imported): S1 fold-RLC post-FS "
   f"2^{s1:.1f} (margin +{m1:.1f} bits), S3 K-sumchecks 2^{s3:.1f} "
   f"(+{m3:.1f} bits), S4 structural room {s4_room:.0f} bits at our ring "
   f"vs {-s4_broken:.0f} bits SHORT at a fully-split ring (break regime); "
   f"LF+ mu*|S|-union at our ring (|S| != |C|, no cancellation): SINGLE "
   f"sumcheck 2^{single_pass_total:.1f} interactive (passes) but "
   f"2^{single_post_fs:.1f} post-FS -> FAILS 2^-128; TWO-parallel "
   f"2^{double_post_fs:.1f} post-FS -> PASSES. Their Remark 4.9 form is "
   f"REQUIRED at our ring, not optional")

# ----------------------------------------------------------------------------
# check 7 — AFS-L6 fold-binding envelope vs the R-EB4 line
# ----------------------------------------------------------------------------
TAIL = 1.3
rows = []
worst_pass_headroom = None
knife_edge_seen = False
for n_inst in (2, 4, 8, 16):
    for e in (2, 4, 7):
        b_1 = 2 ** (e - 1)                     # digit magnitude bound
        for log_m_acc in (10, 11, 12, 13):
            m_acc = 2 ** log_m_acc
            # honest accumulator l_inf bound: concentration + restart (Q4.1)
            # per-coeff std ~ sqrt(n_inst * E[c^2] * d / 3) * b_1
            b_acc = TAIL * math.sqrt(n_inst * 2.0 * D / 3.0) * b_1
            # l2 route (AFS-L6): 8 * T_cap * sqrt(d * m_acc) * B_acc
            beta_l2 = L2(8 * T_CAP * math.sqrt(D * m_acc) * b_acc)
            # naive route: l_inf theorem costed in l2 with T_inf = 256
            beta_naive = L2(8 * 256 * math.sqrt(D * m_acc) * b_acc)
            ok_l2 = beta_l2 <= REB4_LINE
            ok_nv = beta_naive <= REB4_LINE
            rows.append((n_inst, e, log_m_acc, beta_l2, ok_l2, beta_naive,
                         ok_nv))
            if ok_l2:
                h = REB4_LINE - beta_l2
                if worst_pass_headroom is None or h < worst_pass_headroom:
                    worst_pass_headroom = h
            if ok_nv and REB4_LINE - beta_naive < 1.0:
                knife_edge_seen = True
# representative row for the doc (n_inst=2, e=7, m_acc=2^11)
rep = next(r for r in rows if r[:3] == (2, 7, 11))
n_l2_pass = sum(1 for r in rows if r[4])
n_nv_pass = sum(1 for r in rows if r[6])
if not rep[4]:
    fail("representative envelope row (2, e=7, 2^11) fails the l2 route")
if n_l2_pass <= n_nv_pass:
    fail("l2 route not strictly wider than naive l_inf costing")
ok(f"AFS-L6 envelope ({len(rows)} rows over n_inst x e x m_acc): l2 route "
   f"passes {n_l2_pass}/{len(rows)} vs naive l_inf-costed {n_nv_pass}/"
   f"{len(rows)} (l2 recovers log2(256/33) = {L2(256/33):.2f} bits/row); "
   f"representative (n_inst=2, e=7, m_acc=2^11): B_acc = 2^"
   f"{L2(TAIL * math.sqrt(2 * 2.0 * D / 3.0) * 64):.1f}, beta_fold(l2) = "
   f"2^{rep[3]:.1f} vs line 2^{REB4_LINE} (headroom "
   f"{REB4_LINE - rep[3]:.1f} bits), naive route 2^{rep[5]:.1f} "
   f"({'knife-edge/FAIL band' if (rep[5] > REB4_LINE - 1) else 'ok'}); "
   f"worst passing l2 headroom {worst_pass_headroom:.1f} bits; "
   f"knife-edge rows exist on the naive route: {knife_edge_seen}")

# ----------------------------------------------------------------------------
# check 8 — NEGATIVE demo A: defect survival = 1/|slot field|
# ----------------------------------------------------------------------------
# fully split toy: d=8, q=17 (17 = 1 mod 16); slots F_17 via roots of X^8=-1
TQA, TDA = 17, 8
roots = [pow(3, j, TQA) for j in range(1, 16, 2)]   # odd powers of g=3
assert all(pow(r, 8, TQA) == TQA - 1 for r in roots)


def eval_at(f, r, q):
    acc, p = 0, 1
    for c in f:
        acc = (acc + c * p) % q
        p = (p * r) % q
    return acc


N_TRIALS = 20000
hits = 0
target = 5  # fixed nonzero slot residue the adversary must hit
for _ in range(N_TRIALS):
    gamma = [random.randrange(TQA) for _ in range(TDA)]
    if eval_at(gamma, roots[0], TQA) == target:
        hits += 1
rate_full = hits / N_TRIALS
exp_full = 1.0 / 17
sd = math.sqrt(exp_full * (1 - exp_full) / N_TRIALS)
if abs(rate_full - exp_full) > 4 * sd:
    fail(f"fully-split survival {rate_full:.4f} != ~{exp_full:.4f}")

# partially split toy: d=8, q=5; X^8+1 = (X^4+2)(X^4+3) mod 5, slots GF(5^4)
def mod_x4p2(f, q):
    """reduce deg<8 poly mod (X^4 + 2) mod q -> 4 coeffs."""
    out = list(f[:4])
    for i in range(4, 8):
        out[i - 4] = (out[i - 4] - 2 * f[i]) % q
    return tuple(c % q for c in out)


hits2 = 0
target2 = (1, 2, 3, 4)
for _ in range(N_TRIALS):
    gamma = [random.randrange(5) for _ in range(8)]
    if mod_x4p2(gamma, 5) == target2:
        hits2 += 1
rate_part = hits2 / N_TRIALS
exp_part = 1.0 / 625
if hits2 > 8 * max(1.0, N_TRIALS * exp_part):
    fail(f"partially-split survival {rate_part:.5f} >> ~{exp_part:.5f}")
ok(f"BREAK DEMO A (2026-04-30 precedent): RLC defect survival at a "
   f"fully-split toy ring (slots F_17) measured {rate_full:.4f} ~ 1/17 = "
   f"{exp_full:.4f} — {L2(17):.1f} bits/slot, the broken regime; at a "
   f"partially-split toy ring (slots GF(5^4)) measured {rate_part:.5f} ~ "
   f"1/625 = {exp_part:.5f} — the slot-field-size law; at the house ring "
   f"the same law gives 2^-{LOG_CS:.0f} (quinary) / 2^-{LOG_CK:.0f} "
   f"(K-draw) per challenge")

# ----------------------------------------------------------------------------
# check 9 — NEGATIVE demo B: slot-degenerate fold-challenge subset
# ----------------------------------------------------------------------------
# C_bad = challenges vanishing in slot 1 (root roots[0]) of the q=17 ring.
# Differences also vanish there -> non-invertible; the AFS-L1 quotient
# does not exist; a witness perturbation v supported ONLY in slot 1 is
# invisible to every folded output -> a FALSE slot-1 evaluation claim
# accepts for EVERY challenge in C_bad. Healthy set: caught except ~1/17.
r0 = roots[0]


def sample_cbad():
    """uniform ring element with slot-1 residue 0: subtract f(r0)*e1 where
    e1 is the slot-1 idempotent-ish interpolant; construct directly by
    sampling 7 coeffs and solving the 8th so f(r0) = 0."""
    while True:
        f = [random.randrange(TQA) for _ in range(TDA)]
        # solve last coeff: f(r0) = 0  ->  c7 = -(partial)/r0^7
        part = sum(c * pow(r0, i, TQA) for i, c in enumerate(f[:7])) % TQA
        inv = pow(pow(r0, 7, TQA), TQA - 2, TQA)
        f[7] = (-part * inv) % TQA
        if any(f):
            return f


# v: supported only in slot 1 — interpolate: v(r0)=1, v(r_j)=0 for j>0
# Lagrange over the 8 roots, coefficients via solving linear system by
# direct construction: v(X) = prod_{j>0}(X - r_j) * const
v = [1]
for rj in roots[1:]:
    nv = [0] * (len(v) + 1)
    for i, c in enumerate(v):
        nv[i + 1] = (nv[i + 1] + c) % TQA
        nv[i] = (nv[i] - c * rj) % TQA
    v = nv
v = v[:TDA] + [0] * (TDA - len(v))  # degree 7 exactly
c0 = eval_at(v, r0, TQA)
v = [(c * pow(c0, TQA - 2, TQA)) % TQA for c in v]
assert eval_at(v, r0, TQA) == 1
assert all(eval_at(v, rj, TQA) == 0 for rj in roots[1:])

# two challenges in C_bad: difference kills v exactly
rho_a, rho_b = sample_cbad(), sample_cbad()
diff = [(a - b) % TQA for a, b in zip(rho_a, rho_b)]
if all(eval_at(diff, rj, TQA) != 0 for rj in roots):
    fail("C_bad difference unexpectedly invertible")
prod = ring_mul(diff, [c if c <= TQA // 2 else c - TQA for c in v], TQA, TDA)
if any(c % TQA for c in prod):
    fail("(rho-rho')*v != 0 — degeneracy construction broken")

# forged instance: witness w vs w+v differ in slot 1 only; the folded
# output rho*w == rho*(w+v) for ALL rho in C_bad -> false claim accepts
w = [random.randrange(TQA) for _ in range(TDA)]
w_forged = [(a + b) % TQA for a, b in zip(w, v)]
accept_bad, accept_healthy = 0, 0
TRIES = 2000
for _ in range(TRIES):
    rho = sample_cbad()
    fa = ring_mul(rho, [c if c <= TQA // 2 else c - TQA for c in w], TQA, TDA)
    fb = ring_mul(rho, [c if c <= TQA // 2 else c - TQA for c in w_forged],
                  TQA, TDA)
    if [c % TQA for c in fa] == [c % TQA for c in fb]:
        accept_bad += 1
for _ in range(TRIES):
    rho = [random.randrange(TQA) for _ in range(TDA)]  # healthy: full set
    fa = ring_mul(rho, [c if c <= TQA // 2 else c - TQA for c in w], TQA, TDA)
    fb = ring_mul(rho, [c if c <= TQA // 2 else c - TQA for c in w_forged],
                  TQA, TDA)
    if [c % TQA for c in fa] == [c % TQA for c in fb]:
        accept_healthy += 1
if accept_bad != TRIES:
    fail(f"degenerate-set forgery accepted only {accept_bad}/{TRIES}")
exp_h = TRIES / 17.0
if accept_healthy > 3 * exp_h + 10:
    fail(f"healthy-set forgery acceptance {accept_healthy} too high")
ok(f"BREAK DEMO B (F5-pair shape): fold challenges from the "
   f"slot-degenerate subset C_bad (slot-1 residue 0): differences "
   f"NON-invertible (AFS-L1 quotient undefined), forged witness w+v "
   f"(false slot-1 claim) folds IDENTICALLY to w for {accept_bad}/{TRIES} "
   f"= ALL C_bad challenges — binding/extraction broken; the healthy "
   f"full-entropy set accepts the same forgery {accept_healthy}/{TRIES} "
   f"~ 1/17 per draw (per-slot law), and the house quinary/K sets put "
   f"that rate at 2^-297 / 2^-496")

# ----------------------------------------------------------------------------
# check 10 — F-IF1 verification arithmetic (FA's IXF interface, landed)
# ----------------------------------------------------------------------------
# F-IF1.5 norm-law chain: gamma_z = OP_CONC * 2^(e0-1) * sqrt(N_limb * D),
# N_limb(pass) = 32 * N_limb(layer). Verify the RELATIVE chain against
# FA's committed slots (layer e0=5 headroom 0.94 b at the exact-digit
# gate; pass e0=2 headroom ~0.87 b; per-level-gate e0=1 ~0.33 b).
sqrt32_bits = 0.5 * L2(32)
if abs(sqrt32_bits - 2.5) > 1e-12:
    fail("sqrt(32) != +2.5 bits")
layer_head_e5 = 0.94                       # FA slot (layer, e0=5, gate 22.12)
# 31-bit-class limb chain l0 = ceil(31/e0): e0 5 -> 2 shifts gamma by
# 2^(2-5) * sqrt(ceil(31/2)/ceil(31/5)) — the class-mix caveat is R-FC2
shift_5to2 = (2 - 5) + 0.5 * L2(math.ceil(31 / 2) / math.ceil(31 / 5))
pass_head_e2 = layer_head_e5 - sqrt32_bits - shift_5to2
neg_e5 = layer_head_e5 - sqrt32_bits       # e0=5 kept at pass scope
shift_2to1 = (1 - 2) + 0.5 * L2(math.ceil(31 / 1) / math.ceil(31 / 2))
gate_shift = L2(2 ** 22.12 / 2 ** 21.07)   # exact-digit -> per-level gate
pass_head_e1 = pass_head_e2 - gate_shift - shift_2to1
if neg_e5 >= 0:
    fail("FA negative check contradicted: e0=5 survives x32?!")
if abs(pass_head_e2 - 0.87) > 0.15 or abs(pass_head_e1 - 0.33) > 0.15:
    fail(f"F-IF1.5 headroom chain off: e0=2 {pass_head_e2:.2f} vs ~0.87, "
         f"e0=1 {pass_head_e1:.2f} vs ~0.33")
# IXF budget: no claim-layer fold challenges -> drop rows 1/2/4; add 5
# extra K-rounds per instance (~9 instances) and +3 eval-proof levels
ixf_extra = L2(9 * 5 * 3 + 3 * 60) - LOG_CK       # SZ class, generous
ixf_pre = log2sum([row5, row6, row7, ixf_extra])
ixf_post = ixf_pre + FS_LOSS
if not (-222 < ixf_post < -218):
    fail(f"IXF budget 2^{ixf_post:.1f} outside expected band")
ok(f"F-IF1 verification arithmetic: sqrt(32) = +{sqrt32_bits:.1f} b exactly; "
   f"e0=5 at pass scope goes NEGATIVE ({neg_e5:.2f} b — FA's negative "
   f"check confirmed); re-derivation chain gives e0=2 headroom "
   f"{pass_head_e2:.2f} b (FA ~0.87) and e0=1 {pass_head_e1:.2f} b "
   f"(FA ~0.33) — consistent within 0.1 b on the 31-bit limb chain "
   f"[class-mix caveat = R-FC2]; IXF pass budget (no claim-layer fold "
   f"challenges, +5 K-rounds x instances, +3 levels) post-FS "
   f"2^{ixf_post:.1f} — the unfolded class, folding via IXF costs ~0 bits")

print(f"\nALL {ok_count}/10 checks PASS — arithmetic of "
      f"AGGREGATION_FOLDING_SOUNDNESS.md reproduced (norm law, error "
      f"budget, entropy margins, AFS-L6 envelope, break demos, F-IF1 "
      f"verification).")
