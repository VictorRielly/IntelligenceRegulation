#!/usr/bin/env python3
"""Q5 estimator sign-off run (companion: docs/zkmatrix-poc/ESTIMATOR_NOTE.md).

Validates the C3 (MSIS binding) / C4 (MLWE hiding) DESIGN MODELS of the
frozen Route R parameter point against real lattice cryptanalysis
estimates. Two independent sources of numbers; every figure emitted by
this script carries its source tag:

  [core-SVP]           the self-contained model implemented in this file:
                       BKZ block size b via the Chen root-Hermite
                       asymptotic delta(b), attack cost 2^(0.292 b)
                       classical / 2^(0.257 b) quantum (sieving).
  [lattice-estimator]  github.com/malb/lattice-estimator executed
                       IN-PROCESS under the minimal pure-Python sage.all
                       shim defined below (float arithmetic + mpmath
                       special functions). The estimator's algorithm code
                       is UNMODIFIED; the shim is validated against the
                       estimator's own published doctest values before a
                       single instance number is trusted. If the import,
                       the shim validation, or any call fails, the failure
                       is logged honestly and the run continues -- the
                       core-SVP tables never depend on it.

Frozen instances (ring_matmul.rs freeze_check + ring_lattice.rs constants):
  Pi2 2048^3        e=2  kappa 8, N_r 40, msg_r 16   (digit chain, conc)
  Pi2 2048^3        e=3  kappa 8, N_r 40, msg_r 16
  Pi2 2048^3        e=4  kappa 9, N_r 40, msg_r 16   (the default e)
  FFN 512x4096x11008 e=4 kappa 9, N_r 57, msg_r 32
  prototype opening      kappa 8, N_r 26, msg_r 2    (plain chain, worst l1)
at q8_31 = 2147483249 (frozen) and q8_46 = 70368744176561 (fallback; the
chain re-derives its own kappa/N_r there -- those rows are labeled
"chain-derived", they are candidates, not frozen values).

Dimension conventions (ROUTE_R_DESIGN.md Section 3):
  MSIS binding: rank kappa over R_q -> Z-dimension k_Z = kappa*128, witness
  width N_Z = N_r*128, l2 length bound beta (the chain's beta IS an l2
  bound -- see the note for the linf-vs-l2 discussion).
  MLWE hiding (knapsack/normal form): secret dimension
  n = N_Z - (kappa + msg_r)*128, samples m = (kappa + msg_r)*128, ternary
  secret and error (uniform {-1,0,1}, stddev sqrt(2/3)).

Outputs:
  results/estimator_core_svp.txt           [core-SVP] tables + sweeps
  results/estimator_lattice_estimator.txt  [lattice-estimator] run log

Usage (repo root):  python3 scripts/estimator_run.py [--skip-lattice-estimator]
"""

import math
import os
import sys
import time
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
RESULTS = os.path.join(ROOT, "results")
TOOLS_LE = os.path.join(ROOT, "tools", "lattice-estimator")

sys.path.insert(0, HERE)
import route_r_params as rp  # the reference derive chains (read-only import)

D = 128
Q31 = 2147483249        # q8_31 = 2^31 - 399   (frozen modulus)
Q46 = 70368744176561    # q8_46 = 2^46 - 1103  (fallback modulus)
LOG2_DELTA0 = rp.LOG2_DELTA0  # 0.005326: the C3 design-model root-Hermite
CLASSICAL = 0.292
QUANTUM = 0.257
TARGET = 128.0

# ---------------------------------------------------------------------------
# Frozen shapes. msg_r follows the chain: ceil(max(rows, inner, msg_min)/D).
# For the digit shapes the frozen (kappa, N_r) below are asserted against
# rp.derive_q2 at q31 before anything else runs (lockstep with freeze_check).

DIGIT_SHAPES = [
    # label,                rows, inner, cols,  e, frozen kappa, frozen N_r
    ("Pi2 2048^3 e=2",      2048, 2048, 2048,   2, 8, 40),
    ("Pi2 2048^3 e=3",      2048, 2048, 2048,   3, 8, 40),
    ("Pi2 2048^3 e=4",      2048, 2048, 2048,   4, 9, 40),
    ("FFN 512x4096x11008 e=4", 512, 4096, 11008, 4, 9, 57),
]
PROTO = ("prototype opening", 8, 26, 2)  # kappa, N_r, msg_r (plain chain)


# ---------------------------------------------------------------------------
# Chain reconstruction (single forward pass at a GIVEN N_r) -- needed for the
# sweep, where kappa/N_r are moved by hand. Pinned to rp.derive_q2 /
# ring_lattice.rs derive_sigma_params by the self-check below.

