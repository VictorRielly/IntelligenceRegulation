#!/usr/bin/env python3
"""
Independent re-derivation for ZK60_JOINT_SENTENCE_AND_QUERY_CLASSES_CHECK.md.

Nothing is imported from the memo's scripts.  Every constant below was read
from the lane worktree /home/victor/wt-zk60-block125m at commit 8c5922b and is
cited with file:line.  Exact integers and fractions only.

Sections
  1  the sampler arithmetic (memo claims A-12, A-13, A-14)
  2  the stream-segment table, five shapes, rebuilt from shape/layout constants
  3  the endpoint / boundary / seam segments, and the run totals (A-5, A-7)
  4  the flag's price: which terms A-17 carries and which Lemma H states
  5  every BLAKE3 input length per profile, per function family; all clashes
  6  slot_terms -> is a six-terminal `pb-term` absorb reachable? (memo GAP-QC-4)
  7  the two counterexamples, reimplemented from scratch mod a prime
"""

import math
from fractions import Fraction as F
from itertools import combinations

FAILS = []


def check(name, got, want, note=""):
    ok = got == want
    print(f"  [{'OK ' if ok else 'FAIL'}] {name}: got {got!r}"
          + ("" if ok else f"  expected {want!r}") + (f"   {note}" if note else ""))
    if not ok:
        FAILS.append(name)
    return ok


def head(t):
    print("\n" + "=" * 96)
    print(t)
    print("=" * 96)


# ===========================================================================
# 0.  CODE CONSTANTS, transcribed at 8c5922b
# ===========================================================================
# zkp-core/src/field.rs:10
P = (1 << 64) - (1 << 32) + 1
# zkp-core/src/rng.rs:16, :63-70, :73-77, :93-99
BYTES_PER_FP = 16      # fp() = two next_u64
BYTES_PER_SALT = 32    # bytes32() = four next_u64
# hashline/src/zk.rs:373-375
MASK_LOG_MSG, MASK_LOG_DOM, MASK_Q = 9, 12, 256
MASK_M = 1 << MASK_LOG_MSG      # 512
MASK_DOM = 1 << MASK_LOG_DOM    # 4096
N_SLOTS = 23                    # layout.rs:797
M_ROWS = 2 * N_SLOTS + 4        # layout.rs:930  = 50
# hashline/src/private_block/endpoint_g.rs:52 ; private_seam.rs:36
ENDPOINT_G_MASK_ROWS = 5
SEAM_MASK_ROWS = 5
SEAM_LOG_COLS, SEAM_INV_RATE = 8, 8      # private_seam.rs:28, :30
BOUNDARY_SITES = 2                        # run.rs:50

# shape.rs / layout.rs, per shape (see the CHECK doc's provenance table)
SHAPES = {
    #                profile_len  log_cols inv_rate  Q  a_rows a_mask h_rows h_mask  e_rows e_log_n e_rate  legacy
    "toy":    dict(profile_len=39, log_cols=8,  inv_rate=8, Q=256, a_rows=455, a_mask=213,
                   h_rows=384, h_mask=280, e_rows=7,  e_log_n=8,  e_rate=8, legacy=True,  endpoint="seam"),
    "rung":   dict(profile_len=44, log_cols=10, inv_rate=4, Q=256, a_rows=623, a_mask=377,
                   h_rows=576, h_mask=470, e_rows=21, e_log_n=8,  e_rate=8, legacy=True,  endpoint="seam"),
    "rung-G": dict(profile_len=46, log_cols=10, inv_rate=4, Q=256, a_rows=623, a_mask=377,
                   h_rows=576, h_mask=470, e_rows=9,  e_log_n=10, e_rate=4, legacy=False, endpoint="general"),
    "rung-K4":dict(profile_len=47, log_cols=10, inv_rate=4, Q=256, a_rows=727, a_mask=481,
                   h_rows=720, h_mask=614, e_rows=9,  e_log_n=10, e_rate=4, legacy=False, endpoint="general"),
    "125M":   dict(profile_len=36, log_cols=14, inv_rate=4, Q=256, a_rows=5681, a_mask=5435,
                   h_rows=7120, h_mask=7018, e_rows=37, e_log_n=14, e_rate=4, legacy=False, endpoint="general"),
}

