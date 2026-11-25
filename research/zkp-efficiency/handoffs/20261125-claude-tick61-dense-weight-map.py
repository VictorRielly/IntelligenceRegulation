#!/usr/bin/env python3
"""Tick 61 (queue item 102): can a dense (true-words) weight commitment answer claims at padded-domain points.
Standard library only, reads no file. Two parts.
  A. a toy check, over the Goldilocks prime, that a layout which puts each axis's ODD factor on the ROW axis
     (one claim part per odd-factor combination, coefficient = the product of the eq values of the high bits)
     gives exactly the padded matrix's multilinear value, using the rule of zkp_core::pcs::zpart_weights
     (row weight = coef * eq(point[..lr])[r - r0]; column key = point tail) - zkp-core/src/pcs.rs:869-909.
  B. rows, claim parts and receipt bytes at n = 2^16 for both profiles, with the wire formula of tick 59
     (wire.rs:106-108): (G+1)(n+qpad)*16 + Q*(8 + 8*rows + 32 + 32*path), n=2^16, rate 1/4, k=16, Q'=172.
"""
import math, random, itertools

P = (1 << 64) - (1 << 32) + 1
random.seed(61)


def eq_table(point):                      # msb first, as eq_table_msb
    t = [1]
    for r in point:
        t = [y for x in t for y in (x * (1 - r) % P, x * r % P)]   # the first variable is the high bit
    return t


def mle(vals, point):                     # vals length 2^len(point), msb-first index
    t = eq_table(point)
    return sum(a * b for a, b in zip(vals, t)) % P


def zpart_value(M, n, offset, ls, coef, point, rows):
    """coef * MLE(slice)(point) computed as the PCS opening does: sum_r row_w[r] * <M_r, col_w> (ls >= log_cols)."""
    log_cols = n.bit_length() - 1
    lr = ls - log_cols
    r0 = offset // n
    assert offset % n == 0 and lr >= 0
    eq_r = eq_table(point[:lr])
    col_w = eq_table(point[lr:])
    tot = 0
    for i, e in enumerate(eq_r):
        row = M[r0 + i]
        tot += coef * e % P * (sum(a * b for a, b in zip(row, col_w)) % P)
    return tot % P


def toy(d_true, d_bits_low, f_true, f_bits_low, log_cols):
    """matrix (d_true x f_true) padded to (2^dl x 2^fl); odd factors d_true/2^d_bits_low and f_true/2^f_bits_low."""
    dl_low, fl_low = d_bits_low, f_bits_low
    d_odd, f_odd = d_true >> dl_low, f_true >> fl_low
    assert d_odd << dl_low == d_true and f_odd << fl_low == f_true
    d_hi_bits = max(1, (d_odd - 1).bit_length())
    f_hi_bits = max(1, (f_odd - 1).bit_length())
    dl, fl = d_hi_bits + dl_low, f_hi_bits + fl_low           # padded bit counts
    W = [[random.randrange(-127, 128) for _ in range(f_true)] for _ in range(d_true)]
    # padded multilinear value at a random point (zeros outside the true box)
    pt = [random.randrange(P) for _ in range(dl + fl)]
    flat = []
    for i in range(1 << dl):
        for j in range(1 << fl):
            flat.append(W[i][j] % P if i < d_true and j < f_true else 0)
    want = mle(flat, pt)
    # dense layout: one block per (i_hi, j_hi); inside a block coordinates (i_lo, j_lo) row-major; blocks consecutive
    block = 1 << (dl_low + fl_low)
    assert block >= (1 << log_cols) and block % (1 << log_cols) == 0
    dense = []
    for ih in range(d_odd):
        for jh in range(f_odd):
            for il in range(1 << dl_low):
                for jl in range(1 << fl_low):
                    dense.append(W[(ih << dl_low) | il][(jh << fl_low) | jl] % P)
    n = 1 << log_cols
    assert len(dense) == d_true * f_true and len(dense) % n == 0
    M = [dense[k:k + n] for k in range(0, len(dense), n)]
    r_i, r_j = pt[:dl], pt[dl:]
    eq_ih, eq_jh = eq_table(r_i[:d_hi_bits]), eq_table(r_j[:f_hi_bits])
    low_point = r_i[d_hi_bits:] + r_j[f_hi_bits:]             # the part's own coordinates (arity = block bits)
    got = 0
    parts = 0
    for ih in range(d_odd):
        for jh in range(f_odd):
            b = ih * f_odd + jh
            got += zpart_value(M, n, b * block, dl_low + fl_low, eq_ih[ih] * eq_jh[jh] % P, low_point, len(M))
            parts += 1
    got %= P
    return want == got, parts, len(M)


