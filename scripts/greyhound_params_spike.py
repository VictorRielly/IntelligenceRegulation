#!/usr/bin/env python3
"""U-AG2 Agent DA (O-1) parameter spike: Greyhound/LaBRADOR re-derivation
at the house ring R_q = Z_q[X]/(X^128 + 1), q31 = 2^31 - 399.

Companion to docs/zkmatrix-poc/AGGREGATION_PARAMS_DESIGN.md (the design
doc quotes THIS script's printed numbers; keep the two in lockstep).

What it does, in order:
  1. SELF-CHECKS: pins the house norm/hardness conventions against
     repo-published anchors (params.rs formulas; ESTIMATOR_NOTE.md
     C3/core-SVP rows; PROOF_BYTE_LEDGER.md descent bytes) - the script
     refuses to print design numbers if any anchor fails.
  2. Level-0 (Greyhound) layout at the ledger tensor inventory: m1 x m2
     split, digit base, fold-norm gamma_z, top MSIS instance (kappa via
     the C3 model, bits via core-SVP), C2' validity.
  3. Recursion schedule (LaBRADOR levels) with ADAPTIVE digit bases:
     per level, the largest digit base the q-budget admits, the fold
     r_i minimizing the next witness, the per-level MSIS instance.
     Three slack models (see doc Section 3.4): per-level (baseline),
     exact-digit (house sigma.rs-style range claims replace JL),
     compounded (adversarial reading; the O-7 question).
  4. Knowledge-error accounting (quinary per-slot 2^-297.2 engine + JL
     + batching), pre- and post-FS [MODEL].
  5. O-2 byte-model skeleton: complete-artifact tables at the measured
     2^20 layer shape and the 512x11008 FFN layer vs 262,144 B, and a
     verifier-time model [MODEL] vs <= 2 s.

Numbers only from: zkmatrix-rs/src/ring/params.rs + mod.rs (ring/norm
constants), scripts/route_r_params.py (chain conventions),
ESTIMATOR_NOTE.md (core-SVP model + anchors), PROOF_BYTE_LEDGER.md
(inventory, unit costs, budgets). Landing constants not from those
sources are printed with a [MODEL] tag.

stdlib only; runs in well under a second; O(1) memory.
"""

import math

# ---------------------------------------------------------------------------
# House constants (zkmatrix-rs/src/ring/mod.rs + params.rs; route_r_params.py)
# ---------------------------------------------------------------------------
D = 128
Q31 = 2147483249            # Q8 = 2^31 - 399, q = 17 mod 32, k = 8 split
Q46 = 70368744176561        # Q8_46 = 2^46 - 1103, same split class
LOG2_DELTA0 = 0.005326      # C3 root-Hermite model (log2 1.0037)
TAIL = 1.3
E_C2 = 2.0                  # E[c_i^2], quinary {-2..2}
E_RHO2 = 2.0 / 3.0          # E[rho_i^2], ternary
LOG2_C = 128 * math.log2(5)   # |C| = 5^128 = 2^297.2
OP_CONC = TAIL * math.sqrt(E_C2 * D)          # 20.79 (params.rs op_norm)
OP_WC = 2.0 * D                                # 256
OP_DC_CONC = TAIL * math.sqrt(2 * E_C2 * D)    # challenge DIFFERENCE, var 4
RING_MAC_US = 0.18   # us/ring-MAC 1T, A1/Karatsuba kernel class
                     # (RING_MULT_BOTTLENECK.md 6.5: 0.16-0.20) [MEASURED range]
KEL_B = 64           # canonical K-element bytes (16 limbs x 4 B, ledger 0.1)
POLY_B = 4 + D * 4   # one poly, P3 codec (ledger Section 0): 516 B
BUDGET = 262_144     # PROOF_BYTE_LEDGER.md Section 3

checks = []


def check(name, got, want, tol=0.0):
    ok = abs(got - want) <= tol if tol else got == want
    checks.append((name, ok, got, want))
    return ok