def digit_chain_at(rows, inner, cols, e, n_r, conc=True):
    """(sigma, beta, l_dig, msg_r) of the digit chain at fixed N_r."""
    t = max(rows, cols)
    w_u = rp.witness_coeff_bound(t, conc)
    l_dig = math.ceil((math.log2(w_u) + 1.0) / e)
    msg_r = max(1, math.ceil(max(rows, inner) / D))
    n_z = n_r * D
    op = rp.op_norm(conc)
    half = 2.0 ** (e - 1)
    t_bundle = op * half * math.sqrt(l_dig * n_z)
    sigma = 12.0 * t_bundle
    bound = 1.2 * sigma * math.sqrt(l_dig * n_z)
    beta = max(2.0 * bound + op * half * math.sqrt(n_z),
               op * w_u * math.sqrt(n_z))
    return sigma, beta, l_dig, msg_r


def proto_chain_at(n_r):
    """(sigma, beta) of the prototype plain worst-case-l1 opening chain
    (ring_lattice.rs derive_sigma_params) at fixed N_r; t = 1 (single
    commitment, no combination)."""
    n_z = n_r * D
    b0 = math.sqrt(n_z)
    t1 = 2.0 * D * b0
    sigma = 12.0 * t1
    bound = 1.2 * sigma * math.sqrt(n_z)
    beta = 2.0 * bound + 4.0 * D * b0
    return sigma, beta


def proto_derive(q):
    """Fixed-point iteration of the prototype chain (mirrors derive())."""
    lq = math.log2(q)
    msg_r, msg_z = 2, 256
    d_lwe = math.ceil(768.0 * lq / 11.7)
    k_z = 8 * D
    for _ in range(6):
        n_r = math.ceil((k_z + msg_z + d_lwe) / D)
        sigma, beta = proto_chain_at(n_r)
        k_z = math.ceil((math.log2(beta) / 2.0) ** 2 / (lq * LOG2_DELTA0))
    return dict(kappa=math.ceil(k_z / D), k_z=k_z, n_r=n_r, msg_r=msg_r,
                sigma=sigma, beta=beta, d_lwe=d_lwe)


def self_check():
    """Pin this file's forward passes to the reference implementations."""
    for label, rows, inner, cols, e, kap, n_r in DIGIT_SHAPES:
        r = rp.derive_q2("pi2", rows, inner, cols, 0, math.log2(Q31), True, e)
        assert (r["kappa"], r["n_r"]) == (kap, n_r), \
            f"freeze drift at {label}: chain gives ({r['kappa']}, {r['n_r']})"
        sigma, beta, l_dig, msg_r = digit_chain_at(rows, inner, cols, e, n_r)
        assert abs(beta / r["beta"] - 1) < 1e-9 and l_dig == r["l_dig"] \
            and msg_r == r["msg_r"], f"forward-pass drift at {label}"
    p = proto_derive(Q31)
    assert (p["kappa"], p["n_r"]) == (PROTO[1], PROTO[2]), \
        f"prototype drift: chain gives ({p['kappa']}, {p['n_r']})"
    # ring_lattice.rs published values: sigma 2^17.4, beta 2^24.6 (1 dp)
    assert abs(math.log2(p["sigma"]) - 17.4) < 0.05
    assert abs(math.log2(p["beta"]) - 24.6) < 0.05


# ---------------------------------------------------------------------------
# [core-SVP] The model. delta(b) via the Chen asymptotic; cost 2^(0.292 b)
# classical, 2^(0.257 b) quantum. No dimensions-for-free, no memory cost --
# the plain, conservative-for-us direction (it UNDERSTATES attack cost less
# than practical BKZ would; movement is judged against this floor).

B_MIN, B_MAX = 40, 1500


def log2_delta(b):
    """Chen asymptotic root-Hermite factor of BKZ with block size b."""
    b = float(b)
    d = (b / (2.0 * math.pi * math.e) * (math.pi * b) ** (1.0 / b)) \
        ** (1.0 / (2.0 * (b - 1.0)))
    return math.log2(d)


def sis_success(b, k_z, width, q, beta_l2):
    """BKZ-b finds z != 0, Az = 0 mod q, ||z||_2 <= beta: shortest vector
    of the q-ary kernel lattice at the best sub-dimension m <= width,
    length min over m of delta^m * q^(k_z/m) (m >= k_z for full volume)."""
    lq, lb = math.log2(q), math.log2(beta_l2)
    ld = log2_delta(b)
    m = math.sqrt(k_z * lq / ld)      # unconstrained optimum
    m = max(float(k_z), min(float(width), m))
    return ld * m + k_z * lq / m <= lb


