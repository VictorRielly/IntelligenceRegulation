#!/usr/bin/env python3
"""Independent recount of every [COUNTED] figure in
docs/zkmatrix-poc/ZK60_JOINT_LAW_COMPOSITION_RUN.md.

Written from the LANE SOURCE at /home/victor/wt-zk60-block125m, tip caa9b9a,
NOT from the memo's own script (results/zk60_joint_law_composition_run/).
Exact integer arithmetic; floats only for the final log2 report.

Every shape constant below is transcribed from one named source line.
"""

from fractions import Fraction
import math

P = 0xFFFF_FFFF_0000_0001            # zkp-core/src/field.rs:10
FP2 = P * P                          # |Fp2|
MASK_Q = 256                         # hashline/src/zk.rs:375
M_A_ROWS = 46                        # 2 * 23 slots
M_BU_ROWS = 4                        # b_re, b_im, u_re, u_im
MASK_M = 1 << 9                      # zk.rs:373 MASK_LOG_MSG
MASK_DOM = 1 << 12                   # zk.rs:374 MASK_LOG_DOM


# ---------------------------------------------------------------- shapes
# a_rows / h_rows / data rows / sites / groups / round counts / slot length:
# hashline/src/private_block/grow_tests.rs, MODEL_TOY / MODEL_RUNG /
# MODEL_M125 (the lane's own frozen acceptance constants).
SHAPES = {
    "toy": dict(
        log_cols=8, a_rows=None, h_rows=None,           # not needed below
        a_data=None, h_data=None,
        a_sites=None, h_sites=None, a_groups=None, h_groups=None,
        main=None, ext=None, sum_L=583, largest_L=50,
        u8_lookups=61_440, exp_pairs=2_048, act_pairs=512, tab=256,
        endpoint_rows=7, endpoint_log_n=8,
    ),
    "rung-G": dict(
        log_cols=10, a_rows=623, h_rows=576, a_data=377, h_data=470,
        a_sites=122, h_sites=52, a_groups=36, h_groups=9,
        main=215, ext=25, sum_L=840, largest_L=72,
        u8_lookups=419_840, exp_pairs=8_192, act_pairs=8_192, tab=1 << 10,
        endpoint_rows=9, endpoint_log_n=10,
    ),
    "125M": dict(
        log_cols=14, a_rows=5_681, h_rows=7_120, a_data=5_435, h_data=7_018,
        a_sites=122, h_sites=50, a_groups=36, h_groups=9,
        main=332, ext=25, sum_L=1_208, largest_L=117,
        u8_lookups=98_598_912, exp_pairs=4_194_304, act_pairs=1_048_576,
        tab=1 << 14, endpoint_rows=37, endpoint_log_n=14,
    ),
}


def bits(x):
    """log2 of a positive rational/int."""
    return math.log2(float(x))


def neg_log2_prob(count, space):
    return bits(space) - bits(count)


# ------------------------------------------------- 1. prover draw counts
# pcs commit: pads = rng.fp_vec(rows * q)      hashline/src/pcs.rs:90
#             salts = nn * bytes32 (raw bytes, no reduction -> not in D9)
# mask rows:  (rows - data) * n                protocol.rs:655, :757, boundary.rs:324
# H zero-sum: 2 * (n - 1) EXTRA, on top of the blanket mask fill
#                                              protocol.rs:760-768
# M:          2*sum_L coefficients + 46*256 pads + 4*1024 b/u   zk.rs:485-508
def commitment_draws(rows, data_rows, n, q=MASK_Q):
    return (rows - data_rows) * n + rows * q


def mask_commit_draws(sum_L):
    return 2 * sum_L + M_A_ROWS * MASK_Q + M_BU_ROWS * (2 * MASK_M)


def block_draws(s):
    n = 1 << s["log_cols"]
    a = commitment_draws(s["a_rows"], s["a_data"], n)
    h = commitment_draws(s["h_rows"], s["h_data"], n)
    m = mask_commit_draws(s["sum_L"])
    zsum = 2 * (n - 1)
    return a + h + m + zsum, dict(A=a, H=h, M=m, zero_sum=zsum)