print("== A. toy check of the odd-factor-on-rows layout (zpart rule), n = 2^3 columns")
for (dt, dlow, ft, flow) in [(12, 2, 36, 2), (6, 1, 28, 2), (4, 2, 20, 2), (24, 3, 18, 1)]:
    ok, parts, rows = toy(dt, dlow, ft, flow, 3)
    print(f"  true {dt} x {ft} (low bits {dlow}, {flow}): parts {parts}, rows {rows}, padded value reproduced: {ok}")
    assert ok

# ------------------------------------------------------------------ B
n, rho, k, Q = 1 << 16, 4, 16, 172
qpad = k * Q
path = int(math.log2(rho * n))


def wire(rows, G=1):
    vec = (G + 1) * (n + qpad) * 16
    col = Q * 8 * rows
    rest = Q * (8 + 32 + 32 * path)
    return vec + col + rest


def odd_parts(x):                          # odd factor of an axis (parts it adds to a claim)
    while x % 2 == 0:
        x //= 2
    return x


def prof(name, d, f, qw, kvw, blocks, today):
    mats = [("Wq", qw, d), ("Wk", kvw, d), ("Wv", kvw, d), ("Wo", d, qw), ("Wg", d, f), ("Wu", d, f), ("Wd", f, d)]
    dp, fp = 1 << (d - 1).bit_length(), 1 << (f - 1).bit_length()
    pad_axis = {d: dp, f: fp, qw: qw, kvw: kvw}
    true_w = sum(a * b for _, a, b in mats)
    pad_w = sum(pad_axis[a] * pad_axis[b] for _, a, b in mats)
    rows_true = sum(a * b // n for _, a, b in mats)
    assert all((a * b) % n == 0 for _, a, b in mats), "each matrix is a whole number of rows"
    rows_pad = pad_w // n
    parts = sum(odd_parts(a) * odd_parts(b) for _, a, b in mats)
    # smallest part (words per part) must be >= n so that every part is a slice of whole rows
    min_part = min(a * b // (odd_parts(a) * odd_parts(b)) for _, a, b in mats)
    print(f"\n== B. {name}: d={d} (pad {dp}), f={f} (pad {fp}), q={qw}, kv={kvw}, {blocks} blocks")
    print(f"  true words a block   {true_w:>12,}   padded {pad_w:>12,}   ratio {pad_w/true_w:.3f}")
    print(f"  rows at n=2^16       true (dense, odd factors on rows) {rows_true}   padded {rows_pad}   (x{rows_pad/rows_true:.3f})")
    print(f"  claim parts a block  {parts}   (per matrix: " + ", ".join(f"{m}={odd_parts(a)*odd_parts(b)}" for m, a, b in mats) + ")")
    print(f"  smallest part       {min_part:,} words = {min_part//n} rows (>= 1 needed)")
    for lab, r in (("dense map", rows_true), ("padded only", rows_pad)):
        w = wire(r)
        print(f"  {lab:<12} {r:>5} rows a block: wire {w/1e6:7.3f} MB a block, x{blocks} = {w*blocks/1e6:7.1f} MB"
              f"   ({w*blocks/today:.3f} of today's {today/1e6:.1f} MB)")
    return rows_true, rows_pad


prof("W16R2 8B", 4096, 14336, 4096, 1024, 32, 818_728_672)
prof("W16R2 Shieldstral", 3072, 9216, 4096, 1024, 26, 669_600_000)