def usvp_success(b, n_sec, m_max, q, stddev):
    """Primal uSVP embedding, 2016 estimate: success iff
    stddev*sqrt(b) <= delta^(2b - d - 1) * q^(m/d), d = n_sec + m + 1,
    maximized over the number of used samples m <= m_max."""
    lq = math.log2(q)
    ld = log2_delta(b)
    lhs = math.log2(stddev) + 0.5 * math.log2(b)

    def rhs(m):
        d = n_sec + m + 1
        return (2.0 * b - d - 1.0) * ld + (m / d) * lq

    best = max(rhs(m) for m in range(16, m_max + 1, 8))
    return lhs <= best


def min_blocksize(success):
    """Smallest b in [B_MIN, B_MAX] with success(b) (monotone in b), or
    None if even B_MAX fails. Returns B_MIN when B_MIN already succeeds
    (real security is then <= 0.292*B_MIN -- reported as such)."""
    if not success(B_MAX):
        return None
    if success(B_MIN):
        return B_MIN
    lo, hi = B_MIN, B_MAX  # success(lo) False, success(hi) True
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if success(mid):
            hi = mid
        else:
            lo = mid
    return hi


def sis_blocksize(k_z, width, q, beta_l2):
    if beta_l2 >= q:
        return B_MIN  # trivial q-vector; report the floor
    return min_blocksize(lambda b: sis_success(b, k_z, width, q, beta_l2))


def usvp_blocksize(n_sec, m_max, q, stddev=math.sqrt(2.0 / 3.0)):
    if n_sec <= 0:
        return B_MIN  # no hiding dimension left at all
    return min_blocksize(lambda b: usvp_success(b, n_sec, m_max, q, stddev))


def bits(b, coeff):
    if b is None:
        return float("inf")
    return coeff * b


def fmt_bits(b, coeff):
    if b is None:
        return f">{coeff * B_MAX:.0f}"
    x = coeff * b
    return (f"<={x:.1f}" if b == B_MIN else f"{x:.1f}")


def model_equivalent_blocksize():
    """The b whose Chen delta equals the C3 design model's delta0 = 1.0037
    (log2 = 0.005326) -- i.e. the core-SVP strength the C3 line actually
    encodes."""
    lo, hi = B_MIN, B_MAX
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if log2_delta(mid) <= LOG2_DELTA0:
            hi = mid
        else:
            lo = mid
    return hi


# ---------------------------------------------------------------------------
# Instance assembly.

def instance_rows(label, kappa, n_r, msg_r, q, beta, sigma, source_note):
    """Security of one (kappa, N_r) point: MSIS + MLWE, both norms of the
    task convention. Returns a dict of everything the tables need."""
    k_z = kappa * D
    n_z = n_r * D
    n_sec = (n_r - kappa - msg_r) * D
    m_lwe = (kappa + msg_r) * D
    b_sis = sis_blocksize(k_z, n_z, q, beta)
    b_lwe = usvp_blocksize(n_sec, m_lwe, q)
    lq = math.log2(q)
    return dict(
        label=label, kappa=kappa, n_r=n_r, msg_r=msg_r, q=q, beta=beta,
        sigma=sigma, k_z=k_z, n_z=n_z, n_sec=n_sec, m_lwe=m_lwe,
        b_sis=b_sis, b_lwe=b_lwe,
        c2_headroom=lq - math.log2(8.0 * beta),
        d_lwe_model=math.ceil(768.0 * lq / 11.7),
        note=source_note,
    )


def sweep_grid(kappa, n_r):
    return [(kappa + dk, n_r + dn)
            for dk in (-2, -1, 0, 1, 2)
            for dn in (-8, -4, 0, 4, 8)]


# ---------------------------------------------------------------------------
# [core-SVP] report.

