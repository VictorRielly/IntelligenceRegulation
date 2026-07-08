#!/usr/bin/env python3
"""Gadget-layer modulus decision study (finding F3).

Computes every table in docs/zkmatrix-poc/GADGET_MODULUS_DECISION.md — no
hand-computed numbers appear in that document. Mirrors, where they exist,
the Rust derivations this study prices:

  - zkmatrix-rs/src/ring/ct_engine.rs::derive_arp_params / arp_budget_ok
    (SLACK_OP = 4D, JL_C = 13) — section A;
  - zkmatrix-rs/src/ring/ct_engine.rs::derive_ct_round_params +
    the C3/C4 lines of scripts/route_r_params.py — section B1;
  - the per-chunk Ajtai chain of derive_ct_round_params's s-bundle —
    section C.

Anchors imported from the measured docs (marked [anchor] in the output):
LLM_SCALE_ESTIMATE.md (9.4e9 committed element-equivalents/pass, 5.8x bill
factor at w = 12 on 40% of tensors, commit bill 1.6-2.0 min 22T / 5-6 s
GPU with A1, claim layer 10-25 s wall 22T, (bits/30)^2 int8-GEMM scaling),
RING_MULT_BOTTLENECK.md section 6.3/6.4 (0.571 ring-MACs/element at the
q31 FFN point; ring mul 3.9-4.4 us k=8; 4.6e9 scalar MACs/s mod-q matmul).

Run: python3 scripts/gadget_modulus_study.py     (from the repo root)
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import route_r_params as rp  # noqa: E402  (D, E_C2, TAIL, LOG2_DELTA0)

D = rp.D                     # 128
E_C2 = rp.E_C2               # 2.0 quinary
TAIL = rp.TAIL               # 1.3
LOG2_DELTA0 = rp.LOG2_DELTA0

Q31 = 2_147_483_249          # q8_31 = 2^31 - 399  (ring/mod.rs Q8)
Q46 = 70_368_744_176_561     # q8_46 = 2^46 - 1103 (ring/mod.rs Q8_46)

SLACK_OP = 4.0 * D           # ct_engine.rs conservative worst-case ||c-bar||_1
SLACK_CONC = TAIL * math.sqrt(E_C2 * D)  # concentration operator norm ~20.8
JL_C = 13.0                  # ct_engine.rs JL lower-bound constant

W_BITS = 12                  # range width of the LLM quantized spec
BIT_COVERAGE = 0.40          # fraction of tensors range-proved (LLM_SCALE)
ELEMENTS_PASS = 9.4e9        # committed element-equivalents / 7B/512 pass
BILL_FACTOR = 1.0 + BIT_COVERAGE * W_BITS  # 5.8
TENSORS_PASS = 10 * 32       # ~10 tensors/layer x 32 layers
LINKED_TENSORS = int(BIT_COVERAGE * TENSORS_PASS)  # range-proved tensors

MACS_PER_SEC = 4.6e9         # measured mod-q matmul rate, 1T [anchor]
RING_MUL_US = 4.2            # k = 8 ring mul, us, 1T [anchor 3.9-4.4]
COMMIT_22T_MIN = (1.6, 2.0)  # A1-integrated commit bill, 22T [anchor]
COMMIT_GPU_S = (5.0, 6.0)    # assumed 20x GPU row [anchor]
CLAIMS_22T_S = (10.0, 25.0)  # claim layer wall, 22T [anchor]
CLAIMS_1T_S = (110.0, 330.0)  # ~2,200 claims x 0.05-0.15 s [anchor]


def log2(x):
    return math.log(x, 2) if x > 0 else float("-inf")


def hr(title):
    print("\n" + "=" * 74)
    print(title)
    print("=" * 74)


# ===========================================================================
# Section A — F3 reproduction: the ARP budget chain, exactly as coded in
# ct_engine.rs::derive_arp_params, with the slack constant as a parameter.
# ===========================================================================

def arp_chain(n, rows, w_inf, alpha, slack):
    """Mirror of derive_arp_params with SLACK_OP -> slack."""
    center_row = 1.3 * math.sqrt(n * 0.5) * w_inf   # E[R^2] = 1/2
    center_bundle = center_row * math.sqrt(rows)
    sigma_arp = math.ceil(alpha * center_bundle)
    y_bound = 1.2 * sigma_arp * math.sqrt(rows)
    extract = slack * 2.0 * y_bound / math.sqrt(rows / JL_C)
    return sigma_arp, y_bound, extract


def defect_bound(extract, n):
    """arp_budget_ok's quadratic-defect bound B^2 + B sqrt(n)."""
    return extract * extract + extract * math.sqrt(n)