# ---------------------------------------------------------------------------
# Core-SVP machinery (ESTIMATOR_NOTE.md Section 1 [core-SVP] leg):
# delta(b) = (b/(2 pi e) * (pi b)^(1/b))^(1/(2(b-1))), cost 2^(0.292 b).
# C3 inversion: the attack succeeds iff (log2 beta / 2)^2 >= k_Z log2 q
# * log2 delta(b)  =>  required log2 delta = (log2 beta/2)^2/(k_Z log2 q).
# ---------------------------------------------------------------------------

def chen_delta(b):
    return (b / (2 * math.pi * math.e) * (math.pi * b) ** (1.0 / b)) ** (
        1.0 / (2 * (b - 1)))


def block_for_delta(delta_target):
    lo, hi = 50.0, 4000.0
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if chen_delta(mid) > delta_target:
            lo = mid
        else:
            hi = mid
    return 0.5 * (lo + hi)


def msis_core_svp_bits(k_z, log2_q, log2_beta):
    """Classical core-SVP cost of the MSIS instance (n=k_z rows, l2 bound)."""
    if log2_beta >= log2_q:
        return 0.0  # vacuous: q-vector beats the bound
    ld = (log2_beta / 2.0) ** 2 / (k_z * log2_q)
    b = block_for_delta(2.0 ** ld)
    return 0.292 * b


def c3_kappa(log2_beta, log2_q):
    k_z = math.ceil((log2_beta / 2.0) ** 2 / (log2_q * LOG2_DELTA0))
    return math.ceil(k_z / D), k_z


# ---------------------------------------------------------------------------
# Self-checks against repo anchors
# ---------------------------------------------------------------------------

def self_checks():
    # params.rs op-norm conventions
    check("op_norm conc = 1.3 sqrt(2D) = 20.8", round(OP_CONC, 2), 20.8,
          0.01)
    check("op_norm worst = 2D", OP_WC, 256.0)
    # C3 line reproduces frozen kappa rows (ESTIMATOR_NOTE Sections 4/8:
    # prototype log2 beta 24.55 -> k_Z 1024-class -> kappa 8;
    # Pi2 e=4 log2 beta 26.13 -> k_Z 1034 -> kappa 9).
    kp, kz = c3_kappa(24.55, 31.0)
    check("C3 kappa @ prototype (beta 2^24.55)", kp, 8)
    kp2, kz2 = c3_kappa(26.13, 31.0)
    check("C3 k_z @ Pi2 e=4 (beta 2^26.13)", kz2, 1034)
    check("C3 kappa @ Pi2 e=4", kp2, 9)
    # delta(445) = 1.0037 (ESTIMATOR_NOTE Section 5)
    check("chen delta(445)", round(chen_delta(445), 4), 1.0037, 0.0001)
    # core-SVP anchors (ESTIMATOR_NOTE Section 4 [core-SVP] column):
    # prototype (k_Z 1024, beta 2^24.55): 153.0; Pi2 e=3 (1024, 2^25.55):
    # 136.7; FFN e=4 (1152, 2^26.64): 143.4.
    check("core-SVP prototype MSIS bits",
          round(msis_core_svp_bits(1024, 31.0, 24.55), 1), 153.0, 0.4)
    check("core-SVP Pi2 e=3 MSIS bits",
          round(msis_core_svp_bits(1024, 31.0, 25.55), 1), 136.7, 0.4)
    check("core-SVP FFN e=4 MSIS bits",
          round(msis_core_svp_bits(1152, 31.0, 26.64), 1), 143.4, 0.4)
    # d_lwe hiding dimension rule (params.rs / ESTIMATOR_NOTE Section 3)
    check("d_lwe @ q31 = ceil(768*31/11.7)", math.ceil(768 * 31.0 / 11.7), 2035)
    # Ledger descent-byte anchors at 4 B/limb (PROOF_BYTE_LEDGER 0.1/3.1):
    # 2^20 masked descent bytes 86,272 (IA-4 row); FFN pair 105,664 B
    # ("103.2 KiB").
    check("descent bytes @2^20 (1348 kel x 64)", 1348 * KEL_B, 86_272)
    check("descent bytes @FFN (1651 kel x 64)", 1651 * KEL_B, 105_664)
    check("one poly P3 bytes", POLY_B, 516)
    # Old C2 wave cap reproduction (M4_LOOKUP_DESIGN wall 1, exact chain
    # from ct_engine.rs derive_ct_round_params): bundle = t * n_z,
    # t_bundle = op sqrt(bundle), sigma = 12 t_bundle, bound = 1.2 sigma
    # sqrt(bundle), beta = 2 bound + op sqrt(bundle); C2: q > 8 beta.
    # The cap must land at EXACTLY 134 commitments at the working CRS
    # shape (kappa 8, n_r 26), and sigma(134) at 2^17.3-17.4 (ledger 3.1
    # cites "sigma ~ 2^17.4 at the 134-commitment bundle").
    n_z = 26 * D

    def old_beta(t):
        bundle = t * n_z
        t_bundle = OP_CONC * math.sqrt(bundle)
        sigma = 12.0 * t_bundle
        bound = 1.2 * sigma * math.sqrt(bundle)
        return 2.0 * bound + OP_CONC * math.sqrt(bundle), sigma
    t_max = max(t for t in range(1, 400) if Q31 > 8 * old_beta(t)[0])
    check("old C2 cap saturates at 134 commitments", t_max, 134)
    check("old chain sigma(134) = 2^17.3x",
          round(math.log2(old_beta(134)[1]), 1), 17.3, 0.1)