def core_svp_report(fh):
    w = fh.write
    b_model = model_equivalent_blocksize()
    w("Q5 estimator run -- [core-SVP] model (this file; see header for the\n"
      "methodology). Every number in this file is [core-SVP] unless marked\n"
      "otherwise. delta(b): Chen asymptotic; costs 2^(0.292 b) classical,\n"
      "2^(0.257 b) quantum; MSIS in l2 at the chain's l2 beta; MLWE primal\n"
      "uSVP (2016 estimate) with ternary secret/error, stddev sqrt(2/3).\n\n")
    w(f"The C3 design model's delta0 = 1.0037 (log2 {LOG2_DELTA0}) equals the\n"
      f"Chen delta of BKZ block size b = {b_model}, i.e. the C3 line as\n"
      f"written is a {CLASSICAL * b_model:.0f}-bit-classical /"
      f" {QUANTUM * b_model:.0f}-bit-quantum core-SVP line, NOT a 128-bit\n"
      f"line. Any C3-satisfying point therefore needs its k_Z slack, not the\n"
      f"model's equality point, to clear 128 bits.\n\n")

    all_frozen = []
    for q, qlabel, frozen in (
        (Q31, "q8_31 = 2147483249 (frozen modulus)", True),
        (Q46, "q8_46 = 70368744176561 (fallback; kappa/N_r chain-derived"
              " here, candidates not frozen)", False),
    ):
        w("=" * 78 + f"\nModulus {qlabel}\n" + "=" * 78 + "\n")
        lq = math.log2(q)
        insts = []
        for label, rows, inner, cols, e, kap31, nr31 in DIGIT_SHAPES:
            if frozen:
                kap, n_r = kap31, nr31
                note = "frozen"
            else:
                r = rp.derive_q2("pi2", rows, inner, cols, 0, lq, True, e)
                kap, n_r = r["kappa"], r["n_r"]
                note = "chain-derived"
            sigma, beta, l_dig, msg_r = digit_chain_at(rows, inner, cols,
                                                       e, n_r)
            insts.append((label, rows, inner, cols, e,
                          instance_rows(label, kap, n_r, msg_r, q, beta,
                                        sigma, note)))
        p = proto_derive(q)
        if frozen:
            kap, n_r = PROTO[1], PROTO[2]
            note = "frozen"
        else:
            kap, n_r = p["kappa"], p["n_r"]
            note = "chain-derived"
        sigma, beta = proto_chain_at(n_r)
        insts.append((PROTO[0], None, None, None, None,
                      instance_rows(PROTO[0], kap, n_r, PROTO[3], q, beta,
                                    sigma, note)))

        w("\n-- Frozen/derived points ------------------------------------\n")
        w("| shape | point | log2 beta | MSIS b | MSIS cl | MSIS qu |"
          " MLWE n_sec | MLWE b | MLWE cl | MLWE qu | C2 headroom |"
          " verdict vs 128 cl |\n")
        w("|---|---|---|---|---|---|---|---|---|---|---|---|\n")
        for label, rows, inner, cols, e, r in insts:
            v_sis = bits(r["b_sis"], CLASSICAL)
            v_lwe = bits(r["b_lwe"], CLASSICAL)
            verdict = ("PASS" if min(v_sis, v_lwe) >= TARGET else
                       f"FAIL ({'MSIS' if v_sis < v_lwe else 'MLWE'}"
                       f" {min(v_sis, v_lwe):.0f})")
            w(f"| {label} | {r['note']} kappa={r['kappa']} N_r={r['n_r']}"
              f" msg_r={r['msg_r']} | {math.log2(r['beta']):.2f}"
              f" | {r['b_sis']} | {fmt_bits(r['b_sis'], CLASSICAL)}"
              f" | {fmt_bits(r['b_sis'], QUANTUM)} | {r['n_sec']}"
              f" | {r['b_lwe']} | {fmt_bits(r['b_lwe'], CLASSICAL)}"
              f" | {fmt_bits(r['b_lwe'], QUANTUM)}"
              f" | {r['c2_headroom']:.1f} | {verdict} |\n")
            all_frozen.append((label, r))
        w("\n  (MLWE n_sec uses the INTEGRAL rank: (N_r - kappa - msg_r)*128."
          "\n   The chain's own C4 check uses the raw k_z before kappa is"
          "\n   rounded up -- where the two disagree the table above is the"
          "\n   deployed instance; the note discusses the gap.)\n")

        # Sweep tables.
        for label, rows, inner, cols, e, r in insts:
            w(f"\n-- Sweep {label} @ {qlabel.split()[0]}"
              f" (frozen kappa={r['kappa']}, N_r={r['n_r']};"
              f" kappa +-2, N_r +-8) --\n")
            w("| kappa | N_r | log2 beta | MSIS cl | MLWE n_sec | MLWE cl |"
              " C2 hdrm | min(cl) |\n|---|---|---|---|---|---|---|---|\n")
            for kap, n_r in sweep_grid(r["kappa"], r["n_r"]):
                if kap < 1 or n_r <= kap + r["msg_r"]:
                    w(f"| {kap} | {n_r} | - | - | - | - | - |"
                      " (n_sec <= 0) |\n")
                    continue
                if e is not None:
                    sigma, beta, _, _ = digit_chain_at(rows, inner, cols,
                                                       e, n_r)
                else:
                    sigma, beta = proto_chain_at(n_r)
                s = instance_rows(label, kap, n_r, r["msg_r"], q, beta,
                                  sigma, "sweep")
                v = min(bits(s["b_sis"], CLASSICAL),
                        bits(s["b_lwe"], CLASSICAL))
                mark = " *" if (kap, n_r) == (r["kappa"], r["n_r"]) else ""
                w(f"| {kap}{mark} | {n_r} | {math.log2(beta):.2f}"
                  f" | {fmt_bits(s['b_sis'], CLASSICAL)} | {s['n_sec']}"
                  f" | {fmt_bits(s['b_lwe'], CLASSICAL)}"
                  f" | {s['c2_headroom']:.1f} | {v:.1f} |\n")
        w("\n")

    # Minimum-movement solve at the frozen modulus.
    w("=" * 78 + "\nMinimum (kappa, N_r) for 128-bit classical [core-SVP]"
      " at q8_31\n" + "=" * 78 + "\n")
    w("| shape | frozen (kappa, N_r) | min kappa for MSIS>=128"
      " | min N_r for MLWE>=128 (at frozen kappa) | movement |\n")
    w("|---|---|---|---|---|\n")
    moves = {}
    for label, r in all_frozen:
        if r["q"] != Q31:
            continue
        shape = next((s for s in DIGIT_SHAPES if s[0] == label), None)

        def beta_at(n_r):
            if shape is not None:
                _, b_, _, _ = digit_chain_at(shape[1], shape[2], shape[3],
                                             shape[4], n_r)
            else:
                _, b_ = proto_chain_at(n_r)
            return b_

        min_kap = next(k for k in range(1, 64)
                       if bits(sis_blocksize(k * D, r["n_z"], Q31,
                                             beta_at(r["n_r"])),
                               CLASSICAL) >= TARGET)
        min_nr = next(n for n in range(r["kappa"] + r["msg_r"] + 1, 256)
                      if bits(usvp_blocksize((n - r["kappa"] - r["msg_r"])
                                             * D, (r["kappa"] + r["msg_r"])
                                             * D, Q31), CLASSICAL) >= TARGET)
        dk, dn = min_kap - r["kappa"], min_nr - r["n_r"]
        moves[label] = (min_kap, min_nr, r)
        w(f"| {label} | ({r['kappa']}, {r['n_r']}) | {min_kap}"
          f" | {min_nr} | kappa {dk:+d} ({100 * dk / r['kappa']:+.0f}%),"
          f" N_r {dn:+d} ({100 * dn / r['n_r']:+.0f}%) |\n")
    w("\n(min N_r solves the MLWE side only; if kappa also moves, N_r must"
      "\n absorb it 1:1 to keep n_sec -- the combined point is"
      "\n (min kappa, min N_r + (min kappa - frozen kappa)).)\n")

    # Downstream cost of the recommended movement (params-chain formulas).
    w("\n" + "=" * 78 + "\nDownstream cost of movement at q8_31"
      " (route_r_params.py formulas)\n" + "=" * 78 + "\n")
    w("| shape | point | commit/col KB | proof KB | deltas |\n")
    w("|---|---|---|---|---|\n")
    lq = math.log2(Q31)
    for label, rows, inner, cols, e, kap31, nr31 in DIGIT_SHAPES:
        min_kap, min_nr, r = moves[label]
        kap2 = max(min_kap, kap31)
        nr2 = max(min_nr + (kap2 - kap31), nr31)
        for kap, n_r, tag in ((kap31, nr31, "frozen"),
                              (kap2, nr2, "128-bit floor")):
            sigma, beta, l_dig, msg_r = digit_chain_at(rows, inner, cols,
                                                       e, n_r)
            rr = dict(sigma=sigma, n_z=n_r * D, kappa=kap,
                      msg_z=msg_r * D, l_dig=l_dig)
            ckb = (kap + msg_r) * D * lq / 8.0 / 1024.0
            pkb = rp.proof_kb_q2("pi2", rr, lq)
            if tag == "frozen":
                base = (ckb, pkb)
                w(f"| {label} | frozen ({kap}, {n_r}) | {ckb:.1f}"
                  f" | {pkb:.1f} | -- |\n")
            else:
                w(f"| {label} | 128-bit floor ({kap}, {n_r}) | {ckb:.1f}"
                  f" | {pkb:.1f} | commit {ckb - base[0]:+.1f} KB"
                  f" ({100 * (ckb / base[0] - 1):+.1f}%),"
                  f" proof {pkb - base[1]:+.1f} KB"
                  f" ({100 * (pkb / base[1] - 1):+.1f}%) |\n")
    w("\n(The prototype opening is a development artifact; its movement is"
      "\n reported in the tables above but not costed -- it has no"
      "\n deployment proof-size model in route_r_params.py.)\n")
    return all_frozen, moves