def section_a():
    hr("A. Finding F3 reproduced (ARP side-condition budget, n = 512, "
       "rows = 256, alpha = 3)")
    n, rows, alpha = 512, 256, 3.0
    print(f"  budgets: q31/2 = 2^{log2(Q31 / 2):.2f}, "
          f"q46/2 = 2^{log2(Q46 / 2):.2f}")
    print("\n  | slack | meaning | extract bound | defect bound | q31? | q46? |")
    print("  |---|---|---|---|---|---|")
    for slack, name in [(SLACK_OP, "4D worst-case l1 (as coded)"),
                        (SLACK_CONC, "concentration op norm 1.3 sqrt(2D)"),
                        (2.0, "unit-slack class (LNP22-style, UNPROVEN)")]:
        _, _, ex = arp_chain(n, rows, 1, alpha, slack)
        df = defect_bound(ex, n)
        q31 = "closes" if df < Q31 / 2 else "FAILS"
        q46 = "closes" if df < Q46 / 2 else "FAILS"
        print(f"  | {slack:6.1f} | {name} | 2^{log2(ex):.1f} | 2^{log2(df):.1f}"
              f" | {q31} | {q46} |")
    # Assert the report's numbers reproduce.
    _, _, ex_wc = arp_chain(n, rows, 1, alpha, SLACK_OP)
    _, _, ex_c = arp_chain(n, rows, 1, alpha, SLACK_CONC)
    assert abs(log2(ex_wc) - 22.1) < 0.1, log2(ex_wc)
    assert abs(log2(ex_c) - 17.4) < 0.15, log2(ex_c)
    assert defect_bound(ex_wc, n) < Q46 / 2
    assert defect_bound(ex_wc, n) > Q31 / 2
    print("\n  [check] F3's 2^22.1 (conservative) and 2^17.4 (optimistic) "
          "reproduce; q46 closes, q31 does not — asserted.")
    df46 = defect_bound(ex_wc, n)
    print(f"  q46 margin under conservative constants: "
          f"{log2(Q46 / 2) - log2(df46):.2f} bits (thin — see Q4.4 for the "
          f"proof status of the constants themselves).")


# ===========================================================================
# Section B — option (a): gadget claims at a q46-class budget + the
# modulus link.
# ===========================================================================

def derive_gadget_layer(q, msg_r, n_commits):
    """Commitment shape for a gadget-wave ct-round at modulus q.

    Mirrors ct_engine.rs::derive_ct_round_params (concentration operator
    norm, restart discipline) for the round's std bundle, iterated against
    C3/C4 exactly as scripts/route_r_params.py::derive does. Returns None
    when C2 fails (< 1 bit headroom).
    """
    log2_q = log2(q)
    msg_z = msg_r * D
    d_lwe = math.ceil(768.0 * log2_q / 11.7)
    op = TAIL * math.sqrt(2.0 * D)  # concentration op norm (conc = true)
    k_z = 12 * D
    out = None
    for _ in range(8):
        n_z = (math.ceil((k_z + msg_z + d_lwe) / D)) * D
        bundle = n_commits * n_z
        t_bundle = op * math.sqrt(bundle)
        sigma = 12.0 * t_bundle
        bound = 1.2 * sigma * math.sqrt(bundle)
        beta = 2.0 * bound + op * math.sqrt(bundle)
        k_z = math.ceil((log2(beta) / 2.0) ** 2 / (log2_q * LOG2_DELTA0))
        out = dict(kappa=math.ceil(k_z / D), n_r=n_z // D, sigma=sigma,
                   beta=beta, log2_q=log2_q)
    if q <= 8.0 * out["beta"] * 2.0:  # >= 1 bit of C2 headroom
        return None
    out["c2_headroom"] = log2_q - log2(8.0 * out["beta"])
    out["macs_el"] = (1.0 + out["kappa"] / msg_r) * out["n_r"] / D
    out["col_kb"] = (out["kappa"] + msg_r) * D * log2_q / 8.0 / 1024.0
    return out


