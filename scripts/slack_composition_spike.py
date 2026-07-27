#!/usr/bin/env python3
"""U-AG3 Agent EB (O-7) spike: numeric verification of the slack-composition
arithmetic in docs/zkmatrix-poc/AGGREGATION_SOUNDNESS_COMPOSITION.md.

WHAT THIS CHECKS AND WHAT IT DOES NOT: this script checks ARITHMETIC —
per-level norm/slack chains under the SC-L4 (per-level) rule vs the
compounded rule, the modular-JL window margins, the corrected MSIS
bounds and their kappa/byte consequences, the post-FS knowledge-error
sums, and the Monte-Carlo operator-norm distribution behind the R-EB1
cap. It does NOT check the proofs (SC-L0..SC-L6 are paper objects; the
composition lemma's validity is argued in the doc, reviewed by Phase
2.5). A green run means the doc's NUMBERS are internally consistent
and anchored to DA's published tables, nothing more.

Sections:
  1. Anchors: reproduce DA's greyhound_params_spike constants and rows
     (slack model bases, gamma budgets, the compounded L=2 failure, the
     FFN compounded 41.6 MB floor, the per-level FFN sound total).
  2. Monte-Carlo operator norms of quinary challenges/differences at
     D = 128 (singular values via evaluation at odd 256th roots):
     percentiles, R-EB1 cap candidates with resampling rates.
  3. Per-level chains at DA's schedules: honest bounds beta'_i, C-win
     window margins (q/125 and q/168), corrected beta_top per level,
     kappa needed for >= 128-bit [core-SVP] MSIS.
  4. Byte deltas at kappa = 11 (+ R-EB3 t = 7 line) for both shapes and
     both sound configs, vs the 262,144 B budget.
  5. Knowledge-error sums (Eq.-18 house bracket) post-FS at Q = 2^64
     for the five configurations of doc Section 3.3 + batching term.
  6. Compounded rule reproduced (budget shrinks per level; no L = 2).

Level-schedule machinery replicated from scripts/greyhound_params_spike.py
(U-AG2 Agent DA) so the two spikes stay independently runnable; anchor
checks in Section 1 pin the replication against DA's published outputs.

stdlib + numpy; runs in seconds; O(10 MB) memory.
"""

import math
import numpy as np

# --------------------------------------------------------------------------
# House constants (params.rs / mod.rs, verified 2026-07-27; DA Section 1)
# --------------------------------------------------------------------------
D = 128
Q31 = 2147483249
LOG2_Q = 31.0
LOG2_DELTA0 = 0.005326
TAIL = 1.3
E_C2 = 2.0
E_RHO2 = 2.0 / 3.0
LOG2_C = 128 * math.log2(5)          # 297.2
OP_CONC = TAIL * math.sqrt(E_C2 * D)          # 20.79
OP_DC_CONC = TAIL * math.sqrt(2 * E_C2 * D)   # 29.40
KEL_B = 64
POLY_B = 4 + D * 4                    # 516
BUDGET = 262_144
Q_FS = 2.0 ** 64                      # house grinding convention
S_JL = math.sqrt(128.0 / 30.0)        # 2.0656 (= sqrt(256/60) at 512 rows)
S_FORK = 2.0

# [LaB]/[PSS] verified constants (doc Section 0.2/1.4)
JL_WINDOW_C1_256 = 125.0   # [LaB] Lemma 4.2 (tighter than [PSS]'s 120)
JL_WINDOW_C1_512 = 168.0   # [PSS] Lemma 2.2 at lambda = 256
JL_ERR_256 = -128.0        # log2, [LaB] Lemma 4.2
JL_ERR_512 = -256.0        # log2, [PSS] Lemma 2.2 at lambda = 256

checks = []


def check(name, ok, detail=""):
    checks.append((name, ok, detail))
    print("  [%s] %s%s" % ("OK" if ok else "FAIL", name,
                           (" — " + detail) if detail else ""))


# --------------------------------------------------------------------------
# Core-SVP + C3 (replicated from DA's spike; anchored below)
# --------------------------------------------------------------------------

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