# ---------------------------------------------------------------------------
# [lattice-estimator] bridge: sage.all shim + validated in-process run.

def install_sage_shim():
    """Register a minimal pure-Python sage.all in sys.modules. Floats for
    RR/RDF/RealField, ints for ZZ, mpmath for zeta/chi2/Beta CDFs. Only
    the symbols the estimator imports are provided."""
    import types
    import functools
    import fractions
    import mpmath

    if "sage.all" in sys.modules:
        return
    m = types.ModuleType("sage.all")
    sage = types.ModuleType("sage")

    class _Real(float):
        """float + the sage RealNumber methods the estimator calls."""

        def is_NaN(self):
            return math.isnan(self)

        def is_infinity(self):
            return math.isinf(self)

        def sqrt(self):
            return _Real(math.sqrt(self))

        def log(self, base=None):
            return _Real(math.log(self) if base is None
                         else math.log(self) / math.log(base))

        def n(self, *_a, **_k):
            return self

        numerical_approx = n

    class _RealField:
        def __init__(self, prec=53):
            self._prec = prec

        def __call__(self, x):
            return _Real(x)

        def prec(self):
            return self._prec

        def pi(self):
            return math.pi

    def _log(x, base=None):
        if base is None:
            return math.log(x)
        return math.log(x) / math.log(base)

    def _binomial(n, k):
        try:
            return math.comb(int(n), int(k))
        except (ValueError, TypeError, OverflowError):
            return math.exp(math.lgamma(n + 1) - math.lgamma(k + 1)
                            - math.lgamma(n - k + 1))

    def _find_root(f, a, b, **_kw):
        fa, fb = f(a), f(b)
        if fa == 0:
            return a
        if fb == 0:
            return b
        if fa * fb > 0:  # scan for a sign change, sage-style RuntimeError
            n = 256
            xs = [a + (b - a) * i / n for i in range(n + 1)]
            px, pf = xs[0], fa
            for x in xs[1:]:
                fx = f(x)
                if pf * fx <= 0:
                    a, fa, b, fb = px, pf, x, fx
                    break
                px, pf = x, fx
            else:
                raise RuntimeError("f appears to have no root in the bracket")
        for _ in range(200):
            mid = 0.5 * (a + b)
            fm = f(mid)
            if fm == 0 or (b - a) < 1e-13 * max(1.0, abs(mid)):
                return mid
            if fa * fm < 0:
                b, fb = mid, fm
            else:
                a, fa = mid, fm
        return 0.5 * (a + b)

    def _cached(f):
        cache = {}

        @functools.wraps(f)
        def wrapper(*args, **kwds):
            key = (args, tuple(sorted(kwds.items())))
            try:
                hash(key)
            except TypeError:
                return f(*args, **kwds)
            if key not in cache:
                cache[key] = f(*args, **kwds)
            return cache[key]

        wrapper.clear_cache = cache.clear
        return wrapper

    class RealDistribution:
        def __init__(self, name, params):
            self.name, self.params = name, params

        def cum_distribution_function(self, x):
            if self.name == "chisquared":
                if x <= 0:
                    return 0.0
                return float(mpmath.gammainc(self.params / 2.0, 0, x / 2.0,
                                             regularized=True))
            if self.name == "beta":
                a, b = self.params
                if x <= 0:
                    return 0.0
                if x >= 1:
                    return 1.0
                return float(mpmath.betainc(a, b, 0, x, regularized=True))
            if self.name == "gaussian":
                s = self.params
                return 0.5 * (1.0 + math.erf(x / (s * math.sqrt(2.0))))
            raise NotImplementedError(self.name)

    def _unavailable(name):
        def stub(*_a, **_k):
            raise NotImplementedError(
                f"sage.{name} is not provided by the estimator_run shim")
        return stub

    ns = dict(
        oo=float("inf"), pi=math.pi, e=math.e,
        euler_gamma=0.57721566490153286,
        RR=_RealField(53), RDF=_RealField(53), RealField=_RealField,
        ZZ=lambda x: int(round(x)),
        QQ=fractions.Fraction,
        parent=lambda x: _RealField(53),
        log=_log, exp=math.exp, sqrt=math.sqrt,
        ceil=lambda x: math.ceil(x), floor=lambda x: math.floor(x),
        round=round, prod=math.prod, binomial=_binomial,
        erf=math.erf, tanh=math.tanh, coth=lambda x: 1.0 / math.tanh(x),
        zeta=lambda s: float(mpmath.zeta(s)),
        find_root=_find_root, cached_function=_cached,
        RealDistribution=RealDistribution,
        var=_unavailable("var"), find_fit=_unavailable("find_fit"),
        line=_unavailable("line"),
        PowerSeriesRing=_unavailable("PowerSeriesRing"),
    )
    for k, v in ns.items():
        setattr(m, k, v)
    sage.all = m
    sys.modules["sage"] = sage
    sys.modules["sage.all"] = m