def section_b1():
    hr("B1. Option (a): the q46 gadget commitment layer, derived honestly")
    print("  (ct-wave round, concentration discipline, msg_r = 32 FFN "
          "columns; C2/C3/C4\n   iterated as in route_r_params.py; "
          "n_commits = commitments per wave bundle)")
    print("\n  | q | n_commits | kappa | N_r | C2 headroom | ring-MACs/el "
          "| commit KB/col |")
    print("  |---|---|---|---|---|---|---|")
    results = {}
    for q, qn in [(Q31, "q31"), (Q46, "q46")]:
        for n_c in (16, 64, 256):
            r = derive_gadget_layer(q, 32, n_c)
            if r is None:
                print(f"  | {qn} | {n_c} | — | — | C2 FAILS (< 1 bit) "
                      f"| — | — |")
            else:
                print(f"  | {qn} | {n_c} | {r['kappa']} | {r['n_r']} | "
                      f"{r['c2_headroom']:.1f} bits | {r['macs_el']:.3f} | "
                      f"{r['col_kb']:.1f} |")
                results[(qn, n_c)] = r
    r31 = results[("q31", 16)]
    r46 = results[("q46", 16)]
    cpu_ratio = r46["macs_el"] / r31["macs_el"]
    bytes_ratio = r46["col_kb"] / r31["col_kb"]
    # GPU int8-GEMM count scales ~(bits/30)^2 (LLM_SCALE section 3).
    gpu_ratio = cpu_ratio * (46.0 / 30.0) ** 2 / (31.0 / 30.0) ** 2
    print(f"\n  q31 wave capacity note: 64+-commitment wave bundles FAIL C2 "
          f"at q31 —\n  the q31 gadget wave must stay partitioned near "
          f"~16 commitments; at q46 the\n  same derivation holds "
          f"{results[('q46', 256)]['c2_headroom']:.0f}+ bits of headroom at "
          f"256 (wave-partition pressure gone).")
    print(f"\n  per-bit-element cost, q46 vs q31 gadget layer:")
    print(f"    CPU (A1 kernels, P0):           x{cpu_ratio:.2f}")
    print(f"    commit-stream bytes:            x{bytes_ratio:.2f}")
    print(f"    GPU int8-GEMM count ((46/30)^2 vs (31/30)^2): "
          f"x{gpu_ratio:.2f}")
    # P0 regime check (a1_path from route_r_params): the commit regime
    # (key x ternary rho) stays single-prime at q46; the Gaussian-mask
    # regime does NOT (limb-split x3) — per-round mask matvecs only,
    # not per committed element.
    n_acc = r46["n_r"]
    commit_path = rp.a1_path(n_acc, Q46, 1)
    mask_path = rp.a1_path(n_acc, Q46, int(12 * r46["sigma"]))
    print(f"    P0 at q46 (n_acc = {n_acc}): commit regime -> "
          f"{commit_path}; mask regime -> "
          f"{mask_path or 'NONE'} (per-round cost, not per element)")
    return r31, r46, cpu_ratio, bytes_ratio, gpu_ratio


def link_rows(w):
    """Rows for 2^-256 at per-row miss 2^-w (signed uniform w-bit weights:
    max point mass of <xi, delta> mod prime q is 2^-w for delta != 0)."""
    return math.ceil(256.0 / w)


