#!/usr/bin/env python3
"""Independent recount of every number in the draft's §1.3, §3.4 and §6.2.

Exact integer / Fraction arithmetic.  Every geometry constant below is quoted
from the Rust at lane commit 8c5922b with its file:line; NOTHING is copied
from the draft or from its script (which this checker did not read before
writing this file).

Sources of the constants
  shape.rs:381-400   Shape::rung_g   T24 d96 f192, 6x16 over 2 KV,
                     log_cols=10, inv_rate=4, endpoint_rows=9
  shape.rs:441-462   Shape::rung_k4  same, 12x8 over 4 KV
  shape.rs:477-480   Shape::m125     T512 d768 f2048, 12x64 over 4 KV,
                     log_cols=14, inv_rate=4, endpoint_rows=37
  shape.rs:203       opened_cols = COL_CHECKS
  layout.rs:930      M_ROWS = 2*N_SLOTS + 4 = 50
  zk.rs:373-375      MASK_LOG_MSG=9 (m=512), MASK_LOG_DOM=12 (dom=4096),
                     MASK_Q=256
  zk.rs:431-462      mask_commit: 2*sum(L_s) + 2*23*MASK_Q + 4*(2m) fp draws,
                     dom salts
  zkp-core/pcs.rs:777-778  pads = rng.fp_vec(rows*q); salts = nn * bytes32
  endpoint_g.rs:228-233    the five appended rows are filled with rng.fp()
  protocol.rs:757-768      H re-draws its zero-sum pair: 2*(n-1) fp()
  grow_tests.rs:369-391,   the pinned layout models (a_rows, h_rows, ...,
      :400-425, :432-469   published_round_values, challenge_draws)
  run.rs:216               boundary commitment rows = endpoint_rows + 1
  endpoint_g.rs MASK_ROWS = 5 (endpoint_rows = data_rows + 5)
  field: Fp is the Goldilocks prime p = 2^64 - 2^32 + 1; |Fp2| = p^2
"""
from fractions import Fraction
import math, json

P = 2**64 - 2**32 + 1          # zkp-core/src/field.rs
FP2 = P * P
Q_BUDGET = 2**128              # the draft's adversary budget
COL_CHECKS = 256               # shape.rs:203 / MASK_Q
MASK_ROWS = 5                  # endpoint_g.rs
M_ROWS = 50                    # layout.rs:930
MASK_DOM = 4096                # zk.rs:374
MASK_M = 512                   # zk.rs:373

def lg(x):
    """exact-ish log2 of a positive Fraction/int, to 4 dp"""
    if isinstance(x, Fraction):
        return math.log2(x.numerator) - math.log2(x.denominator)
    return math.log2(x)

# ---------------------------------------------------------------- geometry
SHAPES = {
    # name: log_cols, inv_rate, endpoint_rows, endpoint_log_n, endpoint_rate
    "rung-G":  dict(log_cols=10, inv_rate=4, endpoint_rows=9,  e_log=10, e_rate=4,
                    a_rows=623, a_data=377, h_rows=576, h_data=470,
                    published=1055, draws=242),
    "rung-K4": dict(log_cols=10, inv_rate=4, endpoint_rows=9,  e_log=10, e_rate=4,
                    a_rows=727, a_data=481, h_rows=720, h_data=614,
                    published=1070, draws=245),
    "125M":    dict(log_cols=14, inv_rate=4, endpoint_rows=37, e_log=14, e_rate=4,
                    a_rows=5681, a_data=5435, h_rows=7120, h_data=7018,
                    published=1554, draws=361),
}
# the PRE-repair models, for the control against the run memo's own figures
PRE_REPAIR_SUM_L = {"rung-G": 840, "125M": 1208}

def sum_ls(sh):
    """sum of the 23 slots' mask lengths, from the pinned model:
       sum L_s = published_round_values - challenge_draws + 46  (run memo 6.1)"""
    return sh["published"] - sh["draws"] + 46

def per_block_draws(sh, sum_l=None):
    n = 1 << sh["log_cols"]
    q = COL_CHECKS
    if sum_l is None:
        sum_l = sum_ls(sh)
    a = (sh["a_rows"] - sh["a_data"]) * n + sh["a_rows"] * q
    h = (sh["h_rows"] - sh["h_data"]) * n + sh["h_rows"] * q
    h_zero = 2 * (n - 1)                       # protocol.rs:760-768
    m = 2 * sum_l + 2 * 23 * COL_CHECKS + 4 * (2 * MASK_M)
    return dict(A=a, H=h, H_zero=h_zero, M=m, total=a + h + h_zero + m)