def patch_prob_amplify():
    """DISCLOSED runtime patch (the estimator code on disk is untouched):
    estimator.prob.amplify computes ceil(log(1-target)/log(1-success)) at
    up-to-2048-bit MPFR precision; under the float shim `1 - success`
    rounds to 1.0 for success < 2^-53 and the division hits 0. This
    reimplementation is the same formula via log1p (exact for doubles);
    success probabilities below 2^-900 return oo -- at that point the
    repeat count is astronomical and the optimizer discards the branch
    either way. Patched in prob and at every `from .prob import amplify`
    alias site."""
    import estimator.prob as prob

    oo = float("inf")

    def amplify(target_success_probability, success_probability,
                majority=False):
        if success_probability >= 1:
            return 1
        if not success_probability > 2.0 ** -900:
            return oo
        try:
            if majority:
                eps = success_probability / 2
                return math.ceil(2 * math.log(2 - 2
                                              * target_success_probability)
                                 / math.log1p(-4 * eps * eps))
            return math.ceil(math.log1p(-target_success_probability)
                             / math.log1p(-success_probability))
        except (ValueError, ZeroDivisionError, OverflowError):
            return oo

    prob.amplify = amplify
    import estimator.sis_lattice
    import estimator.sis_large_norm
    import estimator.lwe_primal
    import estimator.lwe_dual
    import estimator.lwe_guess
    for mod in (estimator.sis_lattice, estimator.sis_large_norm,
                estimator.lwe_primal, estimator.lwe_dual,
                estimator.lwe_guess):
        mod.prob_amplify = amplify