def section_b2():
    hr("B2. Option (a): the modulus link (q46 bit commitments <-> q31 "
       "value commitments)")
    print("""  Design (one argument subsumes recomposition + link):
    - After BOTH commitment groups enter one statement hash h0_link
      (both CRS hashes bound), derive l rows of signed uniform w-bit
      weights xi_(l,t), t over the tensor's VALUE coordinates.
    - Structured functional: weight on bit (i, t) is xi_(l,t) * 2^i at
      q46; weight on value t is xi_(l,t) at q31. Then
        y_l := sum_t xi_(l,t) * sum_i 2^i b_(i,t) = <xi_l, v>
      is ONE integer, revealed, range-checked, and asserted by a linear
      ct-claim at q46 (over the bit commitments) AND at q31 (over the
      value commitments) — same y_l on both sides.
    - Soundness: q46 side is integer-exact (bits proven binary there, so
      |<xi, V46>| <= n 2^(w-1) (2^W - 1) < q46/2 and the range check
      |y| < q46/2 pins the integer); the q31 side then forces
      V31 = V46 (mod q31) unless a row catches the nonzero difference:
      per-row miss <= 2^-w, rows = ceil(256/w). V46 in [0, 2^W)^n
      integers => the q31 values are range-grounded. No recomposition
      claim at q31, no duplicate bit commitments.""")
    print("\n  | granularity | n values | w_max | rows l | worst |y| "
          "| honest |y| (1.3-tail) | < q31/2? |")
    print("  |---|---|---|---|---|---|---|")
    grans = []
    for name, n_val in [("column (msg_r = 32)", 32 * D),
                        ("token-block 512x4096 tensor slice", 512 * 4096),
                        ("full FFN tensor 512x11008", 512 * 11008)]:
        # q46-side integer-exactness cap: n * 2^(w-1) * (2^W - 1) < q46/2.
        w_max = int(math.floor(log2(Q46 / 2.0 / (n_val * (2 ** W_BITS - 1))))) + 1
        w_max = max(1, w_max)
        rows = link_rows(w_max)
        worst_y = n_val * 2 ** (w_max - 1) * (2 ** W_BITS - 1)
        # honest scale: y = sum of n_val terms xi*v, xi ~ U signed w-bit
        # (var 2^(2w)/12, centered), v in [0, 2^W) UNCENTERED: since xi is
        # centered, Var(xi*v) = E[xi^2] E[v^2] with E[v^2] <= 2^(2W)/3
        # (spike-verified: the /12 variant underestimates by ~1 bit).
        sd = math.sqrt(n_val * (2 ** (2 * w_max) / 12.0)
                       * (2 ** (2 * W_BITS) / 3.0))
        honest_y = TAIL * sd
        ok31 = "yes" if honest_y < Q31 / 2 else "NO (gate at q46/2 only)"
        print(f"  | {name} | {n_val} | {w_max} | {rows} | 2^{log2(worst_y):.1f}"
              f" | 2^{log2(honest_y):.1f} | {ok31} |")
        grans.append((name, n_val, w_max, rows))
    print("""
  Range-check note: only |y| < q46/2 is load-bearing (the side with the
  integer grounding); the brief's symmetric |y| < q31/2 check holds
  honestly at column granularity and worst-case-fails at tensor
  granularity — at tensor granularity keep the gate at q46/2 (sound) or
  gate at a concentration bound with the Q4.1 restart rule.""")
    # Cost table (per linked tensor at tensor granularity; per pass).
    print("\n  Link cost (per side: reveal h_l + mask image W_l, one ring "
          "element each;\n  g-slot share amortized at msg_r per column):")
    print("\n  | granularity | rows | bytes/row | KB/tensor-link | "
          "MB/pass (128 linked tensors) |")
    print("  |---|---|---|---|---|")
    r31 = derive_gadget_layer(Q31, 32, 16)
    r46 = derive_gadget_layer(Q46, 32, 16)
    per_pass_mb = {}
    for name, n_val, w, rows in grans:
        b_row = 8.0                                   # y_l as i64
        b_row += 2 * D * 46 / 8.0                     # q46 h_l + W_l
        b_row += 2 * D * 31 / 8.0                     # q31 h_l + W_l
        b_row += r46["col_kb"] * 1024 / 32.0 / 32.0   # q46 g-slot share
        b_row += r31["col_kb"] * 1024 / 32.0 / 32.0   # q31 g-slot share
        kb_tensor = rows * b_row / 1024.0
        n_tensors = LINKED_TENSORS if "FFN" in name else None
        mb_pass = (kb_tensor * LINKED_TENSORS / 1024.0
                   if n_tensors else float("nan"))
        per_pass_mb[name] = (rows, kb_tensor, mb_pass)
        mp = f"{mb_pass:.1f}" if n_tensors else "(scale by tensor count)"
        print(f"  | {name} | {rows} | {b_row:.0f} B | {kb_tensor:.1f} | {mp} |")
    # Prover arithmetic for the link claims (functional evaluation).
    name, n_val, w, rows = grans[2]
    macs = LINKED_TENSORS * rows * (n_val * (W_BITS + 1))
    t_1t = macs / MACS_PER_SEC
    print(f"\n  link prover arithmetic per pass (functional evals): "
          f"{macs:.2e} MACs = {t_1t:.0f} s 1T ~ {t_1t / 15:.1f} s 22T "
          f"[anchor 4.6e9 MACs/s] — noise-class.")
    print(f"  soundness: per-row miss 2^-{w}, {rows} rows -> "
          f"2^-{w * rows} <= 2^-256; one FS challenge event, inside the "
          f"C1' grinding budget.")
    return grans, per_pass_mb