def endpoint_draws(sh):
    n = 1 << sh["e_log"]
    rows = sh["endpoint_rows"]
    data = rows - MASK_ROWS
    return (rows - data) * n + rows * COL_CHECKS

def boundary_draws(sh):
    n = 1 << sh["e_log"]
    rows = sh["endpoint_rows"] + 1             # run.rs:216
    data = sh["endpoint_rows"] - MASK_ROWS
    return (rows - data) * n + rows * COL_CHECKS

def leaves(sh, L):
    nn_block = (1 << sh["log_cols"]) * sh["inv_rate"]
    nn_io = (1 << sh["e_log"]) * sh["e_rate"]
    # per block: A, H (nn_block each) and M (the mask commitment's own 4096)
    # plus L-1 internal boundaries and 2 external endpoints at nn_io
    return L * (2 * nn_block + MASK_DOM) + (L + 1) * nn_io

def absorbs_and_squeezes(sh, L):
    """the draft's A = absorbs + live squeezes + tag squeezes.  We take the
    MEASURED live-squeeze figures where the gate has them and the draft's
    125M BOUND, and we independently price how much the bound could be wrong
    before any term moves."""
    return None

CONFIG = [("rung-G", 3), ("rung-K4", 3), ("125M", 12)]

out = {}
print("=" * 78)
print("A. SAMPLER DRAW COUNTS  (fp() draws; salts are raw bytes and do not count)")
print("=" * 78)
print(f"{'config':<10} {'sum L_s':>8} {'per block':>12} {'boundary':>9} {'endpoint':>9} {'run total':>13} {'log2 term':>11}")
for name, L in CONFIG:
    sh = SHAPES[name]
    pb = per_block_draws(sh)
    b = boundary_draws(sh)
    e = endpoint_draws(sh)
    tot = L * pb["total"] + (L - 1) * b + 2 * e
    term = Fraction(tot, 2**96)
    print(f"{name:<10} {sum_ls(sh):>8} {pb['total']:>12,} {b:>9,} {e:>9,} {tot:>13,} {lg(term):>11.4f}")
    out[name] = dict(L=L, sum_ls=sum_ls(sh), per_block=pb, boundary=b, endpoint=e,
                     run_draws=tot, sampler_log2=lg(term))

print()
print("  control (PRE-repair sum L_s, i.e. what the run memo counted):")
for name in ("rung-G", "125M"):
    sh = SHAPES[name]
    L = dict(CONFIG)[name]
    pb = per_block_draws(sh, PRE_REPAIR_SUM_L[name])
    tot = L * pb["total"] + (L - 1) * boundary_draws(sh) + 2 * endpoint_draws(sh)
    print(f"    {name:<8} sum L_s={PRE_REPAIR_SUM_L[name]:>5}  per block {pb['total']:>10,}  run {tot:>12,}"
          f"   (memo: 686,990 / 2,093,226 and 9,029,742 / 109,728,040)")

print()
print("=" * 78)
print("B. LEAVES, SALTS, OPENED COLUMNS")
print("=" * 78)
print(f"{'config':<10} {'roots':>6} {'N_leaf':>11} {'salt slots':>11} {'E[distinct opened]':>19} {'E[unopened]':>13}")
for name, L in CONFIG:
    sh = SHAPES[name]
    nl = leaves(sh, L)
    roots = 4 * L + 1
    slots = COL_CHECKS * roots
    # E[distinct] over 256 draws with replacement from nn
    nn_block = (1 << sh["log_cols"]) * sh["inv_rate"]
    nn_io = (1 << sh["e_log"]) * sh["e_rate"]
    def edist(nn):
        return nn * (1 - (Fraction(nn - 1, nn)) ** COL_CHECKS)
    tot_dist = L * (2 * float(edist(nn_block)) + float(edist(MASK_DOM))) + (L + 1) * float(edist(nn_io))
    print(f"{name:<10} {roots:>6} {nl:>11,} {slots:>11,} {tot_dist:>19,.1f} {nl - tot_dist:>13,.1f}")
    out[name].update(N_leaf=nl, roots=roots, salt_slots=slots,
                     distinct_opened=tot_dist, unopened=nl - tot_dist)

print()
print("=" * 78)
print("C. THE RESIDUAL TABLE  (log2; q = 2^128 where q appears)")
print("=" * 78)
# the draft's transcript query counts A: absorbs + live squeezes + tag squeezes
A_COUNT = {"rung-G": 1129 + 6924 + 12, "rung-K4": 1138 + 7686 + 12, "125M": 5932 + 164560 + 48 + 12 * 1024}
hdr = f"{'term':<46}" + "".join(f"{n:>12}" for n, _ in CONFIG)
print(hdr)
rows = []
def row(label, fn):
    vals = []
    for name, L in CONFIG:
        vals.append(fn(name, L))
    rows.append((label, vals))
    print(f"{label:<46}" + "".join(f"{lg(v):>12.4f}" for v in vals))