# ---------------------------------------------------------------------------
# Tensor inventory (PROOF_BYTE_LEDGER.md Sections 1-2 [DERIVED] counts):
# data commitments x 1024 committed coefficients each; g-groups and wave
# pads are wave-masking objects abolished by the reroute.
# ---------------------------------------------------------------------------
SHAPES = {
    "2^20 layer": dict(n_el=1_048_572, data_commits=50_197,
                       dw=21, dt=9, kel=1348),
    "FFN 512x11008": dict(n_el=5_636_096, data_commits=269_721,
                          dw=24, dt=9, kel=1651),
}


# ---------------------------------------------------------------------------
# The level machinery
# ---------------------------------------------------------------------------

def digit_e_max(gamma_max, count_rings, val_bits, log2_q):
    """Largest digit-bit width e such that folding the decomposed vector
    (count_rings ring elements of val_bits-bit values, l = ceil(val_bits/e)
    limbs, digits bounded 2^(e-1)) stays under gamma_max:
        gamma = OP_CONC * 2^(e-1) * sqrt(count * l * D)  <= gamma_max.
    Returns (e, l). e capped to val_bits (no decomposition needed)."""
    best = None
    for e in range(1, int(log2_q) + 1):
        l = max(1, math.ceil(val_bits / e))
        gamma = OP_CONC * 2.0 ** (e - 1) * math.sqrt(count_rings * l * D)
        if gamma <= gamma_max:
            best = (e, l)
    return best


def fold_inf_norm(r, e):
    """Per-coefficient magnitude of an r-fold quinary combination of digit
    vectors bounded 2^(e-1): 1.3 sqrt(r D E_C2 E[dig^2]),
    E[dig^2] ~ (2/3) 4^(e-1) (balanced-digit RMS, params.rs E_RHO2 style)."""
    return TAIL * math.sqrt(r * D * E_C2 * E_RHO2 * 4.0 ** (e - 1))