# ===========================================================================
# Section C — option (b): exact per-chunk ranges at q31 (Ajtai-slot
# grounding at per-ring-element granularity).
# ===========================================================================

def section_c():
    hr("C. Option (b): exact per-chunk ranges at q31 (Ajtai grounding per "
       "ring element)")
    n_chunk, alpha = D, 3.0
    op = SLACK_CONC  # concentration op norm, as the prior session used
    t_s = op * 1.0 * math.sqrt(n_chunk)
    sigma_s = math.ceil(alpha * t_s)
    b_s = 1.2 * sigma_s * math.sqrt(n_chunk)
    two_b = 2.0 * b_s
    defect = two_b ** 2 + two_b * math.sqrt(n_chunk)
    print(f"  per-128-coeff chunk, alpha = {alpha:.0f}: T_s = {t_s:.1f}, "
          f"sigma_s = {sigma_s}, B = {b_s:.0f}")
    print(f"  (2B)^2 = 2^{log2(two_b ** 2):.2f}  "
          f"[prior session estimate 2^28.4 — VERIFIED]")
    assert abs(log2(two_b ** 2) - 28.4) < 0.1
    print(f"  per-chunk defect bound (2B)^2 + 2B sqrt(128) = "
          f"2^{log2(defect):.2f} < q31/2 = 2^{log2(Q31 / 2):.2f} "
          f"-> closes with {log2(Q31 / 2) - log2(defect):.2f} bits")
    print("""
  BUT the honest reading of this chain (Q4.4): the Ajtai opening's norm
  check grounds ||c-bar s*|| (the relaxed opening), not ||s*||; the same
  relaxed-opening composition debt as the ARP applies. And structurally,
  a per-chunk budget requires a per-chunk CLAIM: the whole-tensor sum
  of chunk defects is n_chunks x 2^28.4 >> q31/2, so the binary claim
  cannot stay one-per-tensor. Cost of per-ring-element quadratic
  ct-claims at LLM scale:""")
    bit_elements = ELEMENTS_PASS * (BILL_FACTOR - 1.0) / BILL_FACTOR
    chunks = bit_elements / D
    # per-chunk bytes: h_quad + Ga + Gb + G0 + W_quad (5 ring elements at
    # 31 bits) + per-chunk Ajtai s response (128 coeffs at ~log2(12
    # sigma_s) + 1 bits).
    zbits = math.ceil(log2(12 * sigma_s)) + 1
    b_chunk = 5 * D * 31 / 8.0 + D * zbits / 8.0
    gb_pass = chunks * b_chunk / 2 ** 30
    # per-chunk prover work: ~4 ring muls (Ga, Gb, G0, reveal combo).
    t_chunk_us = 4 * RING_MUL_US
    t_pass_1t = chunks * t_chunk_us * 1e-6
    print(f"\n  bit coefficients/pass: {bit_elements:.2e} "
          f"[anchor: {ELEMENTS_PASS:.1e} x {(BILL_FACTOR - 1) / BILL_FACTOR:.3f}] "
          f"-> {chunks:.2e} chunks")
    print(f"  proof bytes: {b_chunk:.0f} B/chunk -> {gb_pass:,.0f} GB/pass")
    print(f"  prover time: ~{t_chunk_us:.0f} us/chunk (~4 ring muls "
          f"[anchor {RING_MUL_US} us]) -> {t_pass_1t:,.0f} s 1T "
          f"= {t_pass_1t / 15 / 60:.0f} min 22T")
    lo, hi = CLAIMS_1T_S
    print(f"\n  vs the <20% Class-3 criterion (gadget family work vs the "
          f"matmul-claim layer,\n  {lo:.0f}-{hi:.0f} s 1T [anchor]): "
          f"{t_pass_1t / hi:.0f}x-{t_pass_1t / lo:.0f}x the claim layer = "
          f"{100 * t_pass_1t / hi:,.0f}%-{100 * t_pass_1t / lo:,.0f}% "
          f">> 20% -> REJECTED at FFN scale.")
    print("  (viable only for narrow interim tensors, demo class; and it "
          "still inherits Q4.4.)")
    return gb_pass, t_pass_1t


