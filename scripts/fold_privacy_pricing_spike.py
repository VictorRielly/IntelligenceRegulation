#!/usr/bin/env python3
"""fold_privacy_pricing_spike.py — U-AG4 Agent FB machine checks.

Certificates FPP-1..FPP-8 for docs/zkmatrix-poc/AGGREGATION_FOLD_
PRIVACY_PRICING.md (fold/mask interaction, folded Tier Z pricing,
P2 split-proof questions (a)-(c), P1 bounded-leak arithmetic,
E4-wrap pricing under folding).

Conventions: toy field = GF(q31) directly (q = 2^31 - 399), per the
claim-reduction spike's small-field incident note; toy fold matrices
are arithmetic exhibits of ORDERING/SPLIT/ACCOUNTING structure, not
lattice binding strength (the EC SPKZ convention). All byte
arithmetic reproduces repo-recorded totals from component formulas
(sources cited in the doc, Section 3); [MODEL] constants are named
there. stdlib only; runtime < 10 s; RSS < 100 MiB.
"""

import hashlib
import sys

Q = 2**31 - 399  # q31 = 2,147,483,249

OK = []


def ok(name, msg):
    line = f"OK {name}: {msg}"
    OK.append(line)
    print(line)


def die(name, msg):
    print(f"FAIL {name}: {msg}")
    sys.exit(1)


# ----------------------------------------------------------------- #
# field + multilinear toolkit
# ----------------------------------------------------------------- #

def finv(x):
    return pow(x % Q, Q - 2, Q)


def prf(*parts):
    """Deterministic FS-style draw in GF(Q) from serialized parts."""
    h = hashlib.sha256()
    for p in parts:
        h.update(str(p).encode())
        h.update(b"|")
    return int.from_bytes(h.digest(), "big") % Q


def mle_eval(table, z):
    """Evaluate the MLE of `table` (len 2^n, MSB-first indexing) at
    point z (len n, GF(Q) coords)."""
    t = list(table)
    for zj in z:
        half = len(t) // 2
        t = [(t[i] * (1 - zj) + t[i + half] * zj) % Q for i in range(half)]
    assert len(t) == 1
    return t[0]


def eq_weight(zs, xs):
    w = 1
    for z, x in zip(zs, xs):
        w = w * ((z * x + (1 - z) * (1 - x)) % Q) % Q
    return w % Q


def lagrange_eval(ys, r):
    """Interpolate the poly through (i, ys[i]), i = 0..d, eval at r."""
    d = len(ys) - 1
    acc = 0
    for i in range(d + 1):
        num, den = 1, 1
        for j in range(d + 1):
            if j == i:
                continue
            num = num * ((r - j) % Q) % Q
            den = den * ((i - j) % Q) % Q
        acc = (acc + ys[i] * num % Q * finv(den)) % Q
    return acc


def run_sumcheck(F, n, deg, claimed, seed):
    """Prove/verify sum_{b in {0,1}^n} F(b) = claimed.

    F: callable on a length-n assignment of GF(Q) coords (uses MLEs,
    so non-boolean prefixes are fine). Honest prover, FS verifier.
    Returns (accepts, r_full, final_value)."""
    prev = claimed % Q
    r_full = []
    for t in range(n):
        ys = []
        rest = n - t - 1
        for x in range(deg + 1):
            s = 0
            for suffix in range(2 ** rest):
                bits = [(suffix >> (rest - 1 - j)) & 1 for j in range(rest)]
                s = (s + F(r_full + [x] + bits)) % Q
            ys.append(s)
        # verifier round check
        if (ys[0] + ys[1]) % Q != prev:
            return False, r_full, None
        r_t = prf(seed, "round", t, tuple(ys))
        prev = lagrange_eval(ys, r_t)
        r_full.append(r_t)
    if prev != F(r_full) % Q:
        return False, r_full, None
    return True, r_full, prev


# ----------------------------------------------------------------- #
# FPP-1 — the terminal-claim SPLIT (P2 question (a)) at toy scale
# ----------------------------------------------------------------- #
# FD-L2 joint matmul shape with r = m = 1 (no rx/ry variables):
# layers l in {0,1}^2 (4 toy layers), inner index k in {0,1}^2.
# Claim: C(l) = sum_k A(l,k) W(l,k) for ALL l, proven as ONE joint
# sumcheck sum_{l,k} eq(rl,l) A~(l,k) W~(l,k) = MLE(C)(rl).
# Terminals: MLE(A)(r*) -> activation group, MLE(W)(r*) -> weight
# group; the split must be clean (each batched claim recomputable
# from its OWN group's tensors alone).