# Layout::mask_specs() -> (n_vars, degree) per slot   [shape.rs:756-807, layout.rs:1183]
MASK_SPECS = {
    "toy":    [(10,3),(10,3),(6,3),(10,4),(12,3),(5,2),(5,2),(5,2),(5,2),(7,2),(5,2),(5,2),
               (5,2),(5,2),(10,4),(10,4),(9,4),(12,4),(10,4),(9,3),(9,2),(10,2),(10,2)],
    "rung":   [(13,4),(13,4),(6,3),(11,4),(14,4),(8,2),(8,2),(8,2),(7,3),(8,3),(8,2),(8,2),
               (8,2),(9,2),(13,5),(13,5),(11,5),(14,5),(14,5),(11,3),(11,2),(13,2),(13,2)],
    "rung-K4":[(13,4),(13,4),(6,3),(11,4),(15,4),(8,2),(8,2),(8,2),(7,3),(9,3),(8,2),(8,2),
               (8,2),(9,2),(13,5),(13,5),(11,5),(15,5),(14,5),(11,3),(11,2),(13,2),(13,2)],
    "125M":   [(20,4),(20,4),(10,3),(15,4),(23,4),(11,2),(11,2),(11,2),(10,3),(13,3),(11,2),(11,2),
               (11,2),(12,2),(20,5),(20,5),(18,4),(23,5),(21,4),(15,3),(15,2),(20,2),(20,2)],
}
MASK_SPECS["rung-G"] = MASK_SPECS["rung"]

# Shape::slot_terms() = a_sites[s] + h_sites[s] + (s >= SC_IO_IN)   [shape.rs:742]
SLOT_TERMS = {
    "toy":    [1,1,22,3,2,1,1,1,2,2,1,1,1,1,56,15,13,21,17,6,1,2,2],
    "rung":   [1,1,22,3,2,1,1,1,2,2,1,1,1,1,56,15,13,24,17,6,1,2,2],
    "rung-K4":[1,1,22,3,2,1,1,1,2,2,1,1,1,1,56,15,13,24,17,6,1,2,2],
    "125M":   [1,1,22,3,2,1,1,1,2,2,1,1,1,1,54,15,13,24,17,6,1,2,2],
}
SLOT_TERMS["rung-G"] = SLOT_TERMS["rung"]

PARAM_LINE_LEN = {"toy": 113, "rung": 152, "rung-G": 152, "rung-K4": 152, "125M": 157}
EXPECTED_BYTES = 112                      # private_block.rs:213
RUN_PROFILE_LEN = {"rung-G": 44, "rung-K4": 45, "125M": 34}   # run.rs:52, :57, :58
DEGREE_LO, DEGREE_HI = 2, 5               # shape.rs:826-830 over BASE_DEGREE


def cfs_len(n_vars, degree):
    """CfsMask::len  (zkp-core/src/sumcheck.rs:190)"""
    return n_vars * degree + 2


# ===========================================================================
# 1.  THE SAMPLER  (memo A-12, A-13, A-14)
# ===========================================================================
head("1.  THE SAMPLER: reduction bias in distance form and in event form")
N128 = 1 << 128
k_ = N128 // P
r_ = N128 - k_ * P
tv = F(r_ * (P - r_), P * N128)
rej = F(r_, N128)
print(f"  p                = {P}")
print(f"  r = N - kp       = {r_}")
print(f"  p - r            = {P - r_}   (= 2^32? {P - r_ == 1 << 32})")
print(f"  TV(real,uniform) = 2^{math.log2(float(tv)):.10f}")
print(f"  Pr[reject region]= 2^{math.log2(float(rej)):.10f}")
check("A-12  p - r == 2^32", P - r_, 1 << 32)
check("A-12  TV rounds to 2^-96.0000000003",
      f"{math.log2(float(tv)):.10f}", "-96.0000000003")
check("A-12  Pr[rej] rounds to 2^-64.0000000007",
      f"{math.log2(float(rej)):.10f}", "-64.0000000007")
check("A-13  criterion 2(p-r) < p  (distance form wins)", 2 * (P - r_) < P, True)
print(f"  gap between the two forms = {-math.log2(float(rej)) - (-math.log2(float(tv))):.6f} bits"
      "   (memo A-14 says 32.0)")

# A-13's optimality: no coupling with an exactly-uniform good event beats r/N.
# brute force on small analogues: min over v of Pr[X=v] is k/N, so Pr[bad] >= 1 - p*k/N = r/N.
print("\n  A-13 optimality, brute force on small (p, N):")
for pp, NN in [(5, 16), (7, 32), (11, 64), (13, 128), (5, 1024), (17, 256)]:
    kk = NN // pp
    rr = NN - kk * pp
    counts = [0] * pp
    for v in range(NN):
        counts[v % pp] += 1
    c_max = F(min(counts), NN)                 # the largest constant a uniform good event allows
    bad_min = 1 - pp * c_max
    print(f"    p={pp:>3} N={NN:>5}:  min_v Pr[X=v] = {min(counts)}/{NN},"
          f"  best Pr[bad] = {bad_min} = r/N = {F(rr, NN)}"
          f"   {'OK' if bad_min == F(rr, NN) else 'MISMATCH'}")
    if bad_min != F(rr, NN):
        FAILS.append(f"A-13 small case p={pp} N={NN}")
    # and the criterion is NOT universal
    tvs = F(rr * (pp - rr), pp * NN)
    if pp == 5 and NN == 16:
        check("A-13  p=5,N=16 is a case where the EVENT form is smaller",
              2 * tvs > F(rr, NN), True)