# ===========================================================================
# Section D — option (c): the tightened Q4 slack lemma.
# ===========================================================================

def section_d():
    hr("D. Option (c): how far SLACK_OP must drop for the q31 ARP budget "
       "to close")
    n, rows = 512, 256
    # Solve defect(b) = b^2 + b sqrt(n) = q31/2 for b.
    b_max = (-math.sqrt(n) + math.sqrt(n + 4 * (Q31 / 2.0))) / 2.0
    print(f"  q31 budget needs extract bound <= 2^{log2(b_max):.2f}")
    print("\n  | alpha | y_bound | unit extract (slack 1) | slack_max for "
          "q31 | M (restarts) |")
    print("  |---|---|---|---|---|")
    for alpha in (3.0, 2.0, 1.0):
        _, y_b, ex1 = arp_chain(n, rows, 1, alpha, 1.0)
        slack_max = b_max / ex1
        # ARP reveal restart factor at tail-cut t = 1.5 (the ct_engine
        # comment's discipline: alpha = 3 -> M ~ e^(1/2 + 1/18) ~ 1.75).
        m = math.exp(1.5 / alpha + 1.0 / (2 * alpha * alpha))
        print(f"  | {alpha:.0f} | {y_b:.0f} | 2^{log2(ex1):.2f} | "
              f"{slack_max:.2f} | {m:.2f} |")
    _, _, ex1_3 = arp_chain(n, rows, 1, 3.0, 1.0)
    slack_needed = b_max / ex1_3
    print(f"\n  at the coded alpha = 3: SLACK_OP must drop from "
          f"{SLACK_OP:.0f} to <= {slack_needed:.2f} "
          f"({SLACK_OP / slack_needed:.0f}x), i.e. BELOW even the "
          f"concentration operator norm {SLACK_CONC:.1f} "
          f"({SLACK_CONC / slack_needed:.1f}x past it).")
    print(f"""
  The only known argument class that could deliver a constant that small
  is the LNP22-style direct-witness composition (eprint 2022/284): the
  ct-round's message-side extraction is exact over R_q, the committed
  (b*, m*) are fixed by binding BEFORE the JL rows R are derived, and the
  mod-q anti-concentration form of the projection lemma bounds ||b*||
  DIRECTLY from the y range gate — no ||c-bar||_1 factor on the witness;
  effective slack ~2-class from the two-transcript mask relaxation. See
  Q4_LEMMAS.md Q4.4 for the precise statement and its UNPROVEN status.
  Even if proven at slack = 2, the q31 margin is only
  {log2(b_max) - log2(2 * ex1_3):.1f} bits at alpha = 3 — too thin to
  freeze a layer on. Verdict: research deletion-path, not a decision.""")


# ===========================================================================
# Section E — sensitivity: the bit-tensor share of the FFN commit bill and
# end-to-end option costs.
# ===========================================================================