row("sampler bias (D9)", lambda n, L: Fraction(out[n]["run_draws"], 2**96))
row("refusal inside the argument (S-4), L*768/|Fp2|", lambda n, L: Fraction(L * 768, FP2))
row("  the same doubled, as sec 5.2 discharges it", lambda n, L: Fraction(2 * L * 768, FP2))
row("salt guessing  q*N_leaf*2^-256", lambda n, L: Fraction(Q_BUDGET * out[n]["N_leaf"], 2**256))
row("leaf-input collision  C(N_leaf,2)*2^-256",
    lambda n, L: Fraction(out[n]["N_leaf"] * (out[n]["N_leaf"] - 1) // 2, 2**256))
row("challenge pre-query (B5)  q*A*2^-256", lambda n, L: Fraction(Q_BUDGET * A_COUNT[n], 2**256))
row("absorb-input collision (B6)  C(A,2)*2^-256",
    lambda n, L: Fraction(A_COUNT[n] * (A_COUNT[n] - 1) // 2, 2**256))
row("key collision  3*4*2^-256", lambda n, L: Fraction(12, 2**256))
row("generator, in-model alternative  6q*2^-256", lambda n, L: Fraction(6 * Q_BUDGET, 2**256))

print()
totals = []
for i, (name, L) in enumerate(CONFIG):
    # the draft's TOTAL: sampler + S-4 + salt + leafcoll + prequery + absorbcoll
    #                    + keycoll + generator-alternative
    s = (Fraction(out[name]["run_draws"], 2**96)
         + Fraction(L * 768, FP2)
         + Fraction(Q_BUDGET * out[name]["N_leaf"], 2**256)
         + Fraction(out[name]["N_leaf"] * (out[name]["N_leaf"] - 1) // 2, 2**256)
         + Fraction(Q_BUDGET * A_COUNT[name], 2**256)
         + Fraction(A_COUNT[name] * (A_COUNT[name] - 1) // 2, 2**256)
         + Fraction(12, 2**256)
         + Fraction(6 * Q_BUDGET, 2**256))
    totals.append(s)
print(f"{'TOTAL eps(q) at q = 2^128':<46}" + "".join(f"{lg(s):>12.4f}" for s in totals))
# and at q = 2^80
totals80 = []
for i, (name, L) in enumerate(CONFIG):
    s = (Fraction(out[name]["run_draws"], 2**96)
         + Fraction(L * 768, FP2)
         + Fraction(2**80 * out[name]["N_leaf"], 2**256)
         + Fraction(out[name]["N_leaf"] * (out[name]["N_leaf"] - 1) // 2, 2**256)
         + Fraction(2**80 * A_COUNT[name], 2**256)
         + Fraction(A_COUNT[name] * (A_COUNT[name] - 1) // 2, 2**256)
         + Fraction(12, 2**256) + Fraction(6 * 2**80, 2**256))
    totals80.append(s)
print(f"{'TOTAL eps(q) at q = 2^80':<46}" + "".join(f"{lg(s):>12.4f}" for s in totals80))

print()
print(f"{'challenge-only refusal (3L+1)/p [LIVENESS]':<46}"
      + "".join(f"{lg(Fraction(3 * L + 1, P)):>12.4f}" for _, L in CONFIG))

print()
print("  gap from the sampler term to the NEXT LARGEST distance term (bits):")
for name, L in CONFIG:
    samp = lg(Fraction(out[name]["run_draws"], 2**96))
    others = [lg(Fraction(2 * L * 768, FP2)),
              lg(Fraction(Q_BUDGET * out[name]["N_leaf"], 2**256)),
              lg(Fraction(out[name]["N_leaf"] * (out[name]["N_leaf"] - 1) // 2, 2**256)),
              lg(Fraction(Q_BUDGET * A_COUNT[name], 2**256)),
              lg(Fraction(A_COUNT[name] * (A_COUNT[name] - 1) // 2, 2**256)),
              lg(Fraction(12, 2**256)), lg(Fraction(6 * Q_BUDGET, 2**256))]
    nxt = max(others)
    print(f"    {name:<10} sampler {samp:.4f}, next {nxt:.4f}, gap {samp - nxt:.2f} bits")

print()
print("=" * 78)
print("D. MANY RUNS (k = 10^6)")
print("=" * 78)
k = 10**6
for name, L in CONFIG:
    samp = Fraction(k * out[name]["run_draws"], 2**96)
    ref = Fraction(k * L * 768, FP2)
    coll = Fraction(k * k * out[name]["N_leaf"] * out[name]["N_leaf"], 2 * 2**256)
    salt = Fraction(k * Q_BUDGET * out[name]["N_leaf"], 2**256)
    print(f"  {name:<10} sampler {lg(samp):>9.4f}  refusal {lg(ref):>9.4f}  "
          f"leaf-coll(quadratic) {lg(coll):>9.4f}  salt {lg(salt):>9.4f}  "
          f"total {lg(samp + ref + coll + salt):>9.4f}")

print()
print("=" * 78)
print("E. TREE OCCUPANCY (expectations over the 256 index draws)")
print("=" * 78)
def tree_row(nn):
    depth = nn.bit_length() - 1
    d = float(nn * (1 - (Fraction(nn - 1, nn)) ** COL_CHECKS))
    # leaf digests revealed: each opened leaf's own digest is recomputed, and
    # its sibling at level 0 is in the path
    sib = float(nn * (1 - (Fraction(nn - 2, nn)) ** COL_CHECKS)) if nn > 2 else 0.0
    # expected number of level-0 nodes appearing as a path sibling OR opened
    revealed_leaf = d + float(nn * (1 - (Fraction(nn - 1, nn)) ** COL_CHECKS
                                    - Fraction(COL_CHECKS, 1) * Fraction(1, nn)
                                    * (Fraction(nn - 1, nn)) ** (COL_CHECKS - 1)) * 0 + 0)
    return depth, d
print(f"{'tree':<34} {'leaves':>8} {'depth':>6} {'E[distinct opened]':>19} {'% of leaves':>12}")
for label, nn in [("rung-G/K4: every tree", 4096),
                  ("125M: A, H, boundary, endpoint", 65536),
                  ("125M: M", 4096)]:
    depth, d = tree_row(nn)
    print(f"{label:<34} {nn:>8,} {depth:>6} {d:>19.1f} {100*d/nn:>11.1f}%")

json.dump({k2: {kk: (vv if not isinstance(vv, dict) else vv) for kk, vv in v.items()}
           for k2, v in out.items()},
          open("/home/victor/IntelligenceRegulation/results/zk60_hash_layer_fs_lift_run_check/residuals_recount.json", "w"),
          indent=1, default=str)
print()
print("wrote residuals_recount.json")

print()
print("=" * 78)
print("F. FULL TREE-OCCUPANCY TABLE  (the draft's sec 3.4 / control C2)")
print("=" * 78)
def occupancy(nn, k=COL_CHECKS):
    """E[distinct opened], E[level-0 digests revealed], E[internal revealed],
    for k index draws WITH REPLACEMENT from nn leaves."""
    F = Fraction
    dist = nn * (1 - F(nn - 1, nn) ** k)
    lvl0 = nn * (1 - F(nn - 2, nn) ** k)
    depth = nn.bit_length() - 1
    internal = F(0)
    for lev in range(1, depth + 1):
        cnt = nn >> lev
        blk = 1 << (lev + 1)          # a node is revealed iff its SUPERBLOCK is hit
        if blk >= nn:
            internal += cnt           # every node at this level is revealed
        else:
            internal += cnt * (1 - F(nn - blk, nn) ** k)
    return float(dist), float(lvl0), float(internal), depth

print(f"{'tree':<32} {'leaves':>8} {'dep':>4} {'opened':>8} {'lvl0 rev':>9} {'never op':>9} {'internal':>9} {'total':>9} {'of 2nn-1':>9}")
for label, nn in [("toy 2,048-leaf tree", 2048), ("toy / rung M, 4,096", 4096),
                  ("125M A/H/boundary/endpoint", 65536)]:
    d, l0, inter, dep = occupancy(nn)
    tot = l0 + inter
    print(f"{label:<32} {nn:>8,} {dep:>4} {d:>8.1f} {l0:>9.1f} {l0-d:>9.1f} {inter:>9.1f} {tot:>9.1f} {100*tot/(2*nn-1):>8.1f}%")
print("  (draft sec 3.4 / C2 quotes 240.7/453.2/212.5/1,200.6/1,654.8/40.4% at 2,048")
print("   and 248.2/481.4/233.2/1,653.8/2,136.2/26.1% at 4,096, 255.5/510.0/254.5/")
print("   3,643.7/4,154.7/3.2% at 65,536)")