def msis_bits(k_z, log2_q, log2_beta):
    if log2_beta >= log2_q:
        return 0.0
    ld = (log2_beta / 2.0) ** 2 / (k_z * log2_q)
    return 0.292 * block_for_delta(2.0 ** ld)


def c3_kappa(log2_beta, log2_q):
    k_z = math.ceil((log2_beta / 2.0) ** 2 / (log2_q * LOG2_DELTA0))
    return math.ceil(k_z / D), k_z


# --------------------------------------------------------------------------
# DA's slack models + gamma budget (replicated; anchored)
# --------------------------------------------------------------------------
SLACK_MODELS = {
    "per-level": dict(per_level=1.0, base=S_FORK * S_JL * OP_DC_CONC),
    "exact-digit": dict(per_level=1.0, base=S_FORK * OP_DC_CONC),
    "compounded": dict(per_level=S_FORK * S_JL,
                       base=S_FORK * S_JL * OP_DC_CONC),
}


def gamma_budget(log2_q, model, extra_levels):
    m = SLACK_MODELS[model]
    slack = m["base"] * m["per_level"] ** extra_levels
    return (2.0 ** (log2_q - 3)) / slack


# --------------------------------------------------------------------------
# DA's schedule + byte machinery (replicated from greyhound_params_spike.py)
# --------------------------------------------------------------------------
SHAPES = {
    "2^20 layer": dict(n_el=1_048_572, data_commits=50_197,
                       dw=21, dt=9, kel=1348),
    "FFN 512x11008": dict(n_el=5_636_096, data_commits=269_721,
                          dw=24, dt=9, kel=1651),
}


def fold_inf_norm(r, e):
    return TAIL * math.sqrt(r * D * E_C2 * E_RHO2 * 4.0 ** (e - 1))


def digit_l2(n_rings, e):
    """1.3-tail honest l2 bound of an n_rings-ring digit vector at base 2^e
    (E[d^2] = E_RHO2 * 4^(e-1), house convention)."""
    return TAIL * math.sqrt(n_rings * D * E_RHO2 * 4.0 ** (e - 1))


def schedule(n_ring, log2_q, gamma_max, kappa, val_bits, max_levels=10,
             bt_cap=None, T_cap=None, sigma=None):
    """DA's greedy adaptive-base schedule. If bt_cap is given (log2), the
    base choice at levels >= 1 additionally enforces the corrected
    inner-binding validity rule R-EB4 (doc 2.4(d)):
        8 * T_cap * (1 + 2^e) * sigma * beta_i(e)  <=  2^bt_cap,
    beta_i(e) = the level's own witness bound at base e (proxy for the
    next level's, same class — the reporting loop checks the true one)."""
    rows = []
    e0 = None
    for e in range(1, 16):
        l = math.ceil(val_bits / e)
        gamma = OP_CONC * 2.0 ** (e - 1) * math.sqrt(n_ring * l * D)
        if gamma <= gamma_max:
            e0 = (e, l, gamma)
    if e0 is None:
        return None
    e, l0, gamma_z = e0
    lt_guess = math.ceil(val_bits / max(1, e))
    m1 = int(math.sqrt(n_ring * kappa * lt_guess / l0)) or 1
    m2 = math.ceil(n_ring / m1)
    hide = math.ceil(math.ceil(768 * log2_q / 11.7) / D)
    z_len = m1 * l0 + hide
    rows.append(dict(lvl=0, n=n_ring, e=e, l=l0, r=m2, gamma=gamma_z))
    pend = [(z_len, math.log2(fold_inf_norm(m2, e))),
            (m2 * kappa, val_bits), (m2, val_bits)]
    stops = []
    for lvl in range(1, max_levels + 1):
        e_i, n_i = None, None
        for e_try in range(1, int(log2_q) + 1):
            n_try = sum(c * max(1, math.ceil(b / e_try)) for c, b in pend)
            gamma = OP_CONC * 2.0 ** (e_try - 1) * math.sqrt(n_try * D)
            if gamma > gamma_max:
                continue
            if bt_cap is not None:
                bt = 8 * T_cap * (1 + 2.0 ** e_try) * sigma \
                    * digit_l2(n_try, e_try)
                if math.log2(bt) > bt_cap:
                    continue
            e_i, n_i = e_try, n_try
        if e_i is None:
            break
        bare, e_bare, n_bare = None, None, None
        for e_s in range(1, e_i + 1):
            n_s = sum(c * max(1, math.ceil(b / e_s)) for c, b in pend)
            bytes_s = n_s * D * math.ceil((e_s + 1) / 8)
            if bare is None or bytes_s < bare:
                bare, e_bare, n_bare = bytes_s, e_s, n_s
        stops.append((lvl, n_bare, e_bare, bare))
        best = None
        for r in range(4, 257):
            if r > n_i:
                break
            gamma_i = OP_CONC * 2.0 ** (e_i - 1) * math.sqrt(n_i * D)
            wz_b = math.log2(fold_inf_norm(r, e_i))
            nxt = [(math.ceil(n_i / r), wz_b),
                   (r * kappa, val_bits),
                   (r * (r + 1), val_bits)]
            n_nxt = sum(c * max(1, math.ceil(b / e_i)) for c, b in nxt)
            if best is None or n_nxt < best[1]:
                best = (r, n_nxt, gamma_i, wz_b, nxt)
        r, n_nxt, gamma_i, wz_b, pend = best
        rows.append(dict(lvl=lvl, n=n_i, e=e_i, l=1, r=r, gamma=gamma_i))
        if n_nxt >= n_i:
            break
    return dict(rows=rows, stops=stops, gamma_z=gamma_z, m1=m1, m2=m2,
                e0=e, l0=l0, z_len=z_len, hide=hide)