def le_cost_str(res):
    """Render an estimator Cost as 'rop 2^x (beta b, d dim)'."""
    out = f"rop 2^{math.log2(res['rop']):.1f}"
    if "beta" in res:
        out += f", beta {res['beta']}"
    if "d" in res:
        out += f", d {res['d']}"
    return out


def run_lattice_estimator(fh, frozen_rows):
    """Import + validate + run the real estimator on the frozen instances.
    Returns 'validated' | 'unvalidated' | 'failed'."""
    w = fh.write
    w("Q5 estimator run -- [lattice-estimator] leg.\n"
      "Tool: github.com/malb/lattice-estimator (clone commit below),\n"
      "executed in-process under the sage.all float shim of\n"
      "scripts/estimator_run.py (estimator code unmodified).\n\n")
    try:
        head = open(os.path.join(TOOLS_LE, ".git", "HEAD")).read().strip()
        if head.startswith("ref:"):
            ref = head.split()[1]
            head = open(os.path.join(TOOLS_LE, ".git", ref)).read().strip()
        w(f"clone commit: {head}\n\n")
    except OSError:
        w("clone commit: (tools/lattice-estimator missing)\n\n")

    try:
        install_sage_shim()
        sys.path.insert(0, TOOLS_LE)
        from estimator import LWE, SIS, ND, RC, schemes  # noqa: E501
        patch_prob_amplify()
        w("prob.amplify float-safe patch applied (see"
          " patch_prob_amplify() -- same formula via log1p; disk code"
          " untouched).\n\n")
    except Exception:
        w("IMPORT FAILED -- the estimator could not be loaded under the\n"
          "shim. Q5 stays PARTIAL (model-validated only).\n\n")
        w(traceback.format_exc())
        return "failed", None

    # -- shim validation against the estimator's own doctest anchors ------
    w("-- Shim validation (expected values are the estimator's own doctest"
      " outputs) --\n")
    ok = True
    checks = []
    try:
        t0 = time.time()
        r = LWE.primal_usvp(schemes.Kyber512)
        checks.append(("LWE.primal_usvp(Kyber512)", r["beta"], 406,
                       math.log2(r["rop"]), 143.8, time.time() - t0))
        t0 = time.time()
        r = SIS.lattice(SIS.Parameters(n=113, q=2048, length_bound=512,
                                       norm=2))
        checks.append(("SIS.lattice(n=113,q=2048,B=512,l2)", r["beta"], 61,
                       math.log2(r["rop"]), 47.0, time.time() - t0))
        t0 = time.time()
        r = SIS.lattice(schemes.Dilithium2_MSIS_WkUnf)
        checks.append(("SIS.lattice(Dilithium2_MSIS_WkUnf,linf)", r["beta"],
                       427, math.log2(r["rop"]), 152.2, time.time() - t0))
    except Exception:
        w("validation call FAILED:\n" + traceback.format_exc())
        ok = False
    for name, got_b, want_b, got_rop, want_rop, dt in checks:
        good = (got_b == want_b) and abs(got_rop - want_rop) <= 0.15
        ok &= good
        w(f"  {'ok  ' if good else 'FAIL'} {name}: beta {got_b}"
          f" (expect {want_b}), rop 2^{got_rop:.1f}"
          f" (expect 2^{want_rop}) [{dt:.1f}s]\n")
    status = "validated" if ok and checks else "unvalidated"
    w(f"shim validation: {status.upper()}\n")
    if status != "validated":
        w("Numbers below are printed for the record but MUST NOT be used\n"
          "for sign-off; Q5 stays PARTIAL pending a Sage run.\n")
    w("\n-- Frozen instances --\n"
      "MSIS: SIS.Parameters(n=k_Z, q, length_bound=beta(l2), m=N_Z,"
      " norm=2), SIS.lattice.\n"
      "MLWE: LWE.Parameters(n=n_sec, q, Xs=Xe=UniformMod(3), m=m_lwe),"
      " primal_usvp + primal_bdd.\n"
      "Cost models: MATZOV (estimator default) and ADPS16"
      " (core-SVP 0.292b, for apples-to-apples with the [core-SVP] leg).\n\n")

    results = {}
    for label, r in frozen_rows:
        w(f"### {label} @ q={r['q']} ({r['note']})"
          f"  (kappa={r['kappa']}, N_r={r['n_r']},"
          f" msg_r={r['msg_r']}, log2 beta={math.log2(r['beta']):.2f})\n")
        entry = {}
        sis_p = SIS.Parameters(n=r["k_z"], q=r["q"],
                               length_bound=math.floor(r["beta"]),
                               m=r["n_z"], norm=2)
        lwe_p = LWE.Parameters(n=r["n_sec"], q=r["q"],
                               Xs=ND.UniformMod(3), Xe=ND.UniformMod(3),
                               m=r["m_lwe"])
        for tag, kw in (("MATZOV", {}),
                        ("ADPS16", dict(red_cost_model=RC.ADPS16))):
            try:
                t0 = time.time()
                res = SIS.lattice(sis_p, **kw)
                entry[f"sis_{tag}"] = math.log2(res["rop"])
                w(f"  MSIS  [{tag:6}] {le_cost_str(res)}"
                  f"  [{time.time() - t0:.1f}s]\n")
            except Exception as err:
                w(f"  MSIS  [{tag:6}] FAILED: {err!r}\n")
            for alg, f in (("usvp", LWE.primal_usvp),
                           ("bdd", LWE.primal_bdd)):
                try:
                    t0 = time.time()
                    res = f(lwe_p, **kw)
                    entry[f"lwe_{alg}_{tag}"] = math.log2(res["rop"])
                    w(f"  MLWE-{alg:4} [{tag:6}] {le_cost_str(res)}"
                      f"  [{time.time() - t0:.1f}s]\n")
                except Exception as err:
                    w(f"  MLWE-{alg:4} [{tag:6}] FAILED: {err!r}\n")
        results[(label, r["q"])] = entry
        w("\n")
    return status, results


