#!/usr/bin/env python3
"""M4 SiLU activation: piecewise fixed-point reference + error harness.

SiLU(x) = x * sigmoid(x) (Llama's FFN gate activation) as a DECLARED
piecewise degree-<=2 fixed-point function, compiled to the Route R
gadget set in docs/zkmatrix-poc/M4_ACTIVATION_DESIGN.md. This script is
the single source for every number quoted there:

  [1] the segment-table GENERATOR (float fitting is allowed here; the
      emitted table is frozen and digest-pinned by the statement);
  [2] the EXACT integer evaluator — the certified path: no floats, all
      intermediate widths asserted against the declared formats and the
      q31/q46 claim-headroom and link w_max rules;
  [3] a GADGET TRACE that materializes every witness the claim DAG
      commits (indicator planes, u bits, Horner intermediates, output
      rescale) and asserts every claim relation as exact integers —
      completeness by enumeration over the full input grid;
  [4] the ERROR HARNESS: exhaustive on-grid error vs float SiLU, ulp
      comparison vs the ideal int8-quantized SiLU baseline, and
      sampled pipeline error on uniform + Gaussian-shaped activations;
  [5] the COST MODEL: committed element-equivalents per activation
      element and the 7B/512 pass-level commit-bill delta.

Anchors imported from the measured docs (marked [anchor]):
  LLM_SCALE_ESTIMATE.md   9.4e9 committed element-equivalents/pass,
                          commit 1.6-2.0 min 22T / 5-6 s GPU (A1),
                          claim layer 110-330 s 1T, 4.6e9 MACs/s 1T
  GADGET_MODULUS_DECISION 19.9 KB/col q31, 27.3 KB/col q46 (4096-coeff
                          columns), GPU int8-GEMM factor x2.26 on q46,
                          link row ~2519 B, w_max rule vs q46/2
  ring_matmul.rs U6a      H3 slot packing: 8 values/ring element
                          (dense packing: 128 coefficients/element)

Run from the repo root:  python3 scripts/silu_piecewise.py
Deterministic (fixed seed); pure stdlib; ~10 s.
"""

import hashlib
import json
import math
import random

# ---------------------------------------------------------------------------
# Moduli and gadget-layer constants (mirror ring/mod.rs + the decision doc).
# ---------------------------------------------------------------------------
Q31 = 2**31 - 399            # value-chain modulus q8_31
Q46 = 2**46 - 1103           # gadget-layer modulus q8_46
D = 128                      # ring degree
SLOTS = 8                    # H3 slot packing: values per ring element
SLOT_PENALTY = D // (SLOTS)  # 16 dense-coefficient-equivalents per slot value
ARP_UNIT = 512               # binary-claim granularity cap (freeze row)
LINK_TARGET_BITS = 256       # soundness target for link rows: w*l >= 256
LINK_ROW_BYTES = 2519        # [anchor] decision doc Section 3.4

# 7B/512 reference pass [anchor]
PASS_ELEMENT_EQUIV = 9.4e9   # committed element-equivalents, bill factor 5.8
FFN_T, FFN_F, LAYERS = 512, 11008, 32
N_ACT = FFN_T * FFN_F * LAYERS          # SiLU'd elements per pass
N_TENSOR = FFN_T * FFN_F                # elements per FFN gate tensor
COMMIT_22T_S = (96.0, 120.0)            # [anchor] 1.6-2.0 min per pass
COMMIT_GPU_S = (5.0, 6.0)               # [anchor] q31-class GPU commit row
GPU_Q46_FACTOR = 2.26                   # [anchor] (46/30)^2-class int8 cost
CLAIMS_1T_S = (110.0, 330.0)            # [anchor] matmul-claim layer, 1T
MACS_PER_SEC_1T = 4.6e9                 # [anchor]
BYTES_PER_COEFF_Q31 = 19.9 * 1024 / 4096   # commit stream, dense column
BYTES_PER_COEFF_Q46 = 27.3 * 1024 / 4096