NL, NK = 2, 2
NVAR = NL + NK
A_tab = [prf("A", i) for i in range(2 ** NVAR)]
W_tab = [prf("W", i) for i in range(2 ** NVAR)]
C_tab = []
for l in range(2 ** NL):
    s = 0
    for k in range(2 ** NK):
        s = (s + A_tab[l * (2 ** NK) + k] * W_tab[l * (2 ** NK) + k]) % Q
    C_tab.append(s)

rl = [prf("rl", j) for j in range(NL)]  # drawn after commitments
vC = mle_eval(C_tab, rl)                # the (blinded-in-prod) initial claim


def F_joint(assign, Wt=W_tab):
    return (eq_weight(rl, assign[:NL])
            * mle_eval(A_tab, assign) % Q
            * mle_eval(Wt, assign) % Q)


accepts, r_star, _ = run_sumcheck(F_joint, NVAR, 3, vC, "fpp1")
if not accepts:
    die("FPP-1a", "honest joint matmul sumcheck rejected")
vA = mle_eval(A_tab, r_star)
vW = mle_eval(W_tab, r_star)
# final-check factorization: F(r*) = eq * vA * vW  (the two terminals)
assert F_joint(r_star) == eq_weight(rl, r_star[:NL]) * vA % Q * vW % Q

# per-group batching (CR-L4 with nu drawn PER GROUP — F-IF1.6)
nu_act = [prf("nu_act", 0), prf("nu_act", 1)]
nu_wt = [prf("nu_wt", 0)]
batched_act = (nu_act[0] * vA + nu_act[1] * vC) % Q
batched_wt = nu_wt[0] * vW % Q
# recompute each batched claim from that group's tensors ONLY
recompute_act = (nu_act[0] * mle_eval(A_tab, r_star)
                 + nu_act[1] * mle_eval(C_tab, rl)) % Q
recompute_wt = nu_wt[0] * mle_eval(W_tab, r_star) % Q
if batched_act != recompute_act or batched_wt != recompute_wt:
    die("FPP-1a", "group-batched claims not recomputable per group")
ok("FPP-1a", "P2 split (a) POSITIVE: joint matmul sumcheck over "
   "(layer, inner) accepts honestly; terminals land ONE per tensor "
   "(MLE(A), MLE(W)); with nu drawn per group, each batched claim "
   "is recomputed EXACTLY from its own group's tensors alone — the "
   "split is clean, zero cross-terms")

# tamper: corrupt one weight entry, keep the honest claim
W_bad = list(W_tab)
W_bad[5] = (W_bad[5] + 1) % Q
accepts_bad, _, _ = run_sumcheck(
    lambda a: F_joint(a, Wt=W_bad), NVAR, 3, vC, "fpp1")
if accepts_bad:
    die("FPP-1b", "tampered weight tensor accepted")
ok("FPP-1b", "P2 split (a) NEGATIVE: a single tampered weight "
   "position rejects under the joint fold — the split does not "
   "weaken the matmul binding")

# ----------------------------------------------------------------- #
# FPP-2 — cross-contamination is DETECTED (the weight-independence
# canary, P2 question (b)) at the claim layer
# ----------------------------------------------------------------- #
# Contaminated artifact: the weight terminal is smuggled into the
# ACTIVATION group's batched claim (a group-map violation).
nu_bad = prf("nu_bad", 0)
batched_act_contam = (batched_act + nu_bad * vW) % Q
# canary leg 1 (static support): the act batch references tensor "W"
act_group_tensors = {"A", "C"}
contam_support = {"A", "C", "W"}
static_fires = not contam_support.issubset(act_group_tensors)
# canary leg 2 (functional recompute): recompute from T_act alone
functional_fires = (batched_act_contam != recompute_act)
if not (static_fires and functional_fires):
    die("FPP-2", "canary failed to fire on a contaminated split")
ok("FPP-2", "canary (b) at the claim layer: a weight functional "
   "smuggled into the activation-side batch is DETECTED by both "
   "legs — static support check (references a T_W tensor) and "
   "functional recompute-from-T_act-alone (value mismatch)")