for n, lbl in [(327052, "toy, D9's draw count"), (109728784, "125M run L=12, ruling H-6")]:
    print(f"  {lbl:<34} N = {n:>12,}   N*TV = 2^{math.log2(n * float(tv)):.4f}"
          f"   N*Pr[rej] = 2^{math.log2(n * float(rej)):.4f}")


# ===========================================================================
# 2.  THE BLOCK BODY'S STREAM SEGMENTS
# ===========================================================================
def block_body_segments(name):
    s = SHAPES[name]
    n = 1 << s["log_cols"]
    nn = n * s["inv_rate"]
    Q = s["Q"]
    sum_ls = sum(cfs_len(a, b) for a, b in MASK_SPECS[name])
    segs = [
        ("1  A mask + proximity rows", "fp", (s["a_rows"] - s["a_mask"]) * n, "protocol.rs:655-657"),
        ("2  A pads",                  "fp", s["a_rows"] * Q,                 "zkp-core/pcs.rs:777"),
        ("3  A salts",                 "salt", nn,                            "zkp-core/pcs.rs:778"),
        ("4  M CFS mask coefficients", "fp", 2 * sum_ls,                      "zk.rs:485 -> sumcheck.rs:201"),
        ("5  M per-row pads",          "fp", 2 * N_SLOTS * MASK_Q,            "zk.rs:496"),
        ("6  M b_re,b_im,u_re,u_im",   "fp", 4 * 2 * MASK_M,                  "zk.rs:503-508"),
        ("7  M salts",                 "salt", MASK_DOM,                      "zk.rs:513"),
        ("8  H mask + proximity rows", "fp", (s["h_rows"] - s["h_mask"]) * n, "protocol.rs:757-759"),
        ("9  H zero-sum rows",         "fp", 2 * (n - 1),                     "protocol.rs:760-768"),
        ("10 H pads",                  "fp", s["h_rows"] * Q,                 "zkp-core/pcs.rs:777"),
        ("11 H salts",                 "salt", nn,                            "zkp-core/pcs.rs:778"),
    ]
    return segs, sum_ls


def totals(segs):
    fp = sum(c for _, k, c, _ in segs if k == "fp")
    salt = sum(c for _, k, c, _ in segs if k == "salt")
    return fp, salt, fp * BYTES_PER_FP + salt * BYTES_PER_SALT


head("2.  THE BLOCK BODY: eleven segments, rebuilt from shape/layout constants")
BODY = {}
for name in SHAPES:
    segs, sum_ls = block_body_segments(name)
    fp, salt, by = totals(segs)
    BODY[name] = (fp, salt, by)
    n = 1 << SHAPES[name]["log_cols"]
    print(f"\n  --- {name}  (n = {n:,}, sum L_s = {sum_ls:,}) ---")
    off = 0
    for lbl, kind, cnt, site in segs:
        w = BYTES_PER_FP if kind == "fp" else BYTES_PER_SALT
        print(f"    {lbl:<30} {kind:<5} {cnt:>12,}   [{off:>13,} .. {off + cnt * w:>13,})   {site}")
        off += cnt * w
    print(f"    TOTAL fp {fp:,}   salts {salt:,}   bytes {by:,}")

check("A-5  toy fp draws", BODY["toy"][0], 320908)
check("A-5  rung fp draws", BODY["rung"][0], 687028)
check("A-5  rung-G fp draws", BODY["rung-G"][0], 687028)
check("A-5  rung-K4 fp draws", BODY["rung-K4"][0], 750540)
check("A-5  125M fp draws", BODY["125M"][0], 9029804)
check("A-5  toy stream bytes", BODY["toy"][2], 5396672)
check("A-5  125M stream bytes", BODY["125M"][2], 148802240)


# ===========================================================================
# 3.  ENDPOINTS, BOUNDARIES, RUNS
# ===========================================================================
def seam_endpoint(name):
    """private_seam::prepare_with_rng  (:200-223) then pcs::commit_zk_owned (:215)."""
    s = SHAPES[name]
    n = 1 << SEAM_LOG_COLS
    nn = n * SEAM_INV_RATE
    rows = s["e_rows"]
    fp = SEAM_MASK_ROWS * n + rows * s["Q"]
    return fp, nn, fp * BYTES_PER_FP + nn * BYTES_PER_SALT