# ---------------------------------------------------------------------------

def main():
    skip_le = "--skip-lattice-estimator" in sys.argv[1:]
    os.makedirs(RESULTS, exist_ok=True)
    self_check()
    print("self-check: forward passes pinned to route_r_params.py /"
          " ring_lattice.rs -- ok")

    path = os.path.join(RESULTS, "estimator_core_svp.txt")
    with open(path, "w") as fh:
        frozen, moves = core_svp_report(fh)
    print(f"[core-SVP] tables -> {path}")
    for label, r in frozen:
        if r["q"] != Q31:
            continue
        cl = min(bits(r["b_sis"], CLASSICAL), bits(r["b_lwe"], CLASSICAL))
        qu = min(bits(r["b_sis"], QUANTUM), bits(r["b_lwe"], QUANTUM))
        print(f"  {label:26} q31 frozen: classical {cl:6.1f}"
              f"  quantum {qu:6.1f}  ({'PASS' if cl >= TARGET else 'FAIL'}"
              f" vs 128 classical)")

    path = os.path.join(RESULTS, "estimator_lattice_estimator.txt")
    if skip_le:
        print("[lattice-estimator] skipped (--skip-lattice-estimator)")
        return
    with open(path, "w") as fh:
        status, _ = run_lattice_estimator(fh, frozen)
    print(f"[lattice-estimator] {status} -> {path}")


if __name__ == "__main__":
    main()