def silu(x):
    """Float reference (measurement side only, never the certified path)."""
    if x >= 0:
        return x / (1.0 + math.exp(-x))
    e = math.exp(x)
    return x * e / (1.0 + e)


# ---------------------------------------------------------------------------
# [1] Segment-table generator.
#
# Declared formats: input x_int, W_in-bit signed, real value x_int*2^-F_in;
# output y_int, W_out-bit signed, real value y_int*2^-F_out. Shifted domain
# tau = x_int + 2^(W_in-1) in [0, 2^W_in); K = 2^(W_in - wseg) uniform
# segments of h = 2^wseg grid units; local variable u = tau - j*h.
# Per segment j the integer coefficients (A_j, B_j, C_j) define
#     y_raw = A_j + B_j*u + C_j*u^2        (scale 2^-(F_in + Pe))
# and the output is the declared rounding
#     y_int = floor((y_raw + 2^(Pe + F_in - F_out - 1)) / 2^(Pe+F_in-F_out)).
# ---------------------------------------------------------------------------

def _lstsq(us, ts, degree):
    """Least squares fit of ts ~ poly(us) via normal equations (pure float)."""
    n = degree + 1
    ata = [[sum(u ** (i + j) for u in us) for j in range(n)] for i in range(n)]
    atb = [sum(t * u**i for u, t in zip(us, ts)) for i in range(n)]
    # Gaussian elimination with partial pivoting.
    for col in range(n):
        piv = max(range(col, n), key=lambda r: abs(ata[r][col]))
        ata[col], ata[piv] = ata[piv], ata[col]
        atb[col], atb[piv] = atb[piv], atb[col]
        for r in range(col + 1, n):
            f = ata[r][col] / ata[col][col]
            for c in range(col, n):
                ata[r][c] -= f * ata[col][c]
            atb[r] -= f * atb[col]
    out = [0.0] * n
    for r in range(n - 1, -1, -1):
        s = atb[r] - sum(ata[r][c] * out[c] for c in range(r + 1, n))
        out[r] = s / ata[r][r]
    return out


def gen_table(w_in, f_in, k_seg, degree, pe):
    """Fit + round the per-segment integer coefficients.

    Sequential rounding refinement: round the highest coefficient, refit
    the rest against the residual, repeat — keeps the rounding error of
    high-order terms out of the max error.
    """
    assert k_seg & (k_seg - 1) == 0 and k_seg <= 2**w_in
    wseg = w_in - int(round(math.log2(k_seg)))
    h = 1 << wseg
    scale = 1 << (f_in + pe)
    table = []
    for j in range(k_seg):
        us = list(range(h))
        ts = [silu((j * h + u - 2 ** (w_in - 1)) / (1 << f_in)) * scale
              for u in us]
        coeffs_int = [0] * (degree + 1)
        resid = ts[:]
        for d in range(degree, 0, -1):
            c = _lstsq(us, resid, d)
            coeffs_int[d] = round(c[d])
            resid = [r - coeffs_int[d] * u**d for u, r in zip(us, resid)]
        coeffs_int[0] = round(sum(resid) / len(resid))
        table.append(tuple(coeffs_int))
    return table, wseg