def eval_proof_bytes(sched, kappa, agg_bytes=4 + 16 * KEL_B, jl_bytes=4 + 256 * 4):
    v_commit = 4 + kappa * POLY_B
    per_level_wire = ((4 + kappa * POLY_B) + jl_bytes + agg_bytes)
    best = None
    for (lvl, n_i, e_i, bare) in sched["stops"]:
        total = v_commit + (lvl - 1) * per_level_wire + bare
        if best is None or total < best[0]:
            best = (total, lvl, n_i, e_i, bare)
    total, lvl, n_i, e_i, bare = best
    return dict(total=total, stop_level=lvl, n_final=n_i, e_final=e_i,
                bare=bare, per_level_wire=per_level_wire)


def artifact_total(shape, sched, kappa, n_gc=2, agg_bytes=4 + 16 * KEL_B,
                   jl_bytes=4 + 256 * 4):
    ep = eval_proof_bytes(sched, kappa, agg_bytes, jl_bytes)
    total = (4096 + n_gc * (4 + kappa * POLY_B) + shape["kel"] * KEL_B
             + shape["dw"] * 4 * KEL_B
             + ep["stop_level"] * ep["per_level_wire"] + ep["bare"]
             + 16 * 8 * KEL_B + 2048)
    return total, ep


# --------------------------------------------------------------------------
# 1. ANCHORS against DA's published numbers
# --------------------------------------------------------------------------