def boundary_draws(s):
    n = 1 << s["endpoint_log_n"]
    data = s["endpoint_rows"] - 5
    rows = data + 2 * 2 + 2                     # boundary.rs:180-182
    return commitment_draws(rows, data, n), rows


def endpoint_draws(s):
    n = 1 << s["endpoint_log_n"]
    data = s["endpoint_rows"] - 5               # endpoint_g.rs:52 MASK_ROWS
    return commitment_draws(s["endpoint_rows"], data, n)


def salt_draws(s, L):
    """bytes32 calls; RAW BYTES, no reduction bias (D9 excludes them)."""
    n = 1 << s["log_cols"]
    nn = n * 4                                   # inv_rate 4
    en = (1 << s["endpoint_log_n"]) * 4
    per_block = nn + nn + MASK_DOM               # A, H, M
    return L * per_block + (L - 1) * en + 2 * en


# ------------------------------------------------- 2. published field words
def stage_words(s, kind):
    """base-field words (an Fp2 counts twice) published by one stage."""
    n = 1 << s["log_cols"]
    en = 1 << s["endpoint_log_n"]
    rounds = s["main"] + s["ext"]
    # sum_s (n_s+e_s)(d_s+1) = sum_s L_s - 2*23 + rounds
    round_fp2 = (s["sum_L"] - 2 * 23) + rounds
    terminals = s["a_sites"] + s["h_sites"] + 2
    w = 2 * 23                                   # 23 masked scalars
    w += 2 * round_fp2
    w += 2 * terminals
    w += 2 * (2 * 1024) + MASK_Q * 50            # M: q + prox, 256 cols x 50 rows
    w += 2 * (s["a_groups"] + 1) * (n + MASK_Q) + MASK_Q * s["a_rows"]
    w += 2 * (s["h_groups"] + 1) * (n + MASK_Q) + MASK_Q * s["h_rows"]
    return w, round_fp2, terminals


def boundary_words(s):
    en = 1 << s["endpoint_log_n"]
    _, rows = boundary_draws(s)
    return 2 * 3 * (en + MASK_Q) + MASK_Q * rows


def endpoint_words(s):
    en = 1 << s["endpoint_log_n"]
    return 2 * 2 * (en + MASK_Q) + MASK_Q * s["endpoint_rows"]


# ------------------------------------------------- 3. LogUp denominators
def logup_denominators(s):
    """every value handed to `inverses()` in protocol.rs:691, :702, :704, :734"""
    return s["u8_lookups"] + s["exp_pairs"] + s["act_pairs"] + 3 * s["tab"]