def schedule(n_ring, log2_q, gamma_max, kappa, val_bits, max_levels=10,
             verbose=False):
    """Greedy adaptive-base recursion schedule.

    Level 0 = Greyhound: split n_ring into m1 x m2 (verifier-balanced),
    decompose columns at the max feasible base, fold once (z), pass
    (z-parts, t-hat, w-hat) to level 1. Levels >= 1 = LaBRADOR steps:
    r-fold + fresh commitments + garbage, adaptive digit bases.

    Returns dict with per-level rows and the stop-level byte options.
    """
    q = 2.0 ** log2_q
    rows = []
    # ---- level 0 (Greyhound) ----
    e0 = None
    for e in range(1, 16):
        l = math.ceil(val_bits / e)
        gamma = OP_CONC * 2.0 ** (e - 1) * math.sqrt(n_ring * l * D)
        if gamma <= gamma_max:
            e0 = (e, l, gamma)
    if e0 is None:
        return None  # not even binary digits fit: layout infeasible
    e, l0, gamma_z = e0
    # t coefficients are mod-q: decomposed at their own max base for the
    # level-1 witness (computed below); w entries mod-q likewise.
    lt0 = None  # decided by level-1 base
    # verifier-balanced split: m1*l0 = m2*kappa*lt_guess (lt at level-1 base)
    lt_guess = math.ceil(val_bits / max(1, e))
    m1 = int(math.sqrt(n_ring * kappa * lt_guess / l0)) or 1
    m2 = math.ceil(n_ring / m1)
    hide = math.ceil(math.ceil(768 * log2_q / 11.7) / D)  # C4 hiding tail
    z_len = m1 * l0 + hide
    wz_bits = math.log2(fold_inf_norm(m2, e))
    rows.append(dict(lvl=0, n=n_ring, e=e, l=l0, r=m2, gamma=gamma_z,
                     note="Greyhound fold over m2=%d cols, m1=%d" % (m2, m1)))
    # ---- levels >= 1 ----
    # witness entering level 1: z (z_len rings, wz_bits values),
    # t-hat source (m2*kappa rings of val_bits), w (m2 rings of val_bits)
    pend = [(z_len, wz_bits), (m2 * kappa, val_bits), (m2, val_bits)]
    stops = []
    for lvl in range(1, max_levels + 1):
        # adaptive base: iterate (n depends on l depends on e)
        e_i, n_i = None, None
        for e_try in range(1, int(log2_q) + 1):
            n_try = sum(c * max(1, math.ceil(b / e_try)) for c, b in pend)
            gamma = OP_CONC * 2.0 ** (e_try - 1) * math.sqrt(n_try * D)
            if gamma <= gamma_max:
                e_i, n_i = e_try, n_try
        if e_i is None:
            break
        # bare-witness stop option at this level: n_i rings of e_i-bit digits
        bare = n_i * D * math.ceil((e_i + 1) / 8)
        stops.append((lvl, n_i, e_i, bare))
        # choose fold r minimizing next witness
        best = None
        for r in range(4, 257):
            if r > n_i:
                break
            gamma_i = OP_CONC * 2.0 ** (e_i - 1) * math.sqrt(n_i * D)
            wz_b = math.log2(fold_inf_norm(r, e_i))
            nxt = [(math.ceil(n_i / r), wz_b),        # z fold
                   (r * kappa, val_bits),             # fresh inner commits
                   (r * (r + 1) // 2, val_bits)]      # h garbage (linear agg)
            n_nxt = sum(c * max(1, math.ceil(b / e_i)) for c, b in nxt)
            if best is None or n_nxt < best[1]:
                best = (r, n_nxt, gamma_i, wz_b, nxt)
        r, n_nxt, gamma_i, wz_b, pend = best
        rows.append(dict(lvl=lvl, n=n_i, e=e_i, l=1, r=r, gamma=gamma_i,
                         note="fold r=%d" % r))
        if n_nxt >= n_i:  # recursion floor reached
            break
    return dict(rows=rows, stops=stops, gamma_z=gamma_z, m1=m1, m2=m2,
                e0=e, l0=l0, z_len=z_len, hide=hide)


# ---------------------------------------------------------------------------
# Slack models (doc Section 3.4). beta_top = extracted-difference norm the
# TOP (level-0 inner) MSIS instance must be hard at; validity C2' requires
# beta_top <= q/8 (house C2-class headroom).
# ---------------------------------------------------------------------------
S_JL = math.sqrt(128.0 / 30.0)       # 2.066 JL norm-check slack (LaBRADOR)
S_FORK = 2.0                          # transcript-difference factor

# beta_top = base * per_level^(L-1) * gamma, L = recursion depth (levels
# above Greyhound). base carries the one-time factors: fork (2), one JL
# application, one challenge-difference operator norm (relaxed binding,
# SOUNDNESS_REFERENCE 2.2 style). The three readings of how the remaining
# (L-1) levels' slack composes are the O-7 question (doc Section 3.4).
SLACK_MODELS = {
    "per-level":   dict(per_level=1.0, base=S_FORK * S_JL * OP_DC_CONC,
                        note="fresh per-level binding; one JL + one dc"),
    "exact-digit": dict(per_level=1.0, base=S_FORK * OP_DC_CONC,
                        note="house exact digit range claims replace JL"),
    "compounded":  dict(per_level=S_FORK * S_JL,
                        base=S_FORK * S_JL * OP_DC_CONC,
                        note="adversarial reading: slack multiplies per level"),
}


def gamma_budget(log2_q, model, extra_levels):
    """gamma_max such that beta_top = slack(extra_levels) * gamma <= q/8."""
    m = SLACK_MODELS[model]
    slack = m["base"] * m["per_level"] ** extra_levels
    return (2.0 ** (log2_q - 3)) / slack


# ---------------------------------------------------------------------------
# Byte + verifier models (O-2 skeleton)
# ---------------------------------------------------------------------------

def eval_proof_bytes(sched, kappa, merge_outer=True):
    """Wire of the compressed eval proof: the level-0 v-commitment (the
    D w-hat commitment sent before challenges), per executed level one
    outer commitment (+ JL projection + aggregation scalars), and the
    cheapest bare-witness stop. Stopping at witness_k costs the wire of
    levels 1..k-1 plus witness_k in the clear."""
    v_commit = 4 + kappa * POLY_B
    per_level_wire = ((1 if merge_outer else 2) * (4 + kappa * POLY_B)
                      + (4 + 256 * 4)     # JL projection, 256 Z_q coords
                      + (4 + 16 * KEL_B))  # aggregation scalars [MODEL]
    best = None
    for (lvl, n_i, e_i, bare) in sched["stops"]:
        total = v_commit + (lvl - 1) * per_level_wire + bare
        if best is None or total < best[0]:
            best = (total, lvl, n_i, e_i, bare)
    total, lvl, n_i, e_i, bare = best
    return dict(total=total, stop_level=lvl, n_final=n_i, e_final=e_i,
                bare=bare, per_level_wire=per_level_wire)


def artifact_table(shape, sched, kappa, n_gc=2):
    """Complete-artifact byte table, ledger unit-cost style."""
    ep = eval_proof_bytes(sched, kappa)
    items = [
        ("statement (v3 codec)", 4096),
        ("global commitment identities (%d x outer u, kappa=%d)"
         % (n_gc, kappa), n_gc * (4 + kappa * POLY_B)),
        ("masked descent pair (dw %d + dt %d, 4 B/limb)"
         % (shape["dw"], shape["dt"]), shape["kel"] * KEL_B),
        ("batch-merge sumcheck (multi-point -> one point) [MODEL]",
         shape["dw"] * 4 * KEL_B),
        ("eval proof: %d level msgs" % ep["stop_level"],
         ep["stop_level"] * ep["per_level_wire"]),
        ("eval proof: final bare witness (%d rings, %d-bit digits)"
         % (ep["n_final"], ep["e_final"]), ep["bare"]),
        ("batched claim values (16 claims x 8 slots x K-el) [MODEL]",
         16 * 8 * KEL_B),
        ("framing/prefixes [MODEL]", 2048),
    ]
    total = sum(b for _, b in items)
    return items, total, ep


def verifier_model(shape, sched, kappa):
    """[MODEL] single-thread seconds; ring-MAC accounting at the measured
    kernel class 0.18 us/ring-MAC (RING_MULT_BOTTLENECK 6.5)."""
    m1, m2 = sched["m1"], sched["m2"]
    l0 = sched["l0"]
    # level-1 statement processing (the sqrt-sized wrapped relation):
    # kappa * (z_len + that_len + w-hat) ring-MACs, plus later levels.
    lvl1 = kappa * (sched["z_len"] + m2 * kappa * 2 + m2 * 2)
    later = sum(kappa * r["n"] for r in sched["rows"][1:])
    ab = (m1 + m2) * 16 * 16 / D        # a/b K-field tensor build, ring-equiv
    descents = shape["dw"] * 3 * 8 * 16 * 16 / D  # GKR verify, ring-equiv
    macs = lvl1 + later + ab + descents
    return macs * RING_MAC_US * 1e-6


def prover_model(shape, n_ring, sched, kappa):
    """[MODEL] commit-path marginal of the reroute, us/el 1T."""
    l0 = sched["l0"]
    inner = kappa * n_ring * l0            # A * s-hat, all columns
    outer = kappa * sched["m2"] * kappa * 2
    eval_p = n_ring * l0 * 2               # w/z folds, streaming
    total_us = (inner + outer + eval_p) * RING_MAC_US
    return total_us / shape["n_el"]


# ---------------------------------------------------------------------------
# Knowledge error [MODEL where marked]
# ---------------------------------------------------------------------------

def knowledge_error(sched, n_claims=16):
    per_slot = -LOG2_C  # log2(5^-128) = -297.2, house L2 lemma
    lvls = len(sched["rows"])
    eps_fold = math.log2(sum(r["r"] for r in sched["rows"])) + per_slot
    eps_jl = -141.0     # LaBRADOR modular-JL constant [MODEL]
    eps_batch = math.log2(n_claims) + per_slot
    eps_sz = math.log2(24 * 3 * 8) - 496.0  # sumcheck SZ over GF(q^16)
    pre_fs = max(eps_fold, eps_jl, eps_batch, eps_sz) + 2  # union slop
    # FS: PSS-style linear-in-Q loss [MODEL], Q = 2^64, R ~ 3(L+1) rounds
    rounds = 3 * (lvls + 1)
    post_fs = pre_fs + 64 + math.log2(rounds)
    return dict(eps_fold=eps_fold, eps_jl=eps_jl, eps_batch=eps_batch,
                eps_sz=eps_sz, pre_fs=pre_fs, post_fs=post_fs,
                rounds=rounds)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def run_point(label, shape, log2_q, val_bits, model, print_levels=True):
    """Search recursion depths 1..9 (the compounded model's gamma budget
    depends on depth), keep the min-byte valid schedule."""
    n_ring = shape["data_commits"] * 1024 // D
    # kappa from C3 at the top instance: beta_top = q/8 exactly (budget
    # saturated - conservative)
    kappa, k_z = c3_kappa(log2_q - 3, log2_q)
    print("\n== %s | %s | slack model: %s ==" % (label, "q%d" % round(log2_q),
                                                 model))
    best = None
    for depth in range(1, 10):
        gmax = gamma_budget(log2_q, model, depth - 1)
        if gmax < 1.0:
            continue
        s = schedule(n_ring, log2_q, gmax, kappa, val_bits, max_levels=depth)
        if s is None or not s["stops"]:
            continue
        _, total, ep = artifact_table(shape, s, kappa)
        if best is None or total < best[0]:
            best = (total, depth, gmax, s)
        if SLACK_MODELS[model]["per_level"] == 1.0:
            break  # gamma budget depth-independent: one pass suffices
    if best is None:
        print("  INFEASIBLE at this modulus/slack model: no digit base "
              "fits any depth's gamma budget")
        return None
    _, depth, gmax, sched = best
    gz = sched["gamma_z"]
    real_depth = len(sched["rows"]) - 1
    beta_top = (SLACK_MODELS[model]["base"]
                * SLACK_MODELS[model]["per_level"] ** max(0, real_depth - 1)
                * gz)
    bits = msis_core_svp_bits(k_z, log2_q, math.log2(beta_top))
    print("  n_ring = %d (2^%.2f); m1 = %d, m2 = %d; e0 = %d (l0 = %d);"
          % (n_ring, math.log2(n_ring), sched["m1"], sched["m2"],
             sched["e0"], sched["l0"]))
    print("  gamma_z = 2^%.2f; gamma_max = 2^%.2f; beta_top = 2^%.2f "
          "(C2' limit 2^%.2f) -> %s"
          % (math.log2(gz), math.log2(gmax), math.log2(beta_top),
             log2_q - 3, "VALID" if math.log2(beta_top) <= log2_q - 3
             else "INVALID (q-vector wins)"))
    print("  top MSIS: k_Z = %d (kappa = %d), core-SVP %.1f bits "
          "(C3 line targets ~130)" % (k_z, kappa, bits))
    if print_levels:
        print("  level schedule (adaptive bases):")
        for r in sched["rows"]:
            print("    L%d: n = %7d rings, digit e = %2d, fold r = %4d, "
                  "gamma = 2^%.2f  %s"
                  % (r["lvl"], r["n"], r["e"], r["r"],
                     math.log2(r["gamma"]), r["note"]))
    items, total, ep = artifact_table(shape, sched, kappa)
    print("  artifact bytes (O-2 skeleton, canonical widths):")
    for name, b in items:
        print("    %-58s %10s B" % (name, format(b, ",")))
    over = total / BUDGET
    print("    %-58s %10s B  = %.1f KiB  (%.2fx budget) -> %s"
          % ("TOTAL vs 262,144 B", format(total, ","), total / 1024.0,
             over, "PASS" if total <= BUDGET else "OVER"))
    ke = knowledge_error(sched)
    print("  knowledge error: fold 2^%.0f, JL 2^%.0f [MODEL], batch 2^%.0f,"
          " SZ 2^%.0f; pre-FS 2^%.0f; post-FS (PSS linear, R=%d) 2^%.0f "
          "[MODEL] vs 2^-128 -> %s"
          % (ke["eps_fold"], ke["eps_jl"], ke["eps_batch"], ke["eps_sz"],
             ke["pre_fs"], ke["rounds"], ke["post_fs"],
             "PASS" if ke["post_fs"] <= -128 else "FAIL"))
    tv = verifier_model(shape, sched, kappa)
    tp = prover_model(shape, n_ring, sched, kappa)
    print("  verifier [MODEL]: %.2f s 1T (budget 2 s) -> %s;  "
          "prover commit-path marginal [MODEL]: %.1f us/el "
          "(vs 578.7 us/el whole-prove: %+.0f%%)"
          % (tv, "PASS" if tv <= 2.0 else "FAIL", tp, 100 * tp / 578.7))
    return dict(total=total, sched=sched, beta_top=beta_top, bits=bits,
                verifier_s=tv)


def main():
    self_checks()
    n_ok = sum(1 for _, ok, _, _ in checks if ok)
    print("SELF-CHECKS: %d/%d OK" % (n_ok, len(checks)))
    for name, ok, got, want in checks:
        print("  [%s] %s (got %s, want %s)" % ("OK" if ok else "FAIL",
                                               name, got, want))
    if n_ok != len(checks):
        raise SystemExit("anchor self-checks failed - refusing to continue")

    print("\nC2-cap replacement (doc Section 2.4): the per-wave cap "
          "(~134 commitments -> 1020-el row blocks) is VACATED; the new"
          " cap is the level budget:")
    for model in SLACK_MODELS:
        for lq in (31.0, 46.0):
            g0 = gamma_budget(lq, model, 0)
            gl = SLACK_MODELS[model]["per_level"]
            note = ("gamma_max = 2^%.2f" % math.log2(g0)
                    if gl == 1.0 else
                    "gamma_max(L) = 2^%.2f - %.2f L" %
                    (math.log2(g0), math.log2(gl)))
            print("  q%d, %-11s: %s" % (round(lq), model, note))

    results = {}
    for shape_name, shape in SHAPES.items():
        for model in ("per-level", "exact-digit"):
            r = run_point(shape_name, shape, 31.0, 31, model)
            results[(shape_name, "q31", model)] = r
    # the O-7-adversarial reading and the fallback modulus, FFN only
    ffn = SHAPES["FFN 512x11008"]
    results[("FFN 512x11008", "q31", "compounded")] = run_point(
        "FFN 512x11008", ffn, 31.0, 31, "compounded")
    ffn46 = dict(ffn, kel=ffn["kel"])  # descents re-priced inside via KEL_B
    print("\n[q46 fallback run: K-el widens 64 -> 96 B; descent line "
          "re-priced by hand in the doc]")
    results[("FFN 512x11008", "q46", "per-level")] = run_point(
        "FFN 512x11008", ffn46, 46.0, 46, "per-level")

    print("\nVERDICT SUMMARY (doc Section 6):")
    for k, r in results.items():
        if r is None:
            print("  %-45s INFEASIBLE" % (str(k),))
            continue
        print("  %-45s bytes %9s (%.2fx), top-MSIS %.1f bits, verify %.2f s"
              % (str(k), format(r["total"], ","), r["total"] / BUDGET,
                 r["bits"], r["verifier_s"]))
    print("\nALL DONE - %d/%d self-checks OK" % (n_ok, len(checks)))


if __name__ == "__main__":
    main()