def section_anchors():
    print("\n== 1. Anchors vs DA's published tables ==")
    base_pl = SLACK_MODELS["per-level"]["base"]
    check("DA per-level base = 121.7 (2 * 2.066 * 29.4)",
          abs(base_pl - 121.7) < 0.3, "got %.1f" % base_pl)
    check("DA compounded per-level factor = 4.13",
          abs(SLACK_MODELS["compounded"]["per_level"] - 4.13) < 0.01,
          "got %.2f" % SLACK_MODELS["compounded"]["per_level"])
    g_pl = math.log2(gamma_budget(31.0, "per-level", 0))
    g_ed = math.log2(gamma_budget(31.0, "exact-digit", 0))
    g_c2 = math.log2(gamma_budget(31.0, "compounded", 1))
    check("gamma budgets 2^21.07 / 2^22.12 / 2^19.02 (L=2 compounded)",
          abs(g_pl - 21.07) < 0.02 and abs(g_ed - 22.12) < 0.02
          and abs(g_c2 - 19.02) < 0.02,
          "got %.2f / %.2f / %.2f" % (g_pl, g_ed, g_c2))
    # FFN per-level schedule reproduces DA's shape row (e0 = 1, gamma_z 2^20.88)
    ffn = SHAPES["FFN 512x11008"]
    n_ring = ffn["data_commits"] * 1024 // D
    kappa10, kz10 = c3_kappa(31.0 - 3, 31.0)
    s = schedule(n_ring, 31.0, gamma_budget(31.0, "per-level", 0), kappa10, 31)
    check("FFN per-level: e0 = 1, gamma_z = 2^20.88 (DA 3.2)",
          s["e0"] == 1 and abs(math.log2(s["gamma_z"]) - 20.88) < 0.02,
          "e0 = %d, gamma_z = 2^%.2f" % (s["e0"], math.log2(s["gamma_z"])))
    check("compounded L=2 budget < min gamma_z (the DA 3.4 failure row)",
          gamma_budget(31.0, "compounded", 1) < s["gamma_z"],
          "2^%.2f < 2^%.2f" % (g_c2, math.log2(s["gamma_z"])))
    # DA's FFN per-level sound total: base 271,800? DA table: per-level base
    # total (256-row JL widths) 271,800 lower bound row; sound 512-row total
    # 278,968. Reproduce: base artifact at kappa = 10 + 512-JL surcharge.
    total10, ep10 = artifact_total(ffn, s, kappa10)
    jl512_extra = 1024 * max(0, ep10["stop_level"] - 1)
    check("DA FFN per-level artifact reproduced (271,800 base; 278,968 sound)",
          total10 == 271_800 and total10 + jl512_extra == 278_968,
          "base %s, +512JL %s" % (format(total10, ","),
                                  format(total10 + jl512_extra, ",")))
    # 2^20 sound total 252,868 (DA 5.2)
    s20 = schedule(SHAPES["2^20 layer"]["data_commits"] * 1024 // D, 31.0,
                   gamma_budget(31.0, "per-level", 0), kappa10, 31)
    t20, ep20 = artifact_total(SHAPES["2^20 layer"], s20, kappa10)
    check("DA 2^20 per-level sound total reproduced (252,868 B)",
          t20 + 1024 * max(0, ep20["stop_level"] - 1) == 252_868,
          format(t20 + 1024 * max(0, ep20["stop_level"] - 1), ","))
    # Compounded FFN floor 41,593,548 B (DA 5.2): depth-1 schedule
    best = None
    for depth in range(1, 10):
        gm = gamma_budget(31.0, "compounded", depth - 1)
        if gm < 1:
            continue
        sc = schedule(n_ring, 31.0, gm, kappa10, 31, max_levels=depth)
        if sc is None or not sc["stops"]:
            continue
        t, _ = artifact_total(ffn, sc, kappa10)
        if best is None or t < best[0]:
            best = (t, len(sc["rows"]) - 1)
    check("DA compounded FFN floor reproduced (41,593,548 B, one fold level)",
          best is not None and best[0] == 41_593_548 and best[1] == 1,
          "got %s at %d fold level(s) = %.2fx budget"
          % (format(best[0], ","), best[1], best[0] / BUDGET))
    return s, s20, kappa10


# --------------------------------------------------------------------------
# 2. Monte-Carlo operator norms (R-EB1 cap evidence)
# --------------------------------------------------------------------------