def general_endpoint(name):
    """endpoint_g::prepare (:219-239): own generator, 5 mask rows, then pads+salts."""
    s = SHAPES[name]
    n = 1 << s["e_log_n"]
    nn = n * s["e_rate"]
    rows = s["e_rows"]
    fp = ENDPOINT_G_MASK_ROWS * n + rows * s["Q"]
    return fp, nn, fp * BYTES_PER_FP + nn * BYTES_PER_SALT


def boundary(name):
    """boundary::prepare (:315-332) on the CALLER's generator.
       commitment_rows = data_rows + 2*sites + 2 ; mask budget = 2*sites+2 rows."""
    s = SHAPES[name]
    n = 1 << s["e_log_n"]
    nn = n * s["e_rate"]
    rows = s["e_rows"] + 1                      # run.rs:211-217 declares endpoint_rows + 1
    mask_rows = 2 * BOUNDARY_SITES + 2
    fp = mask_rows * n + rows * s["Q"]
    return fp, nn, fp * BYTES_PER_FP + nn * BYTES_PER_SALT


head("3.  ENDPOINTS, BOUNDARIES AND THE RUN TOTALS  (memo A-5, A-6, A-7)")
efp, esalt, eby = seam_endpoint("toy")
print(f"  toy frozen-seam endpoint   : {efp:,} fp, {esalt:,} salts, {eby:,} bytes  (own generator)")
check("A-5  toy proof total fp = D9's 327,052", BODY["toy"][0] + 2 * efp, 327052)