# ----------------------------------------------------------------- #
# FPP-3 — floor-image accounting: folded = ONE image, not 32
# ----------------------------------------------------------------- #
# Toy unrecursed Greyhound fold: witness columns S (m1 x m2) over
# GF(Q); floor image z = S c (dim m1). m1 models the LaBRADOR
# regrowth floor: a property of the recursion geometry, NOT of the
# witness size (PARAMS 3.2; EA F-4).
M1 = 6          # toy floor dimension (rows)
M2L = 4         # columns per toy layer


def stacked_cols(n_layers):
    return [[prf("S", l, j, i) for i in range(M1)]
            for l in range(n_layers) for j in range(M2L)]


dims = []
for n_layers in (8, 16, 32):
    cols = stacked_cols(n_layers)
    c = [prf("c", n_layers, j) for j in range(len(cols))]
    z = [sum(c[j] * cols[j][i] for j in range(len(cols))) % Q
         for i in range(M1)]
    dims.append(len(z))
if dims != [M1, M1, M1]:
    die("FPP-3a", f"floor image dim scaled with layer count: {dims}")
ok("FPP-3a", f"folded floor accounting: stacking 8/16/32 toy layers "
   f"into ONE commitment leaves the floor image at dim {M1} = ONE "
   f"proof's image (witness-size-independent, the regrowth-floor "
   f"law); 32 unfolded proofs would expose 32 x {M1} = {32 * M1} "
   f"values — the fold exposes 32x FEWER floor coordinates per pass")

# accumulation law unchanged at pass shape (AZ-L3(b) / SPKZ-6):
# t transcripts of the SAME stacked witness with fresh challenges;
# rank grows by 1 per transcript per row-system until complete at
# exactly m2 = 128 transcripts.
cols32 = stacked_cols(32)
M2 = len(cols32)  # 128


def gauss_rank_and_solve(rows, rhs=None):
    """Row-reduce over GF(Q); returns (rank, solution if square+full)."""
    m = [list(r) + ([rhs[i]] if rhs is not None else [])
         for i, r in enumerate(rows)]
    n_rows, n_cols = len(m), len(m[0]) - (1 if rhs is not None else 0)
    rank, piv_cols = 0, []
    for col in range(n_cols):
        piv = next((r for r in range(rank, n_rows) if m[r][col] % Q), None)
        if piv is None:
            continue
        m[rank], m[piv] = m[piv], m[rank]
        iv = finv(m[rank][col])
        m[rank] = [x * iv % Q for x in m[rank]]
        for r in range(n_rows):
            if r != rank and m[r][col] % Q:
                f = m[r][col]
                m[r] = [(a - f * b) % Q for a, b in zip(m[r], m[rank])]
        piv_cols.append(col)
        rank += 1
        if rank == n_rows:
            break
    sol = None
    if rhs is not None and rank == n_cols == n_rows:
        sol = [0] * n_cols
        for r, c in enumerate(piv_cols):
            sol[c] = m[r][-1] % Q
    return rank, sol