def section_mc(n_draws=20000, seed=7):
    print("\n== 2. MC operator norms of quinary challenges at D = 128 ==")
    rng = np.random.default_rng(seed)
    # op(c) = max_j |c(zeta_j)| over the 128 odd 256th roots of unity.
    ks = np.arange(1, 2 * D, 2)                      # 128 odd exponents
    ang = np.exp(1j * math.pi * np.outer(np.arange(D), ks) / D)  # D x 128
    cs = rng.integers(-2, 3, size=(n_draws, D)).astype(float)
    ops = np.abs(cs @ ang).max(axis=1)
    diffs = cs[: n_draws // 2] - cs[n_draws // 2:]
    ops_d = np.abs(diffs @ ang).max(axis=1)
    pct = np.percentile(ops, [50, 90, 99, 99.9])
    pct_d = np.percentile(ops_d, [50, 90, 99, 99.9])
    print("  op(c):    p50 %.1f  p90 %.1f  p99 %.1f  p99.9 %.1f  max %.1f"
          % (*pct, ops.max()))
    print("  op(c-c'): p50 %.1f  p90 %.1f  p99 %.1f  p99.9 %.1f  max %.1f"
          % (*pct_d, ops_d.max()))
    for cap in (28.0, 30.0, 33.0, 36.0, 42.0):
        acc = float((ops <= cap).mean())
        print("  T_cap = %4.1f: acceptance %.2f%% (~%.0f attempts/challenge)"
              % (cap, 100 * acc, 1.0 / max(acc, 1e-9)))
    # FINDING: the house 'op_norm(conc)' = 20.8 is a per-use concentration
    # bound (restart discipline, Q4.1), NOT the operator norm of a typical
    # challenge: the true largest singular value sits well above it.
    check("FINDING (doc 1.3): house conc 20.8 is BELOW the true op-norm "
          "median — unusable as an extraction cap",
          OP_CONC < pct[0], "20.8 < p50 = %.1f" % pct[0])
    check("MC sanity: op(c) median in the RMS-scaled band [30, 40] "
          "(RMS = 16 at D = 128, E[c^2] = 2)",
          30.0 <= pct[0] <= 40.0, "p50 = %.1f" % pct[0])
    acc33 = float((ops <= 33.0).mean())
    acc42 = float((ops <= 42.0).mean())
    check("T_cap = 33 acceptance in the practical 5-50% band",
          0.05 <= acc33 <= 0.50, "%.1f%%" % (100 * acc33))
    check("T_cap = 42 acceptance >= 90% (the near-free cap)",
          acc42 >= 0.90, "%.1f%%" % (100 * acc42))
    return 33.0


# --------------------------------------------------------------------------
# 3. Per-level chains: window margins + corrected beta_top + kappa
# --------------------------------------------------------------------------
BT_CAP = 30.5   # log2 validity ceiling for inner-binding MSIS bounds (< q31)


def chain_stats(s, T_cap, sigma, verbose=True, name=""):
    """Per-level corrected bounds over a schedule; returns worst-case dict."""
    worst = dict(win256=1e9, win512=1e9, kappa=0, beta_top=0.0)
    rows = s["rows"]
    if verbose:
        print("  %s (%d fold levels):" % (name, len(rows) - 1))
    for idx, row in enumerate(rows):
        if idx + 1 < len(rows):
            nxt_n, nxt_e = rows[idx + 1]["n"], rows[idx + 1]["e"]
        else:
            nxt_n, nxt_e = s["stops"][-1][1], s["stops"][-1][2]
        b_i = 2.0 ** row["e"]
        beta_next = digit_l2(nxt_n, nxt_e)
        beta_i = digit_l2(row["n"], row["e"])
        # corrected inner-binding bound (doc 2.1 C-msis, [LaB] Thm 5.1 form)
        bt = max(8 * T_cap * (1 + b_i) * sigma * beta_next,
                 2 * (1 + b_i) * sigma * beta_next
                 + 4 * T_cap * sigma * beta_i)
        kappa_need = None
        for kap in range(8, 16):
            if msis_bits(kap * D, LOG2_Q, math.log2(bt)) >= 128.0:
                kappa_need = kap
                break
        m256 = (LOG2_Q - math.log2(JL_WINDOW_C1_256)) - \
            math.log2(sigma * beta_i)
        m512 = (LOG2_Q - math.log2(JL_WINDOW_C1_512)) - \
            math.log2(sigma * beta_i)
        worst["win256"] = min(worst["win256"], m256)
        worst["win512"] = min(worst["win512"], m512)
        worst["kappa"] = max(worst["kappa"], kappa_need or 99)
        worst["beta_top"] = max(worst["beta_top"], math.log2(bt))
        if verbose:
            print("    L%d: e=%2d n=%8d beta_i=2^%5.2f beta'=2^%5.2f "
                  "beta_top=2^%5.2f kappa>=%s win256 %+.2f b win512 %+.2f b"
                  % (row["lvl"], row["e"], row["n"], math.log2(beta_i),
                     math.log2(beta_next), math.log2(bt),
                     kappa_need, m256, m512))
    return worst


def section_chains(T_cap):
    print("\n== 3a. DA's UNCAPPED schedules under the corrected constant ==")
    kappa10, _ = c3_kappa(31.0 - 3, 31.0)
    da_scheds = {}
    for name, shape in SHAPES.items():
        n_ring = shape["data_commits"] * 1024 // D
        da_scheds[name] = schedule(n_ring, 31.0,
                                   gamma_budget(31.0, "per-level", 0),
                                   kappa10, 31)
    w = {}
    for name, s in da_scheds.items():
        w[name] = chain_stats(s, T_cap, S_JL, verbose=(name.startswith("FFN")),
                              name=name)
    max_bt = max(x["beta_top"] for x in w.values())
    check("FINDING R-EB4: DA's e = 8-10 floor bases VIOLATE MSIS validity "
          "(beta_top > q) at the corrected constant",
          max_bt > LOG2_Q, "max beta_top = 2^%.2f > 2^31" % max_bt)

    results = {}
    for sigma, tag in ((S_JL, "JL"), (1.0, "exact-digit")):
        print("\n== 3b. CORRECTED schedules (R-EB4 base cap), sigma = %.2f "
              "(%s), T_cap = %.0f ==" % (sigma, tag, T_cap))
        worst_all = dict(win256=1e9, win512=1e9, kappa=0, beta_top=0.0)
        scheds = {}
        for name, shape in SHAPES.items():
            n_ring = shape["data_commits"] * 1024 // D
            s = schedule(n_ring, 31.0, gamma_budget(31.0, "per-level", 0),
                         kappa10, 31, bt_cap=BT_CAP, T_cap=T_cap, sigma=sigma)
            scheds[name] = s
            ws = chain_stats(s, T_cap, sigma, verbose=True, name=name)
            for k in worst_all:
                if k.startswith("win"):
                    worst_all[k] = min(worst_all[k], ws[k])
                else:
                    worst_all[k] = max(worst_all[k], ws[k])
        check("C-win holds at EVERY level, 256-row window (q/125), %s" % tag,
              worst_all["win256"] > 0,
              "min margin %+.2f bits" % worst_all["win256"])
        check("C-win holds at EVERY level, 512-row window (q/168), %s" % tag,
              worst_all["win512"] > 0,
              "min margin %+.2f bits" % worst_all["win512"])
        check("corrected beta_top valid (<= 2^%.1f < q) at ALL levels, %s"
              % (BT_CAP + 0.5, tag),
              worst_all["beta_top"] <= BT_CAP + 0.5,
              "max 2^%.2f" % worst_all["beta_top"])
        check("kappa <= 12 gives >= 128-bit MSIS at ALL levels, %s" % tag,
              worst_all["kappa"] <= 12,
              "max kappa needed = %d" % worst_all["kappa"])
        results[tag] = (worst_all["kappa"], scheds)
    return results


# --------------------------------------------------------------------------
# 4. Byte deltas at kappa = 11 (+ R-EB3)
# --------------------------------------------------------------------------

def section_bytes(chain_results, T_cap):
    kappa_new = max(k for k, _ in chain_results.values())
    print("\n== 4. Bytes at corrected kappa = %d, R-EB4-capped schedules =="
          % kappa_new)
    out = {}
    for shape_name, shape in SHAPES.items():
        n_ring = shape["data_commits"] * 1024 // D
        for cfg, sigma_tag, agg_b, jl_b in (
                ("512-JL + t=7 [R-EB3 t-up]", "JL", 4 + 7 * POLY_B,
                 4 + 512 * 4),
                ("512-JL + K-draw", "JL", 4 + 2 * POLY_B, 4 + 512 * 4),
                ("exact-digit + K-draw", "exact-digit", 4 + 2 * POLY_B, 0)):
            sigma = S_JL if sigma_tag == "JL" else 1.0
            s = schedule(n_ring, 31.0, gamma_budget(31.0, "per-level", 0),
                         kappa_new, 31, bt_cap=BT_CAP, T_cap=T_cap,
                         sigma=sigma)
            t, ep = artifact_total(shape, s, kappa_new,
                                   agg_bytes=agg_b, jl_bytes=jl_b)
            ratio = t / BUDGET
            out[(shape_name, cfg)] = (t, ratio)
            print("  %-14s %-28s %10s B  %.3fx  -> %s   (stop L%d, %d rings)"
                  % (shape_name, cfg, format(t, ","), ratio,
                     "PASS" if t <= BUDGET else "OVER",
                     ep["stop_level"], ep["n_final"]))
    t20e = out[("2^20 layer", "exact-digit + K-draw")][0]
    check("2^20 exact-digit stays PASS at corrected kappa",
          t20e <= BUDGET,
          "%s B = %.3fx" % (format(t20e, ","), t20e / BUDGET))
    t20 = out[("2^20 layer", "512-JL + K-draw")][0]
    check("FINDING (doc 5.1): 2^20 512-JL goes OVER at corrected constants "
          "(pre-lever) — exact-digit is the byte-preferred branch too",
          BUDGET < t20 <= 1.10 * BUDGET,
          "%s B = %.3fx" % (format(t20, ","), t20 / BUDGET))
    tf = out[("FFN 512x11008", "exact-digit + K-draw")][0]
    check("FFN exact-digit overage stays in the ~1.0-1.2x lever band",
          1.0 < tf / BUDGET < 1.2, "%.3fx" % (tf / BUDGET))

    # 4b. The relaxed-e0 experiment [export to O-2]: the corrected model
    # has NO q/8 line — level-0's base is constrained by R-EB4 + C-win
    # only, so gamma_max can relax to the window-derived line. One point:
    print("  -- 4b. relaxed-e0 experiment (gamma_max = window line "
          "2^%.2f, R-EB4 active) [O-2 export, not the primary row] --"
          % (LOG2_Q - math.log2(JL_WINDOW_C1_256) - math.log2(S_JL)))
    g_relax = 2.0 ** (LOG2_Q - math.log2(JL_WINDOW_C1_256)
                      - math.log2(S_JL))
    improved = {}
    for shape_name, shape in SHAPES.items():
        n_ring = shape["data_commits"] * 1024 // D
        for cfg, sigma_tag, agg_b, jl_b in (
                ("512-JL + K-draw", "JL", 4 + 2 * POLY_B, 4 + 512 * 4),
                ("exact-digit + K-draw", "exact-digit", 4 + 2 * POLY_B, 0)):
            sigma = S_JL if sigma_tag == "JL" else 1.0
            s = schedule(n_ring, 31.0, g_relax, kappa_new, 31,
                         bt_cap=BT_CAP, T_cap=T_cap, sigma=sigma)
            w = chain_stats(s, T_cap, sigma, verbose=False)
            t, ep = artifact_total(shape, s, kappa_new,
                                   agg_bytes=agg_b, jl_bytes=jl_b)
            ok_valid = (w["beta_top"] <= BT_CAP + 0.5 and w["kappa"] <= 12
                        and w["win256"] > 0)
            improved[(shape_name, cfg)] = (t, ok_valid)
            print("     %-14s %-22s e0 = %d  %10s B  %.3fx  %s  (valid: %s)"
                  % (shape_name, cfg, s["e0"], format(t, ","), t / BUDGET,
                     "PASS" if t <= BUDGET else "OVER",
                     "yes" if ok_valid else "NO"))
    check("relaxed-e0 keeps all soundness gates green where run",
          all(v for _, v in improved.values()), "")
    check("relaxed-e0 improves or matches every DA-anchored row",
          all(improved[k][0] <= out[k][0] + 1 for k in improved), "")
    return out, kappa_new


# --------------------------------------------------------------------------
# 5. Knowledge-error sums (doc Section 3.3 table)
# --------------------------------------------------------------------------

def ke_post_fs(levels, r_list, jl_log2, t_agg, kdraw=False):
    """Eq.-(18) house bracket, summed, times 2(Q+1). All log2."""
    per_level = []
    for r in r_list:
        terms = []
        if jl_log2 is not None:
            terms.append(2.0 ** jl_log2)
        if not kdraw and t_agg is not None:
            terms.append(2.0 ** (-31.0 * t_agg))
        if kdraw:
            terms.append(2.0 ** -496.0)          # K/R_q-draw aggregation
        terms.append(2.0 ** -496.0)              # alpha/beta full-entropy
        terms.append((5 + 2 * 8) * r * 2.0 ** -LOG2_C)   # fold, l = 8
        per_level.append(sum(terms))
    total = sum(per_level)
    total += 16 * 2.0 ** -LOG2_C                 # batching round (SC-L6)
    total += 2.0 ** -485.0                       # DB engine SZ class
    return math.log2(2 * (Q_FS + 1) * total)


def section_ke(s_ffn):
    print("\n== 5. Post-FS knowledge error (Q = 2^64, DA FFN schedule) ==")
    r_list = [row["r"] for row in s_ffn["rows"]]
    L = len(r_list)
    rows = [
        ("256-row JL, any t", JL_ERR_256, 5, False, "FAIL"),
        ("512-row JL + t = 5 [missing-term row]", JL_ERR_512, 5, False, "FAIL"),
        ("512-row JL + t = 7 [R-EB3]", JL_ERR_512, 7, False, "PASS"),
        ("512-row JL + K-draw", JL_ERR_512, None, True, "PASS"),
        ("exact-digit + K-draw", None, None, True, "PASS"),
    ]
    got = {}
    for name, jl, t, kd, want in rows:
        v = ke_post_fs(L, r_list, jl, t, kd)
        verdict = "PASS" if v <= -128 else "FAIL"
        got[name] = (v, verdict)
        print("  %-38s post-FS 2^%7.1f  -> %s (doc: %s)"
              % (name, v, verdict, want))
        check("KE verdict matches doc: %s" % name, verdict == want,
              "2^%.1f" % v)
    # spot expectations from the doc table (loose tolerance: schedule-dependent)
    check("256-JL lands in the 2^-55..-70 class (doc ~2^-60)",
          -70 <= got[rows[0][0]][0] <= -55, "2^%.1f" % got[rows[0][0]][0])
    check("512-JL + t5 lands in the 2^-80..-95 class (the missing term)",
          -95 <= got[rows[1][0]][0] <= -80, "2^%.1f" % got[rows[1][0]][0])
    check("batching term alone ~2^-228 class",
          abs(math.log2(2 * (Q_FS + 1) * 16 * 2.0 ** -LOG2_C) - (-228)) < 2,
          "2^%.1f" % math.log2(2 * (Q_FS + 1) * 16 * 2.0 ** -LOG2_C))


# --------------------------------------------------------------------------
# 6. Compounded rule reproduced (the boundary configuration)
# --------------------------------------------------------------------------

def section_compounded():
    print("\n== 6. Compounded rule (the refuted reading, reproduced) ==")
    budgets = [math.log2(gamma_budget(31.0, "compounded", L - 1))
               for L in range(1, 6)]
    print("  gamma budget by depth L: " +
          ", ".join("L=%d: 2^%.2f" % (i + 1, b) for i, b in enumerate(budgets)))
    check("compounded budget shrinks 2.05 bits/level (log2 4.13)",
          abs((budgets[0] - budgets[1]) - math.log2(4.13)) < 0.01,
          "%.2f bits" % (budgets[0] - budgets[1]))
    check("compounded admits L = 1 only at q31 (budget(2) < 2^20.88)",
          budgets[0] > 20.88 > budgets[1],
          "budget(1) 2^%.2f > gamma_z^min 2^20.88 > budget(2) 2^%.2f"
          % (budgets[0], budgets[1]))


def main():
    print("slack_composition_spike — EB/O-7 arithmetic checks")
    print("(checks arithmetic, not proofs — see header)")
    s_ffn, s_20, kappa10 = section_anchors()
    T_cap = section_mc()
    chain_results = section_chains(T_cap)
    section_bytes(chain_results, T_cap)
    # KE sums over the corrected JL schedule's fold counts
    section_ke(chain_results["JL"][1]["FFN 512x11008"])
    section_compounded()
    n_ok = sum(1 for _, ok, _ in checks if ok)
    print("\nRESULT: %d/%d OK%s" % (n_ok, len(checks),
                                    "" if n_ok == len(checks) else
                                    "  — FAILURES ABOVE"))
    if n_ok != len(checks):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
