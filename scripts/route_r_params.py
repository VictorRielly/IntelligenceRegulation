#!/usr/bin/env python3
"""Route R (ring lift) parameter re-derivation.

Mirrors the C0-C4 iteration of the lattice report Section 11 /
derive_params_gadget in zkmatrix-rs/src/bin/lattice_matmul.rs, with the
Route Z scalar-challenge factors replaced by ring-challenge operator norms
over R_q = Z_q[X]/(X^d + 1), d = 128, coefficient embedding.

Substitutions (see docs/zkmatrix-poc/ROUTE_R_DESIGN.md Section 3):
  - repetitions r = 1 (challenge set C = quinary-coefficient ring elements,
    |C| = 5^128 = 2^297.2, replacing C1's r(b-2) >= 256).
  - challenge operator norm  op  replaces 2^b:
      worst case      op_wc = ||c||_1 <= 2d          (l1 * l2 bound)
      concentration   op_c  = 1.3 * sqrt(E[c_i^2] d) = 1.3 sqrt(2d)
    (E||c x||^2 = d E[c^2] ||x||^2 exactly for negacyclic convolution; the
    1.3 tail matches the report's 1.2 discipline with margin. Concentration
    bounds are legitimate for rejection-CENTER sizing -- the challenges are
    honest-verifier randomness -- with a restart-if-exceeded rule and a
    2^-64-class addition to the soundness error where extraction compares
    against combined honest openings; both uses are flagged in the doc.)
  - combining t commitments with independent ring challenges:
      worst case      B = t * op_wc * b0
      concentration   B = 1.3 * sqrt(2 d t) * b0
  - multiplication expansion: products of short elements bound by
    ||xy||_2 <= ||x||_1 ||y||_2 (worst case) / sqrt(d E[x^2]) ||y||_2 (conc).

The X^d+1 expansion factor is inside op; everything else is the report's
chain verbatim: sigma = 12 T, B = 1.2 sigma sqrt(dim), beta per protocol,
C2: q > 8 beta, C3: k_Z >= (log2 beta / 2)^2 / (log2 q * log2 delta0),
C4: N_Z >= k_Z + msg_Z + 768 log2 q / 11.7.
"""

import math

D = 128
LOG2_DELTA0 = 0.005326
E_C2 = 2.0  # E[c_i^2] for quinary coefficients {-2..2}
TAIL = 1.3


def op_norm(conc: bool) -> float:
    return TAIL * math.sqrt(E_C2 * D) if conc else 2.0 * D


def combine(t: int, b0: float, conc: bool) -> float:
    if conc:
        return TAIL * math.sqrt(E_C2 * D * t) * b0
    return t * 2.0 * D * b0


def derive(proto: str, rows: int, inner: int, cols: int, msg_min: int,
           log2_q: float, conc: bool):
    """One C0-C4 iteration at fixed log2 q. Returns dict or None (C2 fail)."""
    msg_r = max(1, math.ceil(max(rows, inner, msg_min) / D))
    msg_z = msg_r * D
    d_lwe = math.ceil(768.0 * log2_q / 11.7)
    k_z = 12 * D  # seed guess
    out = {}
    for _ in range(6):
        n_r = math.ceil((k_z + msg_z + d_lwe) / D)
        n_z = n_r * D
        b0 = math.sqrt(n_z)
        op = op_norm(conc)
        if proto == "pi1":
            b_rho = combine(cols, b0, conc)
            t_sq = 2.0 * (op * b_rho) ** 2
            dim = 2 * n_z
        else:  # pi2
            b_rho_s = combine(rows, b0, conc)
            b_rho_v = combine(cols, b0, conc)
            last = op * b0 + op * op * b_rho_v
            t_sq = op * op * (b_rho_s ** 2 + b_rho_v ** 2) + last * last
            dim = 3 * n_z
        sigma = 12.0 * math.sqrt(t_sq)
        bound = 1.2 * sigma * math.sqrt(dim)
        if proto == "pi1":
            beta = 2.0 * bound + op * b_rho
        else:
            beta = max(2.0 * bound + op * b_rho_s,
                       3.0 * op * bound + op ** 3 * b_rho_v)
        k_z = math.ceil((math.log2(beta) / 2.0) ** 2
                        / (log2_q * LOG2_DELTA0))
        out = dict(msg_r=msg_r, msg_z=msg_z, n_r=n_r, n_z=n_z,
                   kappa=math.ceil(k_z / D), k_z=k_z,
                   sigma=sigma, bound=bound, beta=beta, d_lwe=d_lwe)
    # C2 with >= 1 bit headroom; C0 ring analogue (LS18: q > 32) is trivial.
    if 2.0 ** log2_q <= 16.0 * out["beta"]:
        return None
    out["log2_q"] = log2_q
    return out