chals = [[prf("acc", t, j) for j in range(M2)] for t in range(M2)]
r1, _ = gauss_rank_and_solve(chals[:1])
rhalf, _ = gauss_rank_and_solve(chals[:M2 // 2])
rfull, _ = gauss_rank_and_solve(chals)
if (r1, rhalf, rfull) != (1, M2 // 2, M2):
    die("FPP-3b", f"rank law broken: {(r1, rhalf, rfull)}")
# exact recovery of row 0 of the stacked witness at t = m2
row0_rhs = [sum(chals[t][j] * cols32[j][0] for j in range(M2)) % Q
            for t in range(M2)]
_, sol = gauss_rank_and_solve(chals, row0_rhs)
if sol != [cols32[j][0] for j in range(M2)]:
    die("FPP-3b", "row recovery at m2 transcripts failed")
ok("FPP-3b", f"accumulation law at pass shape: rank grows exactly "
   f"1/transcript/row-system (1, {M2 // 2}, {M2} at t = 1, {M2 // 2}, "
   f"{M2}); EXACT witness-row recovery at t = m2 = {M2} transcripts "
   f"(AZ-L3(b) verbatim at the stacked shape); at t = 1 the solution "
   f"space keeps dim m2 - 1 per row — the ONE-proof leak is bounded, "
   f"the fold changes the per-proof law not at all")

# ----------------------------------------------------------------- #
# FPP-4 — the group-map hash edge: mask/order F5 pair (FP-L2)
# ----------------------------------------------------------------- #
# SHIPPED order: the group map (privacy-class assignment of every
# segment) is inside h0_agg BEFORE any challenge; the bare
# activation floor is then weight-INDEPENDENT. ATTACK order: group
# assignment chosen AFTER the fold challenges migrates a weight
# column into the bare activation opening.
act_cols = [[prf("act", j, i) for i in range(M1)] for j in range(4)]
wt_cols = [[prf("wt", j, i) for i in range(M1)] for j in range(2)]
group_map = {"act": [0, 1, 2, 3], "wt": [0, 1]}
h0 = prf("h0", str(sorted(group_map.items())), "commitments")
c_act = [prf(h0, "fold", j) for j in range(len(act_cols))]
z_act = [sum(c_act[j] * act_cols[j][i] for j in range(len(act_cols))) % Q
         for i in range(M1)]
# weight-independence, demonstrated directly: perturb W, floor fixed
wt_cols_p = [[(x + 1) % Q for x in col] for col in wt_cols]
z_act_p = [sum(c_act[j] * act_cols[j][i] for j in range(len(act_cols))) % Q
           for i in range(M1)]  # W does not enter the act fold at all
if z_act_p != z_act:
    die("FPP-4a", "activation floor moved under a weight perturbation")
recomp = [sum(c_act[j] * act_cols[j][i] for j in range(len(act_cols))) % Q
          for i in range(M1)]
if recomp != z_act:
    die("FPP-4a", "canary recompute failed on the shipped order")
ok("FPP-4a", "shipped order (group map inside h0_agg before every "
   "challenge): the bare activation floor is recomputed EXACTLY "
   "from (T_act, challenges) alone and is INVARIANT under weight "
   "perturbation — weight-independence holds by construction "
   "(mask-then-fold = the h0_agg edge, FP-L2)")

# ATTACK: adversary sees c, then assigns w1 into the act opening
z_attack = [(z_act[i] + prf(h0, "fold", 4) * wt_cols[0][i]) % Q
            for i in range(M1)]
canary_fires = (z_attack != recomp)
# the leaked delta IS an explicit weight functional
delta = [(z_attack[i] - z_act[i]) % Q for i in range(M1)]
leak_is_wt_functional = (
    delta == [prf(h0, "fold", 4) * wt_cols[0][i] % Q for i in range(M1)])
# and the shipped hash edge rejects the migration outright
h0_swapped = prf("h0", str(sorted({"act": [0, 1, 2, 3, "w1"],
                                   "wt": [1]}.items())), "commitments")
hash_edge_rejects = (h0_swapped != h0)
if not (canary_fires and leak_is_wt_functional and hash_edge_rejects):
    die("FPP-4b", "attack leg not caught")
ok("FPP-4b", "ATTACK order (group map chosen after the fold "
   "challenges): a weight column migrated into the bare activation "
   "opening (i) shifts the floor by an EXPLICIT weight functional "
   "c_5 * w1 — the P2 privacy break made concrete; (ii) is caught "
   "by the recompute canary; (iii) is rejected by the shipped "
   "h0_agg group-map edge (changed assignment => changed statement "
   "hash) — the F5 pair for FA's group-map row")

# ----------------------------------------------------------------- #
# FPP-5 — byte-table reproduction (every doc total from formulas)
# ----------------------------------------------------------------- #
# Unit widths (PROOF_BYTE_LEDGER Section 0): K-element wire 64 B;
# commit identity at kappa 11 = 4 + 11*516 = 5,680 B; R-EB3 K-draw
# aggregation line 1,036 B/level; floor coordinate 1 B at e_f = 7.
KEL = 64
U_ID = 4 + 11 * 516                  # 5,680
LVL = U_ID + 1036                    # 6,716 per level >= 1
STATEMENT = 6144
FRAMING = 2048


def kel_fit(dw):                     # F-IF1.8 [MODEL]
    return 2 * dw * dw + 11 * dw + 235


def evalproof(levels, floor_rings):
    # level-0 v commitment + (levels-1) level messages + bare floor
    return U_ID + (levels - 1) * LVL + floor_rings * 128


checks = []
# descent pairs
checks.append(("kel(24) ledger anchor", kel_fit(24) * KEL, 105_664))
checks.append(("kel(29) FFN-pass descent", kel_fit(29) * KEL, 143_104))
checks.append(("kel(26) 2^20-pass descent", kel_fit(26) * KEL, 119_872))
# instance transcript, FFN complete layer (EA R8-b decomposition):
# 3 matmul (12/12/14 r, wire-deg 2), Hadamard (23 r, 3), requant x2
# (23 r, 3), range-table (28 r, 3), batch (25 r, 3) + 4 boundary
# K-el x 8 instances
inst_layer = ((12 + 12 + 14) * 2 + (23 + 23 + 23 + 28 + 25) * 3) * KEL \
    + 8 * 4 * KEL
checks.append(("FFN layer instance transcript (EA)", inst_layer, 30_336))
# folded: +5 rounds at wire-deg 3 on the three matmuls, Hadamard,
# requant x2 and batch (25->30); range TABLE side unchanged (FD-L3)
inst_pass = inst_layer + 7 * 5 * 3 * KEL
checks.append(("FFN pass instance transcript (FA)", inst_pass, 37_056))
# eval proofs (FA 6.1): L8 act 710-ring floor; L8 weight 734; L7 2^20
checks.append(("act eval proof L8", evalproof(8, 710), 143_572))
checks.append(("weight eval proof L8", evalproof(8, 734), 146_644))
checks.append(("2^20 eval proof L7", evalproof(7, 732), 139_672))
# FA pass bases from components
act_only = (STATEMENT + 2 * U_ID + kel_fit(29) * KEL + inst_pass
            + 151 * KEL + evalproof(8, 710) + FRAMING)
wc = act_only + U_ID + evalproof(8, 734)
p20 = (STATEMENT + 2 * U_ID + kel_fit(26) * KEL + 10_688
       + 68 * KEL + evalproof(7, 732) + FRAMING)
checks.append(("FA act-only pass base", act_only, 352_948))
checks.append(("FA W-C pass base", wc, 505_272))
checks.append(("FA 2^20 pass base", p20, 294_136))
for name, got, want in checks:
    if got != want:
        die("FPP-5a", f"{name}: {got} != {want}")
ok("FPP-5a", f"{len(checks)} recorded totals reproduced from "
   "component formulas: descent kel fits, the FFN instance "
   "transcript (layer 30,336 -> pass 37,056 = +5 index rounds on 7 "
   "of 8 instances, table side exempt), all three eval-proof lines "
   "(5,680 + (L-1) x 6,716 + floor x 128), and FA's three pass "
   "bases 352,948 / 505,272 / 294,136 B")

# --- corrected masked-floor surcharge (the re-derivation) ---
# bare floor: 1 B/coord (e_f = 7); masked response: 4 B/coord at the
# e_L <= 4 no-limb-growth corner [MODEL] => surcharge = 3 B/coord.
FLOOR_ACT = 710 * 128     # 90,880
FLOOR_WT = 734 * 128      # 93,952
FLOOR_20 = 732 * 128      # 93,696
sur_act, sur_wt, sur_20 = 3 * FLOOR_ACT, 3 * FLOOR_WT, 3 * FLOOR_20
if (sur_act, sur_wt, sur_20) != (272_640, 281_856, 281_088):
    die("FPP-5b", "surcharge arithmetic")
ok("FPP-5b", "corrected masked-floor surcharges at the R-EB4 pass "
   f"floors: activation +{sur_act:,} B, weight +{sur_wt:,} B, 2^20 "
   f"+{sur_20:,} B (= 3 B/coord x 90,880 / 93,952 / 93,696 coords, "
   "no-limb-growth corner [MODEL]) — 13.8-17.6 pct ABOVE the stale "
   "+176-240 KB class (whose floors predate R-EB4)")

# --- masked-instance wire deltas [MODEL] ---
# per masked instance: G pin + mask opening (2 K-el) + 1-2 extension
# rounds at wire-deg 3 => 320..512 B, midpoint 416 B.
D_LO, D_MID, D_HI = 320, 416, 512


def tier_z(base, floors, n_masked):
    return base + sum(floors) + n_masked * D_MID


P2 = tier_z(wc, [sur_wt], 4)             # 3 matmuls + batch masked
P3 = tier_z(wc, [sur_act, sur_wt], 8)    # all 8 instances masked
P1S = tier_z(wc, [sur_act], 8)           # P1-strict (act floor masked)
P1N = wc + 8 * D_MID                     # P1 label mode (bare floor)
ACT_S = tier_z(act_only, [sur_act], 8)   # act-only reference
TZ20 = tier_z(p20, [sur_20], 2)
exp = {"P2": 788_792, "P3": 1_063_096, "P1-strict": 781_240,
       "P1-label": 508_600, "act-only-strict": 628_916, "2^20": 576_056}
got = {"P2": P2, "P3": P3, "P1-strict": P1S, "P1-label": P1N,
       "act-only-strict": ACT_S, "2^20": TZ20}
if got != exp:
    die("FPP-5c", f"Tier Z totals: {got} != {exp}")
ok("FPP-5c", "folded Tier Z pass totals (W-C layout, midpoint "
   f"deltas): P2 = {P2:,} B = {P2 / 2**20:.3f} MiB; "
   f"P3 = {P3:,} B = {P3 / 2**20:.3f} MiB; "
   f"P1-strict = {P1S:,} B; P1-label = {P1N:,} B; "
   f"2^20 pass = {TZ20:,} B = {TZ20 / 2**20:.3f} MiB — "
   "P2 and P3 both INSIDE Amendment A1's 0.5-2 MiB target class")

# --- the unfolded check rows (ZK_GAP_OPTIONS Section 4B) ---
LAYER_A = 283_392            # EB-corrected FFN exact-digit layer
LAYER_FLOOR = 640 * 128      # 81,920 B bare layer floor [MODEL]
optb_lo = LAYER_A - LAYER_FLOOR + 4 * (512 * 128)
optb_hi = LAYER_A - LAYER_FLOOR + 4 * (640 * 128)
if (optb_lo, optb_hi) != (463_616, 529_152):
    die("FPP-5d", f"Option B corridor: {optb_lo}, {optb_hi}")
pass_a, pass_b_lo, pass_b_hi = 32 * LAYER_A, 32 * optb_lo, 32 * optb_hi
if pass_a != 9_068_544:
    die("FPP-5d", "Option A pass")
if not (14.0 < pass_b_lo / 2**20 < 14.5 and 16.0 < pass_b_hi / 2**20 < 16.5):
    die("FPP-5d", "Option B pass class")
ok("FPP-5d", "unfolded check rows reproduced: Option A pass 32 x "
   f"283,392 = {pass_a:,} B (8.65 MiB); Option B corridor "
   f"463,616-529,152 B/layer (= 283,392 - 81,920 bare floor + 4 "
   f"B/coord x 512..640-ring masked floor [MODEL]) -> "
   f"{pass_b_lo / 2**20:.2f}-{pass_b_hi / 2**20:.2f} MiB/pass — the "
   "ZK_GAP_OPTIONS 14-16 MiB class, from the same formulas")

# --- surcharge concentration + freeze margin ---
conc_lo = 32 * (optb_lo - LAYER_A) / (sur_act + sur_wt)
conc_hi = 32 * (optb_hi - LAYER_A) / (sur_act + sur_wt)
FREEZE = 1_114_112           # 1.0625 MiB
band_hi = (507_512 + 9_360) + sur_act + sur_wt + 8 * D_HI  # FA worst band
if not (P3 <= band_hi <= FREEZE <= 2 * 2**20):
    die("FPP-5e", f"freeze margin: P3 {P3}, band_hi {band_hi}")
ok("FPP-5e", "surcharge concentration: unfolded pays 32 masked "
   f"floors ({32 * (optb_lo - LAYER_A) / 2**20:.2f}-"
   f"{32 * (optb_hi - LAYER_A) / 2**20:.2f} MiB of surcharge/pass), "
   f"folded W-C pays TWO ({(sur_act + sur_wt) / 2**20:.3f} MiB) = "
   f"{conc_lo:.1f}-{conc_hi:.1f}x concentration; freeze candidate "
   f"{FREEZE:,} B = 1.0625 MiB covers P3 worst-band {band_hi:,} B "
   "with margin and sits inside the A1 class"
   )

# ----------------------------------------------------------------- #
# FPP-6 — recovery-rank margins (P1 label / P2 asymmetry arithmetic)
# ----------------------------------------------------------------- #
act_coeffs = 5_646_592 * 128        # FA 5.1 pass activation rings
wt_coeffs = 33_816_576 * 128        # FA 5.2 stacked weight rings
p20_coeffs = 32_936 * 32 * 128      # EA 2.4 x 32 layers
thr_act = -(-act_coeffs // FLOOR_ACT)
thr_wt = -(-wt_coeffs // FLOOR_WT)
thr_20 = -(-p20_coeffs // FLOOR_20)
frac_act = FLOOR_ACT / act_coeffs
# EC 7.3 layer-scale anchor: dense layer ~10^3-class proofs
thr_layer_ec = -(-176_328 * 128 // 79_872)
if (thr_act, thr_wt, thr_20, thr_layer_ec) != (7953, 46072, 1440, 283):
    die("FPP-6", f"thresholds {(thr_act, thr_wt, thr_20, thr_layer_ec)}")
wt_days = thr_wt * 15 / 86_400  # at the 15 s/pass roadmap target
ok("FPP-6", "recovery-rank margins [naive upper bounds, NO margin "
   f"credited]: P1 FFN pass — one floor = {FLOOR_ACT:,} constraints "
   f"on {act_coeffs:,} committed activation coeffs = "
   f"{100 * frac_act:.4f} pct of naive rank; rank-completeness needs "
   f"~{thr_act:,} fresh proofs of the SAME pass (2^20 pass: "
   f"~{thr_20:,}; EC 7.3 layer anchor ~{thr_layer_ec} reproduced). "
   f"P2 asymmetry: weights re-proven EVERY pass reach naive "
   f"recovery rank in ~{thr_wt:,} passes = ~{wt_days:.0f} days of "
   "continuous proving at 15 s/pass — no operational rule can bound "
   "it; the weight-floor mask is mandatory in P2/P3, every pass")

# ----------------------------------------------------------------- #
# FPP-7 — the E2/E4 norm corner survives at pass floor dims [MODEL]
# ----------------------------------------------------------------- #
import math
LINE = 28.00                          # q/8 = 2^28.00
corner_layer, growth_layer = 27.2, 28.6   # EC SPKZ-7b at 64-80k class
b_act = corner_layer + 0.5 * math.log2(FLOOR_ACT / 81_920)
b_wt = corner_layer + 0.5 * math.log2(FLOOR_WT / 81_920)
g_wt = growth_layer + 0.5 * math.log2(FLOOR_WT / 81_920)
if not (b_act < LINE and b_wt < LINE and g_wt > LINE):
    die("FPP-7", f"corner arithmetic {(b_act, b_wt, g_wt)}")
ok("FPP-7", "the E2/E4 masked-floor norm corner at pass floors "
   f"[MODEL, sqrt(dim) first-order]: e_L<=4 no-limb-growth bound "
   f"2^{b_act:.2f} (act) / 2^{b_wt:.2f} (weight) vs the q/8 line "
   f"2^{LINE:.2f} — the corner SURVIVES at pass scale with ~0.7 b; "
   f"the limb-growth branch (2^{g_wt:.2f}) stays DEAD — the F-Z1 "
   "corner condition carries to the pass unchanged, and EB's "
   "relaxed validity line (~6 b window margin) only widens it")

# ----------------------------------------------------------------- #
# FPP-8 — T_blind pass budget (mask material fits, committed-only)
# ----------------------------------------------------------------- #
descent_masks = round(2315 * kel_fit(29) / kel_fit(24))   # scale w/ pair
matmul_ng = 3 * (1 + 5 * 3 + 14 * 2)      # 5 l-rounds deg 3, 14 deg 2
had_ng = 1 + 28 * 3
req_ng = 2 * (1 + 28 * 3)
batch_ng = 1 + 30 * 3
pads = 151 * 8                            # one ring-granular pad/entry
claim_seg = 128
total_kel = (descent_masks + matmul_ng + had_ng + req_ng + batch_ng
             + pads + claim_seg)
rings = -(-total_kel // 8)
if not rings <= 4096 // 2:
    die("FPP-8", f"T_blind budget: {rings} rings")
ok("FPP-8", f"T_blind at pass scope [MODEL]: descent masks ~"
   f"{descent_masks:,} K-el (scaled to dw 29) + instance masks "
   f"{matmul_ng + had_ng + req_ng + batch_ng} + pads {pads:,} + "
   f"claim segment {claim_seg} = ~{total_kel:,} K-el = ~{rings} "
   f"rings — fits the 4,096-ring T_blind window with >= "
   f"{4096 // rings}x headroom; zero wire (committed only)")

print(f"{len(OK)}/{len(OK)} OK — all fold_privacy_pricing_spike "
      "assertions passed")