def section_e(cpu_ratio, bytes_ratio, gpu_ratio, link_mb, link_s_22t,
              chunk_gb, chunk_s_1t):
    hr("E. Sensitivity: what each option costs end-to-end (7B/512 pass)")
    fb = (BILL_FACTOR - 1.0) / BILL_FACTOR
    print(f"  bill factor 1 + {BIT_COVERAGE:.0%} x {W_BITS} = "
          f"{BILL_FACTOR:.1f} [anchor] -> bit tensors are {fb:.1%} of the "
          f"{ELEMENTS_PASS:.1e} committed\n  element-equivalents — the bit "
          f"fraction is DOMINANT, not small (integration note).")
    cpu_mult = (1 - fb) + fb * cpu_ratio
    gpu_mult = (1 - fb) + fb * gpu_ratio
    c_lo, c_hi = COMMIT_22T_MIN
    g_lo, g_hi = COMMIT_GPU_S
    cl_lo, cl_hi = CLAIMS_22T_S
    print("\n  | option | commit 22T CPU | commit GPU | extra proof bytes "
          "| extra prover | verdict |")
    print("  |---|---|---|---|---|---|")
    print(f"  | (reference) all-q31, F3 OPEN | {c_lo:.1f}-{c_hi:.1f} min | "
          f"{g_lo:.0f}-{g_hi:.0f} s | — | — | UNSOUND (binary side "
          f"condition open) |")
    print(f"  | (a) q46 bits + link | {c_lo * cpu_mult:.1f}-"
          f"{c_hi * cpu_mult:.1f} min (x{cpu_mult:.2f}) | "
          f"{g_lo * gpu_mult:.0f}-{g_hi * gpu_mult:.0f} s (x{gpu_mult:.2f}) "
          f"| ~{link_mb:.0f} MB link (+{bytes_ratio:.2f}x bit commit "
          f"stream) | ~{link_s_22t:.1f} s 22T | SOUND TODAY (conservative "
          f"constants) |")
    print(f"  | (b) per-chunk q31 | {c_lo:.1f}-{c_hi:.1f} min | "
          f"{g_lo:.0f}-{g_hi:.0f} s | ~{chunk_gb:,.0f} GB | "
          f"~{chunk_s_1t / 60:.0f} min 1T | REJECTED at scale (Class-3 "
          f"blowout; inherits Q4.4) |")
    print(f"  | (c) tightened slack | {c_lo:.1f}-{c_hi:.1f} min | "
          f"{g_lo:.0f}-{g_hi:.0f} s | — | — | UNPROVEN (needs slack <= "
          f"~3.8; deletion path) |")
    tot_lo = g_lo * gpu_mult + cl_lo
    tot_hi = g_hi * gpu_mult + cl_hi
    print(f"\n  option (a) pass total (GPU commit + 22T claims + "
          f"noise-class gadgets):\n    ~{tot_lo:.0f}-{tot_hi:.0f} s vs the "
          f"15-30 s reconciliation band — the ~2-4x endpoint\n    band "
          f"stretches to ~{tot_lo / 7:.1f}-{tot_hi / 7:.1f}x CPU-int8 "
          f"(7 s baseline); CPU-only path nearly unchanged "
          f"(x{cpu_mult:.2f}).")
    print(f"""
  RECOMMENDATION: option (a) — q46-class budget for the gadget layer's
  binary claims with the modulus link, at x{cpu_mult:.2f} CPU commit,
  x{gpu_mult:.2f} GPU commit, ~{link_mb:.0f} MB/pass of link rows. It is
  the only option whose every budget closes under the constants the code
  enforces TODAY; the link machinery is shared with the trace gate's
  Q-A4 (one design item, two consumers); and option (c), if the Q4.4
  lemma is later proven at unit-slack class, deletes the q46 layer
  without any redesign of the claims themselves. Option (b) is rejected
  at FFN scale and kept for narrow tensors only.""")


def main():
    print("Gadget-layer modulus decision study (F3) — computed tables")
    print(f"moduli: q31 = {Q31} (2^31 - 399), q46 = {Q46} (2^46 - 1103); "
          f"d = {D}, quinary challenges")
    section_a()
    r31, r46, cpu_ratio, bytes_ratio, gpu_ratio = section_b1()
    grans, per_pass = section_b2()
    link_mb = per_pass["full FFN tensor 512x11008"][2]
    # link prover time from section B2's print: recompute for the summary.
    name, n_val, w, rows = grans[2]
    link_s_22t = (LINKED_TENSORS * rows * n_val * (W_BITS + 1)
                  / MACS_PER_SEC / 15.0)
    chunk_gb, chunk_s_1t = section_c()
    section_d()
    section_e(cpu_ratio, bytes_ratio, gpu_ratio, link_mb, link_s_22t,
              chunk_gb, chunk_s_1t)


if __name__ == "__main__":
    main()