# ------------------------------------------------- report
def main():
    print("=" * 72)
    print("INDEPENDENT RECOUNT — ZK60_JOINT_LAW_COMPOSITION_RUN.md")
    print("p = 2^64 - 2^32 + 1 =", P, " |Fp2| = p^2")
    print("=" * 72)

    print("\n-- 1. sampler draws (D9: every fp() draw, 2^-96 each) ------------")
    for name in ("rung-G", "125M"):
        s = SHAPES[name]
        blk, parts = block_draws(s)
        bnd, brows = boundary_draws(s)
        ep = endpoint_draws(s)
        print(f"{name}: block {blk:,}  {parts}")
        print(f"{name}: boundary ({brows} rows) {bnd:,}   external endpoint {ep:,}")
        for L in (3, 12):
            tot = L * blk + (L - 1) * bnd + 2 * ep
            print(f"   L={L:2d}: {tot:,} draws -> residual 2^-{96 - bits(tot):.2f}")
        print(f"   salts (raw bytes, excluded from D9) L=12: {salt_draws(s, 12):,}")
    # toy cross-check of the METHOD against the published 327,052 / 2^-77.7
    print("   toy published control: 327,052 draws -> 2^-%.1f" % (96 - bits(327052)))

    print("\n-- 2. published field words --------------------------------------")
    for name, L in (("rung-G", 3), ("125M", 12)):
        s = SHAPES[name]
        sw, rf, tm = stage_words(s, name)
        bw, ew = boundary_words(s), endpoint_words(s)
        tot = L * sw + (L - 1) * bw + 2 * ew
        print(f"{name}: round Fp2/stage {rf:,}  terminals/stage {tm}  "
              f"stage words {sw:,}")
        print(f"   L={L}: {tot:,} base-field words = {tot*8:,} B")

    print("\n-- 3. LogUp denominators / the one input-dependent refusal -------")
    for name in ("toy", "rung-G", "125M"):
        s = SHAPES[name]
        d = logup_denominators(s)
        line = f"{name}: {d:,} inverted -> per block 2^-{neg_log2_prob(d, FP2):.2f}"
        for L in (3, 12):
            line += f"   L={L}: 2^-{neg_log2_prob(L*d, FP2):.2f}"
        print(line)

    print("\n-- 4. challenge-only liveness = (3L+1) proximity determinants ----")
    for L in (1, 3, 12):
        k = 3 * L + 1 if L > 1 else 4
        print(f"   L={L:2d}: {k}/p -> 2^-{bits(P) - bits(k):.2f}")

    print("\n-- 4b. the toy control, EXACTLY (D9's accepted 327,052) ----------")
    # toy: log_cols 8, a_rows 455 / data 213, h_rows 384 / data 280,
    # sum_L 583, endpoint 7 rows / 2 data at log_n 8  (grow_tests MODEL_TOY)
    n = 256
    ta = commitment_draws(455, 213, n)
    th = commitment_draws(384, 280, n)
    tm = mask_commit_draws(583)
    tz = 2 * (n - 1)
    tep = commitment_draws(7, 2, n)
    tot = ta + th + tm + tz + 2 * tep
    print(f"   A {ta:,} + H {th:,} + M {tm:,} + H zero-sum {tz:,} "
          f"+ 2 endpoints {2*tep:,} = {tot:,}")
    print(f"   published / D9-accepted: 327,052   ->  "
          f"{'MATCH' if tot == 327_052 else 'MISMATCH'}")
    print("   (the H zero-sum term is REQUIRED to hit it: without it, "
          f"{tot - tz:,})")

    print("\n-- 4c. reconciling the 29,800-per-block delta at 125M ------------")
    s = SHAPES["125M"]
    mine, _ = block_draws(s)
    design = 8_999_942            # ZK60_PRIVATE_RUN_MULTI_BLOCK.md:1383
    zsum = 2 * ((1 << s["log_cols"]) - 1)
    bound = 2 * (23 * s["largest_L"] - s["sum_L"])   # sum_L bounded by 23*117
    print(f"   this recount (and the memo)            {mine:,}")
    print(f"   - H's zero-sum re-draw 2(n-1)          {-zsum:,}   "
          "(protocol.rs:760-768, omitted by the design)")
    print(f"   + M with sum_L bounded by 23*117       {+bound:,}   "
          "(RUN.md:1376-1378 says so in as many words)")
    print(f"   = the design memo's figure             "
          f"{mine - zsum + bound:,}   design says {design:,}   "
          f"{'MATCH' if mine - zsum + bound == design else 'MISMATCH'}")

    print("\n-- 5. degrees of freedom, per commitment -------------------------")
    for name in ("rung-G", "125M"):
        s = SHAPES[name]
        _, brows = boundary_draws(s)
        bdata = s["endpoint_rows"] - 5
        rows = [
            ("A", s["a_groups"], s["a_rows"] - s["a_data"]),
            ("H", s["h_groups"], s["h_rows"] - s["h_data"]),
            ("external endpoint", 1, 5),
            ("internal boundary", 2, brows - bdata),
        ]
        print(f"  {name}:")
        for r, g, free in rows:
            print(f"    {r:<20} G={g:<3} generators 2(G+1)={2*(g+1):<4} "
                  f"free non-data rows {free:<4} slack {free - 2*(g+1)}")


if __name__ == "__main__":
    main()