for name in ("rung-G", "rung-K4", "125M"):
    bfp, bsalt, bby = boundary(name)
    gfp, gsalt, gby = general_endpoint(name)
    print(f"\n  {name}: boundary {bfp:,} fp / {bsalt:,} salts ;"
          f" generalised endpoint {gfp:,} fp / {gsalt:,} salts")
    for L in ((3,) if name != "125M" else (12,)):
        run_fp = L * BODY[name][0] + (L - 1) * bfp
        run_salt = L * BODY[name][1] + (L - 1) * bsalt
        run_by = run_fp * BYTES_PER_FP + run_salt * BYTES_PER_SALT
        tot = run_fp + 2 * gfp
        ncom = 4 * L + 1
        shared = 3 * L + (L - 1)
        print(f"    L={L}: run stream {run_fp:,} fp, {run_salt:,} salts, {run_by:,} bytes;"
              f"  + 2 endpoints -> {tot:,} fp")
        print(f"          commitments {ncom}, of which {shared} share the one run stream"
              f"  -> C({shared},2) = {shared * (shared - 1) // 2:,} pairs rest on M-3")
        if name == "125M" and L == 12:
            check("A-7  125M L=12 run-stream fp draws", run_fp, 109546000)
            check("A-7  125M L=12 run-stream salt draws", run_salt, 2342912)
            check("A-7  125M L=12 run-stream bytes", run_by, 1827709184)
            check("A-7  125M L=12 total fp = ruling H-6's", tot, 109728784)
            check("A-11 C(47,2) pairs on one stream", shared * (shared - 1) // 2, 1081)
        if name == "rung-G" and L == 3:
            check("A-7  rung-G L=3 total fp = ruling H-6's", tot, 2093340)
        if name == "rung-K4" and L == 3:
            check("A-7  rung-K4 L=3 total fp = ruling H-6's", tot, 2283876)


# ===========================================================================
# 4.  THE FLAG'S PRICE  (memo A-16, A-17 against Lemma H)
# ===========================================================================
head("4.  THE FLAG'S PRICE: what Lemma H states against what A-17 carries")
N_LEAF = 12288          # toy: 2048(A) + 4096(M) + 2048(H) + 2*2048(endpoints)
N_NODE = 12283          # 4 x 2047 + 4095
N_OVERLAP = N_LEAF + N_NODE
check("Lemma H's toy N_leaf", 2048 + 4096 + 2048 + 2 * 2048, N_LEAF)
check("Lemma H's toy N_node", 4 * 2047 + 4095, N_NODE)
check("Lemma H's toy N_overlap (leaf+node 64-byte objects)", N_OVERLAP, 24571)
t2 = F(N_LEAF * (N_LEAF - 1) // 2, 1 << 256)
t3 = F(N_OVERLAP, 1 << 256)
t4 = F(N_NODE * N_LEAF, 1 << 512)
print(f"  C(N_leaf,2) * 2^-256          = 2^{math.log2(float(t2)):.4f}   (the memo's 2^-229.8)")
print(f"  N_overlap  * 2^-256           = 2^{math.log2(float(t3)):.4f}   (the 2^-241.42 row)")
print(f"  N_node*N_leaf * 2^-512        = 2^{math.log2(float(t4)):.4f}   (correction C-4)")
print("  q * N_leaf * 2^-256           = q * 2^{:.4f}".format(math.log2(float(F(N_LEAF, 1 << 256)))))
check("2^-229.83 reproduces", f"{math.log2(float(t2)):.2f}", "-229.83")
check("2^-241.42 reproduces", f"{math.log2(float(t3)):.2f}", "-241.42")
check("2^-484.83 reproduces", f"{math.log2(float(t4)):.2f}", "-484.83")
q_break = float(t2) / float(F(N_LEAF, 1 << 256))
print(f"\n  The q-term overtakes the collision term at q = {q_break:,.0f} = 2^{math.log2(q_break):.2f}.")
print("  => pricing the flag at 2^-229.8 is right only for an adversary making")
print(f"     fewer than 2^{math.log2(q_break):.1f} oracle queries.  [FINDING]")
print("  The memo's stated MECHANISM for 2^-241.42 ('a digest must spell 24 fixed")
print("  bytes') would give 2^-192 per pair, not 2^-241.42; the figure of record")
print("  comes from the 32-byte SALT being uniform, counted over 24,571 objects:")
print(f"     24 fixed bytes           -> 2^-{8*24} per pair")
print(f"     32 uniform salt bytes x {N_OVERLAP} objects -> 2^{math.log2(float(t3)):.4f}")


# ===========================================================================
# 5.  EVERY BLAKE3 INPUT LENGTH, PER PROFILE
# ===========================================================================
ABSORB_FIXED = 48       # state(32) + le64(|label|) + le64(|data|)   transcript.rs:61-67
SQUEEZE = 32 + 7 + 8    # transcript.rs:103-106
REFILL = 32 + 8         # rng.rs:54-56
NODE = 64               # merkle.rs:15 ; pcs.rs:678
SEED_PREFIX = 22        # rng.rs:48  b"hashline-zk-os-rng/v1/"
DOM_ENDPOINT_G, DOM_BOUNDARY, DOM_SEAM = 42, 43, 28
D_CALIB, D_PUBLIC, D_SCHED = 30, 31, 33
D_RUN_PUB, D_RUN_SCHED = 29, 31
SPEC_SEAM, SPEC_ENDPOINT_G, SPEC_BOUNDARY = 128, 142, 151

check("seam spec digest  = DOMAIN(28)+ctx(32)+8*u64+i32", 28 + 32 + 64 + 4, SPEC_SEAM)
check("general endpoint spec = DOMAIN(42)+ctx(32)+8*u64+i32", 42 + 32 + 64 + 4, SPEC_ENDPOINT_G)
check("internal boundary spec = DOMAIN(43)+ctx(32)+9*u64+i32", 43 + 32 + 72 + 4, SPEC_BOUNDARY)


def absorb(label, data_len):
    return ABSORB_FIXED + len(label) + data_len


def inputs_for(name, L=None):
    """Return {family: {length: [descriptions]}} for one profile.
       L=None is a single block; L>=2 is that shape's run."""
    s = SHAPES[name]
    n = 1 << s["log_cols"]
    nn = n * s["inv_rate"]
    en = 1 << s["e_log_n"]
    Q = s["Q"]
    legacy = s["legacy"]
    is_run = L is not None

    FT = "F_T transcript" if not legacy else "F_U unkeyed"
    FC = "F_C column" if not legacy else "F_U unkeyed"
    FL = "F_L leaf" if not legacy else "F_U unkeyed"
    FN = "F_N node" if not legacy else "F_U unkeyed"
    FU = "F_U unkeyed"
    FK = "keyed under secret OS entropy"

    out = {}

    def add(fam, ln, what):
        out.setdefault(fam, {}).setdefault(ln, [])
        if what not in out[fam][ln]:
            out[fam][ln].append(what)

    prof_len = RUN_PROFILE_LEN[name] if is_run else s["profile_len"]
    add(FT, 12 + prof_len, f"transcript constructor (profile {prof_len} B)")
    add(FT, SQUEEZE, "transcript squeeze / position tag / refusal replay")

    # the header absorbs
    add(FT, absorb(b"expected-IO", EXPECTED_BYTES), "absorb `expected-IO`")
    add(FT, absorb(b"public-statement", 32), "absorb `public-statement`")
    add(FT, absorb(b"calibration", 32), "absorb `calibration`")
    add(FT, absorb(b"schedule", 32), "absorb `schedule`")
    if is_run:
        add(FT, absorb(b"run-shape", 7 * 8), "absorb `run-shape`")
        pl = {"rung-G": 236, "rung-K4": 236, "125M": 242}[name]
        pl += 1 if 2 <= L <= 9 else (2 if L >= 10 else 0)
        pl += PARAM_LINE_LEN[name] - (152 if name != "125M" else 157) + \
              (152 if name != "125M" else 157)   # base already inside
        pl = {"rung-G": 236, "rung-K4": 236, "125M": 242}[name] + \
             (0 if L == 1 else (1 if L <= 9 else 2))
        add(FT, absorb(b"parameters", pl), f"absorb `parameters` (run line, L={L}, {pl} B)")
        add(FT, absorb(b"pb-run-stage", 8), "absorb `pb-run-stage`")
        add(FT, absorb(b"pb-run-block", 32), "absorb `pb-run-block`")
        add(FT, absorb(b"B", 32), "absorb root `B`")
    else:
        add(FT, absorb(b"parameters", PARAM_LINE_LEN[name]), "absorb `parameters` (block line)")

    for lab in (b"A", b"H", b"M"):
        add(FT, absorb(lab, 32), f"absorb root `{lab.decode()}`")
    add(FT, absorb(b"rows", 8), "absorb `rows`")
    add(FT, absorb(b"log-cols", 8), "absorb `log-cols`")
    add(FT, absorb(b"pb-slot", 8), "absorb `pb-slot`")
    add(FT, absorb(b"pb-scalar", 16), "absorb `pb-scalar`")
    for d in range(DEGREE_LO, DEGREE_HI + 1):
        add(FT, absorb(b"sc-round", 16 * (d + 1)), f"absorb `sc-round` (degree {d})")
    for k in sorted(set(SLOT_TERMS[name])):
        add(FT, absorb(b"pb-term", 16 * k), f"absorb `pb-term` ({k} terminals)")
    add(FT, absorb(b"mask-q", 16 * 2 * MASK_M), "absorb `mask-q`")
    add(FT, absorb(b"mask-prox", 16 * 2 * MASK_M), "absorb `mask-prox`")
    for v in sorted({16 * (n + Q), 16 * (en + Q)}):
        add(FT, absorb(b"pcs-vec", v), f"absorb `pcs-vec` ({v} B data)")
        add(FT, absorb(b"pcs-prox", v), f"absorb `pcs-prox` ({v} B data)")

    # column digests
    add(FC, 8 * s["a_rows"], f"column digest A ({s['a_rows']} rows)")
    add(FC, 8 * s["h_rows"], f"column digest H ({s['h_rows']} rows)")
    add(FC, 8 * M_ROWS, f"column digest M ({M_ROWS} rows)")
    add(FC, 8 * s["e_rows"], f"column digest endpoint ({s['e_rows']} rows)")
    if is_run:
        add(FC, 8 * (s["e_rows"] + 1), f"column digest boundary ({s['e_rows'] + 1} rows)")

    add(FL, NODE, "salted leaf")
    add(FN, NODE, "Merkle inner node")

    # unkeyed statement digests + the generator refill (always F_U)
    add(FU, REFILL, "generator refill block")
    add(FU, D_CALIB, "calibration identity (private_block.rs:222)")
    add(FU, SPEC_SEAM if s["endpoint"] == "seam" else SPEC_ENDPOINT_G,
        "frozen-seam spec digest" if s["endpoint"] == "seam" else "general endpoint spec digest")
    if is_run:
        add(FU, SPEC_BOUNDARY, "internal boundary spec digest (boundary.rs:211)")
        add(FU, D_RUN_PUB + 32 * L, f"run public statement (L={L})")

    # the OS seed derivations (keyed, secret key)
    add(FK, SEED_PREFIX + prof_len, f"seed derivation, {'run' if is_run else 'block'} prover")
    if s["endpoint"] == "seam":
        add(FK, SEED_PREFIX + DOM_SEAM, "seed derivation, frozen-seam endpoint")
    else:
        add(FK, SEED_PREFIX + DOM_ENDPOINT_G, "seed derivation, generalised endpoint")
    return out


head("5.  EVERY BLAKE3 INPUT LENGTH, PER PROFILE -- all clashes, mine, not the memo's")
PROFILES = [("toy", None), ("rung", None), ("rung-G", None), ("rung-K4", None), ("125M", None),
            ("rung-G", 3), ("rung-K4", 3), ("125M", 12)]
found = {}
for name, L in PROFILES:
    tab = inputs_for(name, L)
    tag = f"{name}" + (f" run L={L}" if L else " single block")
    print(f"\n  --- {tag}  ({'legacy' if SHAPES[name]['legacy'] else 'tagged'}) ---")
    # within-family clashes
    for fam in sorted(tab):
        for ln, whats in sorted(tab[fam].items()):
            if len(whats) > 1:
                print(f"    WITHIN {fam:<18} {ln:>7} B : " + " | ".join(whats))
                found.setdefault(tag, []).append((fam, ln, tuple(whats)))
    # cross-family coincidences
    fams = sorted(tab)
    for fa, fb in combinations(fams, 2):
        for ln in sorted(set(tab[fa]) & set(tab[fb])):
            print(f"    CROSS  {fa} / {fb}  {ln:>7} B : "
                  f"{'; '.join(tab[fa][ln])}  <->  {'; '.join(tab[fb][ln])}")
    # nearest margins over the whole profile
    everything = {}
    for fam in tab:
        for ln, whats in tab[fam].items():
            everything.setdefault(ln, []).extend(f"{w} [{fam}]" for w in whats)
    ks = sorted(everything)
    margins = sorted(((ks[i + 1] - ks[i], ks[i], ks[i + 1]) for i in range(len(ks) - 1)))[:3]
    for d, a, b in margins:
        if d <= 2:
            print(f"    MARGIN {d} B : {a} ({everything[a][0]})  vs  {b} ({everything[b][0]})")

print("\n  The toy's four legacy clashes the memo names (64, 81, 151, 171):")
toy = inputs_for("toy", None)
toyU = toy["F_U unkeyed"]
for ln in (64, 81, 151, 171):
    print(f"    {ln:>4} B -> {toyU.get(ln, 'NOT PRESENT in my toy set')}")
check("toy: 171 B is a real clash (expected-IO vs parameters)",
      len(toyU.get(171, [])) >= 2, True)
check("toy: 151 B (pb-term(6)) has NO boundary digest beside it (the toy has no boundary)",
      len(toyU.get(151, [])), 1)


# ===========================================================================
# 6.  IS A SIX-TERMINAL `pb-term` ABSORB REACHABLE?  (memo GAP-QC-4 / W-6)
# ===========================================================================
head("6.  `pb-term` terminal counts per shape (memo left this [UNVERIFIED])")
for name in SHAPES:
    st = SLOT_TERMS[name]
    lens = sorted({55 + 16 * k for k in set(st)})
    six = [i for i, k in enumerate(st) if k == 6]
    print(f"  {name:<8} distinct terminal counts {sorted(set(st))}")
    print(f"           absorb lengths           {lens}")
    print(f"           slots with SIX terminals: {six}  -> 151-byte absorb "
          f"{'EXISTS' if six else 'does not exist'}")
    check(f"{name}: a six-terminal pb-term absorb exists (slot 19 = SC_TAB)", bool(six), True)
    for k in set(st):
        if (55 + 16 * k) % 8 == 0:
            FAILS.append(f"{name}: pb-term length divisible by 8")
print("  55 + 16k = 7 mod 16 for every k, and a column digest is 0 mod 8,")
print("  so no pb-term absorb can equal a column digest at any shape.  [PROVED]")
check("pb-term lengths are 7 mod 16 for k in 1..64",
      all((55 + 16 * k) % 16 == 7 for k in range(1, 65)), True)


# ===========================================================================
# 7.  THE TWO COUNTEREXAMPLES, REIMPLEMENTED
# ===========================================================================
head("7.  THE TWO COUNTEREXAMPLES, reimplemented from scratch (mod q = 101)")
Q101 = 101


def rowspace_rank(rows, q):
    """rank over GF(q) of the given rows"""
    rows = [list(r) for r in rows]
    R, C = len(rows), len(rows[0]) if rows else 0
    r = 0
    for c in range(C):
        piv = next((i for i in range(r, R) if rows[i][c] % q), None)
        if piv is None:
            continue
        rows[r], rows[piv] = rows[piv], rows[r]
        inv = pow(rows[r][c], q - 2, q)
        rows[r] = [(x * inv) % q for x in rows[r]]
        for i in range(R):
            if i != r and rows[i][c] % q:
                f = rows[i][c]
                rows[i] = [(a - f * b) % q for a, b in zip(rows[i], rows[r])]
        r += 1
        if r == R:
            break
    return r


def lcg(seed):
    s = seed
    while True:
        s = (1103515245 * s + 12345) % (1 << 31)
        yield s % Q101


print("  (i) a SHARED blinding row: two claim sites, three published coordinates each.")
for seed in (1, 2, 3, 5, 8, 13):
    g = lcg(seed)
    w = [next(g) for _ in range(3)]
    wp = [(x + 1 + next(g) % 7) % Q101 for x in w]
    M0 = [[next(g) for _ in range(3)] for _ in range(3)]
    M1 = [[next(g) for _ in range(3)] for _ in range(3)]
    b0 = [next(g) for _ in range(3)]
    b1 = [next(g) for _ in range(3)]
    def view(M, w, b):
        return [(sum(M[i][j] * w[j] for j in range(3)) + b[i]) % Q101 for i in range(3)]
    # independent rows: the 6 published values are a function of (w, b0, b1); the
    # blinding coordinates span all 6 -> disclosed dimension 0.
    ind = rowspace_rank([[1 if i == j else 0 for j in range(6)] for i in range(6)], Q101)
    # shared row: b1 = b0 -> the blinding spans only 3 of the 6 coordinates
    shared_span = [[1 if (i == j or i + 3 == j) else 0 for j in range(6)] for i in range(3)]
    disclosed_shared = 6 - rowspace_rank(shared_span, Q101)
    v0, v1 = view(M0, w, b0), view(M1, w, b0)
    d = [(a - b) % Q101 for a, b in zip(v0, v1)]
    v0p, v1p = view(M0, wp, b0), view(M1, wp, b0)
    dp = [(a - b) % Q101 for a, b in zip(v0p, v1p)]
    sep = d != dp
    if seed == 1:
        print(f"      disclosed dim, independent rows = {6 - ind}")
    ok = (6 - ind == 0) and disclosed_shared == 3 and sep
    print(f"      seed {seed:>2}: disclosed(independent)=0  disclosed(shared)={disclosed_shared}"
          f"  (M0-M1)w separates two witnesses: {sep}   {'OK' if ok else 'FAIL'}")
    if not ok:
        FAILS.append(f"counterexample (i) seed {seed}")

print("\n  (ii) ruling R-3: two DISTINCT rows at DISJOINT positions whose VALUES coincide.")
for seed in (1, 2, 3, 5, 8, 13):
    g = lcg(seed + 100)
    w = [next(g) for _ in range(3)]
    wp = [(x + 1 + next(g) % 7) % Q101 for x in w]
    M0 = [[next(g) for _ in range(3)] for _ in range(3)]
    M1 = [[next(g) for _ in range(3)] for _ in range(3)]
    b = [next(g) for _ in range(3)]          # the realised coincidence: b0 == b1 == b
    # the GATE reads the STRUCTURE: two distinct symbols, disjoint positions -> rank 6
    gate_rank = rowspace_rank([[1 if i == j else 0 for j in range(6)] for i in range(6)], Q101)
    gate_disclosed = 6 - gate_rank
    def view(M):
        return [(sum(M[i][j] * w[j] for j in range(3)) + b[i]) % Q101 for i in range(3)]
    d = [(a - c) % Q101 for a, c in zip(view(M0), view(M1))]
    want = [(sum((M0[i][j] - M1[i][j]) * w[j] for j in range(3))) % Q101 for i in range(3)]
    leaks = d == want
    def viewp(M):
        return [(sum(M[i][j] * wp[j] for j in range(3)) + b[i]) % Q101 for i in range(3)]
    dp = [(a - c) % Q101 for a, c in zip(viewp(M0), viewp(M1))]
    sep = d != dp
    ok = gate_disclosed == 0 and leaks and sep
    print(f"      seed {seed:>2}: gate disclosed = {gate_disclosed}; realised view determines"
          f" (M0-M1).w: {leaks}; separated: {sep}   {'OK' if ok else 'FAIL'}")
    if not ok:
        FAILS.append(f"counterexample (ii) seed {seed}")

print("\n  Pricing: an ACCIDENT at the real geometry (a blinding row is 256 Goldilocks words):")
print(f"      p^-256 = 2^{-256 * math.log2(P):.1f}")
print("  A BROKEN DRAW DISCIPLINE has probability ONE and is invisible to a rank gate.")
print("  Memo's five owed assertions are all about POSITIONS.  The two defects below")
print("  keep every position disjoint and still correlate the realised VALUES:")
print("    (d1) `b_re[m] := -b_re[0]` (zk.rs:505-506): two drawn words at DISJOINT")
print("         positions, one discarded, and the committed row carries a deterministic")
print("         linear relation.  Assertions 1-5 all pass.  It is in the code today.")
print("    (d2) a generator constructed from a DETERMINISTIC seed on a production path")
print("         (`ZkRng::new`, rng.rs:20; reachable through `ZkConfig::rng`, zk.rs:334-337)")
print("         -- one generator, never cloned, correct offsets, and every proof identical.")
print("  => a SIXTH assertion is owed, about the realised value map, not the positions.")

head("RESULT")
if FAILS:
    print("  FAILURES:")
    for f in FAILS:
        print("   -", f)
    raise SystemExit(1)
print("  ALL ASSERTIONS PASSED.")