def spec_digest(params, table):
    """Canonical JSON of the declared function -> SHA-256 (statement pin)."""
    doc = {
        "function": "silu-piecewise-fixedpoint-v1",
        "input": {"width": params["w_in"], "frac_bits": params["f_in"],
                  "signed": True},
        "output": {"width": params["w_out"], "frac_bits": params["f_out"],
                   "signed": True},
        "segments": params["k_seg"], "seg_shift": params["wseg"],
        "degree": params["degree"], "pe": params["pe"],
        "rounding": "y=floor((y_raw+2^(s-1))/2^s), s=pe+f_in-f_out",
        "table": [list(row) for row in table],
    }
    blob = json.dumps(doc, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(blob).hexdigest()


# ---------------------------------------------------------------------------
# [2] Exact integer evaluator (the certified path — integers only).
# ---------------------------------------------------------------------------

def eval_fx(x_int, table, p):
    """Declared function: W_in-bit signed int -> W_out-bit signed int."""
    w_in, f_in, f_out, pe = p["w_in"], p["f_in"], p["f_out"], p["pe"]
    assert -(2 ** (w_in - 1)) <= x_int < 2 ** (w_in - 1)
    tau = x_int + 2 ** (w_in - 1)
    j = tau >> p["wseg"]
    u = tau - (j << p["wseg"])
    coeffs = table[j]
    y_raw = sum(c * u**d for d, c in enumerate(coeffs))     # scale 2^-(f_in+pe)
    s = pe + f_in - f_out
    y_int = (y_raw + (1 << (s - 1))) >> s                   # declared rounding
    assert -(2 ** (p["w_out"] - 1)) <= y_int < 2 ** (p["w_out"] - 1), \
        f"output overflow at x={x_int}: {y_int}"
    return y_int


# ---------------------------------------------------------------------------
# [3] Gadget trace: every committed witness + every claim relation, asserted
# as exact integers. This mirrors the claim DAG of M4_ACTIVATION_DESIGN.md
# Section 4 one-to-one; running it over the whole grid is the completeness
# check for the composed chain (and the model for the spec compiler's
# differential tests).
# ---------------------------------------------------------------------------

def gadget_trace(x_int, table, p):
    w_in, f_in, f_out, pe = p["w_in"], p["f_in"], p["f_out"], p["pe"]
    k_seg, wseg, degree = p["k_seg"], p["wseg"], p["degree"]
    h = 1 << wseg
    half = 2 ** (w_in - 1)

    # Chain-native input planes (x is range-proved upstream): offset code.
    tau = x_int + half
    x_bits = [(tau >> i) & 1 for i in range(w_in)]

    # Placement witnesses: indicator planes e_j and remainder bits.
    j = tau >> wseg
    u = tau - (j << wseg)
    e = [1 if jj == j else 0 for jj in range(k_seg)]
    u_bits = [(u >> i) & 1 for i in range(wseg)]

    # Claim P-bin: all planes binary (b*(b-1) == 0 per coefficient).
    for b in e + u_bits + x_bits:
        assert b * (b - 1) == 0
    # Claim P-one: sum_j e_j = 1  (RingClaim at q46, per coefficient).
    assert sum(e) == 1
    # Claim P-place: recomp(x planes) - h * sum_j j*e_j - recomp(u planes) = 0
    # (RingClaim at q46 over existing + new planes; no wrap: < 2^(w_in+1)).
    lhs = sum(2**i * bi for i, bi in enumerate(x_bits)) \
        - h * sum(jj * ej for jj, ej in enumerate(e)) \
        - sum(2**i * bi for i, bi in enumerate(u_bits))
    assert lhs == 0 and 2 ** (w_in + 1) < Q46 // 2

    # Links L_A/L_B/L_C: selected coefficients (slot-packed q31 targets,
    # grounded on the e planes with signed weight maps).
    sel = [sum(table[jj][d] * e[jj] for jj in range(k_seg))
           for d in range(degree + 1)]
    # Link L_u: u_s slot target grounded on the u planes (2^i map).
    u_slot = sum(2**i * bi for i, bi in enumerate(u_bits))
    assert u_slot == u

    # Horner claims (QuadRingClaim per slot, q31): degree 2 ->
    #   H1: w1 = C_sel o u_s + B_sel ;  H2: y_raw = w1 o u_s + A_sel.
    if degree == 2:
        w1 = sel[2] * u_slot + sel[1]
        y_raw = w1 * u_slot + sel[0]
        assert abs(w1) < Q31 // 2 and abs(sel[2] * u_slot) < Q31 // 2
    else:
        w1 = None
        y_raw = sel[1] * u_slot + sel[0]
    assert abs(y_raw) < Q31 // 2, "q31 claim headroom"
    assert y_raw == sum(c * u**d for d, c in enumerate(table[j]))

    # Output rescale (link-grounded): y_raw + 2^(s-1) = 2^s*y_out + r_out
    # with r_out in [0, 2^s) proven by its planes; y_out by the chain's
    # own output planes (offset code for the signed value).
    s = pe + f_in - f_out
    y_int = (y_raw + (1 << (s - 1))) >> s
    r_out = y_raw + (1 << (s - 1)) - (y_int << s)
    assert 0 <= r_out < (1 << s)
    r_bits = [(r_out >> i) & 1 for i in range(s)]
    y_code = y_int + 2 ** (p["w_out"] - 1)          # offset code, in [0, 2^W)
    y_bits = [(y_code >> i) & 1 for i in range(p["w_out"])]
    assert sum(2**i * b for i, b in enumerate(r_bits)) == r_out
    assert sum(2**i * b for i, b in enumerate(y_bits)) == y_code
    # Link L_out functional: y_raw + 2^(s-1) + 2^s*2^(w_out-1)
    #                        = 2^s * y_code + r_out  (all grounded integers).
    assert y_raw + (1 << (s - 1)) + (1 << s) * 2 ** (p["w_out"] - 1) \
        == (1 << s) * y_code + r_out
    return y_int


def check_link_wmax(p, table, n_values):
    """The w_max rule (decision doc 3.3) for every link the design uses:
    n * 2^(w-1) * max|map value| < q46/2; returns {link: (w, rows)}."""
    s = p["pe"] + p["f_in"] - p["f_out"]
    links = {
        "L_u   (u planes -> u_s)": (1 << p["wseg"]) - 1,
        "L_A   (e planes -> A_sel)": max(abs(t[0]) for t in table),
        "L_B   (e planes -> B_sel)": max(abs(t[1]) for t in table),
        "L_out (y/r planes -> y_raw)": (1 << (s + p["w_out"])) - 1,
    }
    if p["degree"] == 2:
        links["L_C   (e planes -> C_sel)"] = max(abs(t[2]) for t in table) or 1
    out = {}
    for name, max_map in links.items():
        w = int(math.floor(math.log2(Q46 / 2 / (n_values * max_map)))) + 1 - 1
        while n_values * 2 ** (w - 1) * max_map >= Q46 // 2:
            w -= 1
        assert w >= 4, f"{name}: w={w} too small at n={n_values}"
        out[name] = (w, math.ceil(LINK_TARGET_BITS / w))
    return out


# ---------------------------------------------------------------------------
# [4] Error harness.
# ---------------------------------------------------------------------------

def grid_errors(table, p):
    """Exhaustive over the input grid: approximation error (y_raw, before
    output rounding) and declared total error vs float SiLU; ulp deltas vs
    the ideal quantized-SiLU baseline round(silu(x)*2^F_out)."""
    w_in, f_in, f_out, pe = p["w_in"], p["f_in"], p["f_out"], p["pe"]
    s_in, s_out, s_raw = 2.0**-f_in, 2.0**-f_out, 2.0 ** -(f_in + pe)
    approx_max = approx_sum = tot_max = tot_sum = 0.0
    ulp_max, mismatches = 0, 0
    n = 2**w_in
    for x_int in range(-(n // 2), n // 2):
        ref = silu(x_int * s_in)
        tau = x_int + n // 2
        j, u = tau >> p["wseg"], tau & ((1 << p["wseg"]) - 1)
        y_raw = sum(c * u**d for d, c in enumerate(table[j]))
        y_int = eval_fx(x_int, table, p)
        ideal = math.floor(ref / s_out + 0.5)
        ideal = max(-(n // 2), min(n // 2 - 1, ideal))  # saturating baseline
        ea, et = abs(y_raw * s_raw - ref), abs(y_int * s_out - ref)
        approx_max, tot_max = max(approx_max, ea), max(tot_max, et)
        approx_sum, tot_sum = approx_sum + ea, tot_sum + et
        ulp = abs(y_int - ideal)
        ulp_max = max(ulp_max, ulp)
        mismatches += 1 if ulp else 0
    return {"approx_max": approx_max, "approx_mean": approx_sum / n,
            "tot_max": tot_max, "tot_mean": tot_sum / n,
            "ulp_max": ulp_max, "mismatch": mismatches, "n": n}


def sampled_errors(table, p, dists, n_samples=100_000, seed=1):
    """Full-pipeline error on real-valued activations w: quantize to the
    input grid, apply the declared function, compare vs float silu(w).
    Baseline column: ideal int8 SiLU on the same quantized input — the
    error floor any quantized activation pays."""
    rng = random.Random(seed)
    w_in, f_in, f_out = p["w_in"], p["f_in"], p["f_out"]
    lo, hi = -(2 ** (w_in - 1)), 2 ** (w_in - 1) - 1
    s_in, s_out = 2.0**-f_in, 2.0**-f_out
    rows = []
    for name in dists:
        pipe_max = pipe_sum = base_max = base_sum = 0.0
        for _ in range(n_samples):
            if name == "uniform[-8,8)":
                w = rng.uniform(lo * s_in, (hi + 1) * s_in)
            else:
                sigma = float(name.split("=")[1].rstrip(")"))
                w = rng.gauss(0.0, sigma)
            x_int = max(lo, min(hi, math.floor(w / s_in + 0.5)))
            ref = silu(w)
            ep = abs(eval_fx(x_int, table, p) * s_out - ref)
            ideal = max(lo, min(hi, math.floor(silu(x_int * s_in) / s_out + 0.5)))
            eb = abs(ideal * s_out - ref)
            pipe_max, pipe_sum = max(pipe_max, ep), pipe_sum + ep
            base_max, base_sum = max(base_max, eb), base_sum + eb
        rows.append((name, pipe_max, pipe_sum / n_samples,
                     base_max, base_sum / n_samples))
    return rows


# ---------------------------------------------------------------------------
# [5] Cost model: committed element-equivalents (dce = dense q31-coefficient
# equivalents; one slot-packed value = 16 dce) and the pass-level bill.
# ---------------------------------------------------------------------------

def cost_variant_a(p):
    """Piecewise deg-d: slot tensors u_s, sel[0..d], w1..w_{d-1}, y_raw
    = 2d+2; new q46 planes: K indicators + wseg u-bits + s r_out-bits.
    (y_out planes are chain-native: the downstream gate o up product
    range-needs them under ANY activation.)"""
    d = p["degree"]
    slot_tensors = 2 * d + 2
    s = p["pe"] + p["f_in"] - p["f_out"]
    planes = p["k_seg"] + p["wseg"] + s
    return {"slot_tensors": slot_tensors, "planes": planes,
            "dce_q31_slot": SLOT_PENALTY * slot_tensors, "dce_q46": planes,
            "dce": SLOT_PENALTY * slot_tensors + planes}


def cost_variant_b(p):
    """Exact one-hot table: 2^W_in indicator planes, one dense-target link,
    zero slot tensors, zero approximation error."""
    planes = 2 ** p["w_in"]
    return {"slot_tensors": 0, "planes": planes,
            "dce_q31_slot": 0, "dce_q46": planes, "dce": planes}


def pass_costs(cost, label):
    dce = cost["dce"]
    marginal = dce * N_ACT
    pct = 100.0 * marginal / PASS_ELEMENT_EQUIV
    cpu = [marginal / PASS_ELEMENT_EQUIV * t for t in COMMIT_22T_S]
    gpu_rate = [t / PASS_ELEMENT_EQUIV for t in COMMIT_GPU_S]
    gpu = [(cost["dce_q31_slot"] + GPU_Q46_FACTOR * cost["dce_q46"])
           * N_ACT * r for r in gpu_rate]
    stream = (cost["dce_q31_slot"] * BYTES_PER_COEFF_Q31
              + cost["dce_q46"] * BYTES_PER_COEFF_Q46) * N_ACT / 1e9
    arp_macs = cost["dce_q46"] * N_ACT * 256          # JL rows per bit-coeff
    arp_s_1t = arp_macs / MACS_PER_SEC_1T
    return {"label": label, "dce": dce, "marginal": marginal, "pct": pct,
            "cpu_s": cpu, "gpu_s": gpu, "stream_gb": stream,
            "arp_s_1t": arp_s_1t}


# ---------------------------------------------------------------------------
# Driver.
# ---------------------------------------------------------------------------

def make_params(w_in, f_in, w_out, f_out, k_seg, degree, pe):
    p = {"w_in": w_in, "f_in": f_in, "w_out": w_out, "f_out": f_out,
         "k_seg": k_seg, "degree": degree, "pe": pe}
    table, wseg = gen_table(w_in, f_in, k_seg, degree, pe)
    p["wseg"] = wseg
    return p, table


def run_config(w_in, f_in, w_out, f_out, k_seg, degree, pe):
    p, table = make_params(w_in, f_in, w_out, f_out, k_seg, degree, pe)
    g = grid_errors(table, p)
    c = cost_variant_a(p)
    return p, table, g, c


def main():
    print("M4 SiLU piecewise fixed-point harness (scripts/silu_piecewise.py)")
    print(f"moduli: q31 = 2^31-399, q46 = 2^46-1103; slot penalty x{SLOT_PENALTY}")

    # -- Sweep: int8 spec (W_in=8/F_in=4 -> W_out=8/F_out=4). ---------------
    w_in, f_in, w_out, f_out = 8, 4, 8, 4
    half_ulp_out = 2.0 ** -(f_out + 1)
    print(f"\n[sweep] int8 spec: x Q{w_in - f_in - 1}.{f_in} in [-8,8) -> "
          f"y Q{w_out - f_out - 1}.{f_out}; out half-ulp {half_ulp_out:.5f}")
    print("  rule: approx_max <= out half-ulp / 2 = "
          f"{half_ulp_out / 2:.6f} AND ulp_max <= 1")
    hdr = (f"  {'K':>3} {'deg':>3} {'Pe':>3} | {'approx_max':>10} "
           f"{'approx_mean':>11} {'tot_max':>8} {'ulp_max':>7} "
           f"{'mismatch':>8} | {'dce/el':>6} {'rule':>4}")
    print(hdr)
    best = None
    for k_seg in (4, 8, 16, 32):
        for degree in (1, 2):
            for pe in (6, 8, 10):
                p, table, g, c = run_config(w_in, f_in, w_out, f_out,
                                            k_seg, degree, pe)
                ok = (g["approx_max"] <= half_ulp_out / 2
                      and g["ulp_max"] <= 1)
                print(f"  {k_seg:>3} {degree:>3} {pe:>3} | "
                      f"{g['approx_max']:>10.6f} {g['approx_mean']:>11.6f} "
                      f"{g['tot_max']:>8.5f} {g['ulp_max']:>7d} "
                      f"{g['mismatch']:>5d}/{g['n']:<3d}| "
                      f"{c['dce']:>6d} {'PASS' if ok else '--':>4}")
                if ok and (best is None or c["dce"] < best[3]["dce"]):
                    best = (p, table, g, c)
    assert best, "no config passed the error rule"
    p, table, g, c = best

    # -- Recommended operating point, in detail. ----------------------------
    print(f"\n[recommended] K={p['k_seg']} deg={p['degree']} Pe={p['pe']} "
          f"(wseg={p['wseg']}, h={1 << p['wseg']} grid units "
          f"= {(1 << p['wseg']) * 2.0**-p['f_in']:.2f} real)")
    print(f"  spec digest (sha256 of canonical table JSON): "
          f"{spec_digest(p, table)}")
    print("  segment table (A,B,C at scale 2^-(F_in+Pe) per u, u in grid units):")
    for j, row in enumerate(table):
        lo = (j * (1 << p["wseg"]) - 2 ** (p["w_in"] - 1)) * 2.0**-p["f_in"]
        hi = lo + (1 << p["wseg"]) * 2.0**-p["f_in"]
        print(f"    seg {j:>2} x in [{lo:>6.2f},{hi:>6.2f}): "
              + " ".join(f"{c:>7d}" for c in row))

    # Completeness by enumeration: gadget trace on every grid input.
    n = 2 ** p["w_in"]
    for x_int in range(-(n // 2), n // 2):
        assert gadget_trace(x_int, table, p) == eval_fx(x_int, table, p)
    print(f"  gadget trace: all {n} inputs satisfy every claim relation "
          "(placement, binary, links, Horner, rescale) exactly")

    wmax = check_link_wmax(p, table, N_TENSOR)
    print(f"  link w_max at full-tensor granularity (n = {N_TENSOR}):")
    for name, (w, rows) in sorted(wmax.items()):
        print(f"    {name:<28} w = {w:>2}, rows = {rows}")

    dists = ["uniform[-8,8)", "gauss(s=0.5)", "gauss(s=1)", "gauss(s=2)",
             "gauss(s=4)"]
    print("  sampled pipeline error vs float SiLU (declared | ideal-int8"
          " baseline):")
    for name, pm, pmean, bm, bmean in sampled_errors(table, p, dists):
        print(f"    {name:<14} max {pm:.5f} mean {pmean:.6f} | "
              f"baseline max {bm:.5f} mean {bmean:.6f}")

    # -- Secondary 12-bit spec row. ------------------------------------------
    print("\n[12-bit spec] x Q3.8 -> y Q3.8 (higher-fidelity mode):")
    for k_seg in (16, 32, 64):
        p2, t2, g2, c2 = run_config(12, 8, 12, 8, k_seg, 2, 10)
        print(f"  K={k_seg:>3} deg=2 Pe=10 | approx_max {g2['approx_max']:.6f}"
              f" tot_max {g2['tot_max']:.6f} ulp_max {g2['ulp_max']}"
              f" mismatch {g2['mismatch']}/{g2['n']} | dce/el {c2['dce']}")

    # -- Cost model. ---------------------------------------------------------
    print(f"\n[cost] 7B/512 pass: {N_ACT / 1e6:.0f}M SiLU'd elements "
          f"({LAYERS} gate tensors of {FFN_T}x{FFN_F}); "
          f"pass baseline {PASS_ELEMENT_EQUIV:.1e} element-equivalents")
    p_deg2, _, _, c_deg2 = run_config(p["w_in"], p["f_in"], p["w_out"],
                                      p["f_out"], 16, 2, 8)
    variants = [
        (cost_variant_a(p),
         f"A: piecewise K={p['k_seg']} deg={p['degree']} (rec)"),
        (c_deg2, f"A2: piecewise K={p_deg2['k_seg']} deg=2 Pe=8"),
        (cost_variant_b(p), "B: exact one-hot table (2^8)"),
    ]
    print(f"  {'variant':<28} {'dce/el':>6} {'slotT':>5} {'planes':>6} "
          f"{'+pass %':>8} {'commit 22T s':>13} {'GPU s':>11} "
          f"{'stream GB':>9} {'ARP 1T s':>8}")
    for cost, label in variants:
        r = pass_costs(cost, label)
        print(f"  {label:<28} {r['dce']:>6d} {cost['slot_tensors']:>5d} "
              f"{cost['planes']:>6d} {r['pct']:>+7.0f}% "
              f"{r['cpu_s'][0]:>5.0f}-{r['cpu_s'][1]:<6.0f} "
              f"{r['gpu_s'][0]:>4.1f}-{r['gpu_s'][1]:<5.1f} "
              f"{r['stream_gb']:>9.0f} {r['arp_s_1t']:>8.0f}")
    ra = pass_costs(cost_variant_a(p), "")
    print(f"  reference: matmul-claim layer {CLAIMS_1T_S[0]:.0f}-"
          f"{CLAIMS_1T_S[1]:.0f} s 1T; Class-3 criterion is <20% of it.")
    print(f"  variant A marginal commit alone = {ra['cpu_s'][0]:.0f}-"
          f"{ra['cpu_s'][1]:.0f} s 22T on top of {COMMIT_22T_S[0]:.0f}-"
          f"{COMMIT_22T_S[1]:.0f} s — the piecewise route costs "
          f"{ra['pct']:.0f}% of today's whole commit bill.")


if __name__ == "__main__":
    main()