def minimal_q(proto, rows, inner, cols, msg_min, conc):
    for lq in [x / 2.0 for x in range(56, 125)]:  # 28.0 .. 62.0
        r = derive(proto, rows, inner, cols, msg_min, lq, conc)
        if r is not None:
            return r
    return None


def commit_col_kb(r, lq):
    return (r["kappa"] + r["msg_r"]) * D * lq / 8.0 / 1024.0


def proof_kb(proto, r, lq):
    sigma_bits = math.log2(r["sigma"]) + 4
    if proto == "pi1":
        bits = r["msg_z"] * lq + 2 * r["n_z"] * sigma_bits
    else:
        bits = (2 * r["msg_z"] * lq + 3 * r["n_z"] * sigma_bits
                + (r["kappa"] * D + D) * lq)
    return bits / 8.0 / 1024.0


def show(label, proto, rows, inner, cols, msg_min=0):
    print(f"\n### {label} ({proto}, {rows}x{inner}x{cols})")
    print("| norm model | min log2 q | kappa | N_r (N_Z) | msg_r | "
          "log2 sigma | log2 beta | commit/col KB | proof KB (r=1) |")
    print("|---|---|---|---|---|---|---|---|---|")
    for conc, name in [(False, "worst-case l1"), (True, "concentration")]:
        r = minimal_q(proto, rows, inner, cols, msg_min, conc)
        if r is None:
            print(f"| {name} | (none <= 2^62) | | | | | | | |")
            continue
        lq = r["log2_q"]
        print(f"| {name} | {lq:.1f} | {r['kappa']} | "
              f"{r['n_r']} ({r['n_z']}) | {r['msg_r']} | "
              f"{math.log2(r['sigma']):.1f} | {math.log2(r['beta']):.1f} | "
              f"{commit_col_kb(r, lq):.1f} | {proof_kb(proto, r, lq):.1f} |")
        # also at fixed q = 2^31-19 if feasible (prototype modulus)
        r31 = derive(proto, rows, inner, cols, msg_min, 31.0, conc)
        if r31 is not None:
            print(f"| {name} @ q=2^31 | 31.0 | {r31['kappa']} | "
                  f"{r31['n_r']} ({r31['n_z']}) | {r31['msg_r']} | "
                  f"{math.log2(r31['sigma']):.1f} | "
                  f"{math.log2(r31['beta']):.1f} | "
                  f"{commit_col_kb(r31, 31.0):.1f} | "
                  f"{proof_kb(proto, r31, 31.0):.1f} |")


def soundness_accounting():
    print("### Challenge-set soundness accounting (replaces C1)")
    for base, name in [(3, "ternary {-1,0,1}"), (5, "quinary {-2..2}")]:
        log_c = D * math.log2(base)
        eps = 1.0 - log_c  # log2(2/|C|)
        post_fs = 128.0 + eps  # log2((Q+1)^2 eps), Q = 2^64
        verdict = "PASS" if post_fs <= -128 else "FAIL"
        print(f"  {name}: |C| = {base}^{D} = 2^{log_c:.1f}; "
              f"knowledge error 2/|C| = 2^{eps:.1f}; "
              f"(Q+1)^2 eps = 2^{post_fs:.1f} vs target 2^-128 -> {verdict}")
    log_c = 256 * math.log2(3)
    print(f"  ternary at d=256 (fallback): |C| = 2^{log_c:.1f}; "
          f"post-FS 2^{128 + 1 - log_c:.1f} -> PASS")


if __name__ == "__main__":
    print("Route R parameter tables (d = 128, quinary challenges, r = 1)")
    soundness_accounting()
    # Demo chain shapes (M0/M1 report): X 16x32, W1 32x64, W2 64x8.
    show("demo chain worst shape", "pi2", 32, 32, 64, msg_min=64)
    # Square n = 2048, both protocols (the LLM-scale reference claim).
    show("n = 2048 square", "pi2", 2048, 2048, 2048)
    show("n = 2048 square", "pi1", 2048, 2048, 2048)
    # FFN-like rectangle at Llama-7B width (per-token-block claims).
    show("FFN block 512x4096x11008", "pi2", 512, 4096, 11008)
