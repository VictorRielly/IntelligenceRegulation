#!/usr/bin/env python3
"""Tick 66 (queue item 105): odd-factor layout for the embedding and head tables.
Standard library only, reads no file. Two parts.
  A. a toy check over the Goldilocks prime that the odd-factor-on-rows layout answers the claims the token stages raise:
       (A1) the table claim of stage IN's TZC slot: tau~(rho) = sum_{v<V} eq(v;rho) (v + beta E~(v,r) + g)
            + (sum_{v>=V} eq(v;rho)) (beta E~(0,r) + g)   [padded rows repeat row 0: stage_in.rs:185-187]
            evaluated through parts (the main claim) and one row-0 claim, against the direct padded value;
       (A2) the head claim of stage OUT's SO_HEAD slot: sum_j eq(j;r_j) m_j W'[j][rho_d], once with m folded into the
            committed words (an ordinary multilinear claim: parts work) and once with m left out (what the grammar
            cannot do inside a commitment row): the number of distinct column-weight vectors is counted.
     The part rule is zkp_core::pcs::zpart_weights (pcs.rs:869-909): row weight = coef * eq(point[..lr]); column key =
     the point tail on the whole row; every part of a claim must have the same key (pcs.rs:934).
  B. rows, parts and receipt bytes at n = 2^16 for both profiles (wire formula of ticks 59 and 61:
     (G+1)(n+qpad)*16 + Q*(8 + 8*rows + 32 + 32*path), n = 2^16, rate 1/4, k = 16, Q' = 172).
"""
import math, random

P = (1 << 64) - (1 << 32) + 1
random.seed(66)


def eq_table(point):
    t = [1]
    for r in point:
        t = [y for x in t for y in (x * (1 - r) % P, x * r % P)]
    return t


def mle(vals, point):
    t = eq_table(point)
    return sum(a * b for a, b in zip(vals, t)) % P


def odd_split(x):
    lo = 0
    while x % 2 == 0:
        x //= 2
        lo += 1
    return x, lo


def part_value(M, n, offset, ls, coef, point):
    """coef * MLE(slice)(point) by the opening's rule, slice of at least one row."""
    log_cols = n.bit_length() - 1
    lr = ls - log_cols
    assert offset % n == 0 and lr >= 0
    r0 = offset // n
    eq_r = eq_table(point[:lr])
    col_w = eq_table(point[lr:])
    tot = 0
    for i, e in enumerate(eq_r):
        tot += coef * e % P * (sum(a * b for a, b in zip(M[r0 + i], col_w)) % P)
    return tot % P


def dense_layout(W, v_true, d_true, log_cols):
    """W[v][i] true words. Odd factor of v on the row axis (blocks), d a power of two here or with its own odd factor.
    Returns (rows M, parts description, padded bit counts)."""
    v_odd, v_lo = odd_split(v_true)
    d_odd, d_lo = odd_split(d_true)
    v_hi_bits = max(1, (v_odd - 1).bit_length()) if v_odd > 1 else 0
    d_hi_bits = max(1, (d_odd - 1).bit_length()) if d_odd > 1 else 0
    lv, ld = v_hi_bits + v_lo, d_hi_bits + d_lo
    dense = []
    for vh in range(v_odd):
        for dh in range(d_odd):
            for vl in range(1 << v_lo):
                for dl in range(1 << d_lo):
                    dense.append(W[(vh << v_lo) | vl][(dh << d_lo) | dl])
    n = 1 << log_cols
    assert len(dense) == v_true * d_true and len(dense) % n == 0
    M = [dense[k:k + n] for k in range(0, len(dense), n)]
    return M, (v_odd, v_lo, v_hi_bits, d_odd, d_lo, d_hi_bits), (lv, ld)


def claim_value(M, info, rho_v, r_d, log_cols):
    """sum over odd-factor combinations of coef * MLE(block)(low point); the same tail for every part."""
    v_odd, v_lo, v_hi_bits, d_odd, d_lo, d_hi_bits = info
    n = 1 << log_cols
    eq_vh = eq_table(rho_v[:v_hi_bits]) if v_hi_bits else [1]
    eq_dh = eq_table(r_d[:d_hi_bits]) if d_hi_bits else [1]
    low = rho_v[v_hi_bits:] + r_d[d_hi_bits:]
    block = 1 << (v_lo + d_lo)
    got = 0
    parts = 0
    for vh in range(v_odd):
        for dh in range(d_odd):
            b = vh * d_odd + dh
            got += part_value(M, n, b * block, v_lo + d_lo, eq_vh[vh] * eq_dh[dh] % P, low)
            parts += 1
    return got % P, parts


def toy_embedding(v_true, d_true, log_cols):
    """A1. Vocabulary axis with an odd factor (and optionally the width axis too)."""
    W = [[random.randrange(-3000, 3000) % P for _ in range(d_true)] for _ in range(v_true)]
    M, info, (lv, ld) = dense_layout(W, v_true, d_true, log_cols)
    vp, dp = 1 << lv, 1 << ld
    beta, g = random.randrange(P), random.randrange(P)
    rho_v = [random.randrange(P) for _ in range(lv)]
    r_d = [random.randrange(P) for _ in range(ld)]
    # direct: the padded table tau over the lifted cube, evaluated at rho_v
    E_row = lambda v: [W[v][i] if i < d_true else 0 for i in range(dp)]
    ef = [mle(E_row(v), r_d) for v in range(v_true)]
    tau = [(v + beta * ef[v] + g) % P if v < v_true else (beta * ef[0] + g) % P for v in range(vp)]
    want = mle(tau, rho_v)
    # through the claims: main claim E~(rho_v, r_d) and the row-0 claim E~(0, r_d)
    main, parts = claim_value(M, info, rho_v, r_d, log_cols)
    flat_pad = [E_row(v)[i] if v < v_true else 0 for v in range(vp) for i in range(dp)]
    assert main == mle(flat_pad, rho_v + r_d), "main claim differs from the padded multilinear value"
    row0, _ = claim_value(M, info, [0] * lv, r_d, log_cols)          # E~(0, r_d): the second claim (row 0)
    eqv = eq_table(rho_v)
    ident = sum(eqv[v] * v for v in range(vp)) % P                   # public: MLE of v over true rows, computed below
    ident = sum(eqv[v] * v for v in range(v_true)) % P
    pad_mass = sum(eqv[v_true:]) % P
    # tau~(rho) = ident + beta * (sum_{v<V} eq ef[v]) + g * (sum_{v<V} eq) + pad_mass (beta row0 + g)
    # and sum_{v<V} eq(v;rho) E~(v,r) = main claim, because padded rows of E are zero
    got = (ident + beta * main + g * ((1 - pad_mass) % P) + pad_mass * ((beta * row0 + g) % P)) % P
    return want == got, parts, len(M), vp - v_true


def toy_head(v_true, d_true, log_cols):
    """A2. Head with per-row multipliers m_j in [1, 2^12]: count the distinct column-weight vectors a claim needs."""
    n = 1 << log_cols
    W = [[random.randrange(-127, 128) % P for _ in range(d_true)] for _ in range(v_true)]
    m = [random.randrange(1, 1 << 12) for _ in range(v_true)]
    Wm = [[(m[j] * W[j][i]) % P for i in range(d_true)] for j in range(v_true)]
    M, info, (lv, ld) = dense_layout(Wm, v_true, d_true, log_cols)
    vp, dp = 1 << lv, 1 << ld
    r_j = [random.randrange(P) for _ in range(lv)]
    rho_d = [random.randrange(P) for _ in range(ld)]
    e = eq_table(r_j)
    want = 0
    wf = [sum(e[j] * m[j] % P * (W[j][i] % P) for j in range(v_true)) % P for i in range(d_true)] + [0] * (dp - d_true)
    want = mle(wf, rho_d)
    got, parts = claim_value(M, info, r_j, rho_d, log_cols)
    folded_ok = (want == got)
    # without folding: the column weight of commitment word (row R, col c) is m[j(R,c)] * eq(...); in the dense layout a
    # commitment row of n words holds n // d_true consecutive vocabulary rows (power-of-two d), so the weight vector of a
    # row depends on the m values it holds: count distinct vectors over the rows
    per_row = n // d_true if d_true <= n and n % d_true == 0 else None
    distinct = None
    if per_row:
        keys = set()
        for R in range(len(M)):
            keys.add(tuple(m[R * per_row + k] for k in range(per_row) if R * per_row + k < v_true))
        distinct = (len(keys), len(M))
    return folded_ok, parts, len(M), distinct



def toy_embedding_padcopy(v_true, d_true):
    """A1b. Alternative: commit the vocabulary padded to V_pad rows, rows >= V holding a copy of row 0 (what tau_table
    reads there); then the table claim is ONE plain multilinear claim E'~(rho_v, r_d), no row-0 claim, no odd factors."""
    lv, ld = (v_true - 1).bit_length(), (d_true - 1).bit_length()
    vp, dp = 1 << lv, 1 << ld
    W = [[random.randrange(-3000, 3000) % P for _ in range(d_true)] for _ in range(v_true)]
    Ep = [(W[v] if v < v_true else W[0]) + [0] * (dp - d_true) for v in range(vp)]
    beta, g = random.randrange(P), random.randrange(P)
    rho_v = [random.randrange(P) for _ in range(lv)]
    r_d = [random.randrange(P) for _ in range(ld)]
    ef = [mle(Ep[v], r_d) for v in range(vp)]
    tau = [(v + beta * ef[v] + g) % P if v < v_true else (beta * ef[0] + g) % P for v in range(vp)]
    want = mle(tau, rho_v)
    eqv = eq_table(rho_v)
    ident = sum(eqv[v] * v for v in range(v_true)) % P
    claim = mle([x for row in Ep for x in row], rho_v + r_d)       # one claim on the committed padded object
    got = (ident + beta * claim + g) % P
    return want == got


print("== A1. toy: the stage-IN table claim through parts plus the row-0 claim (n = 2^3 columns)")
for vt, dt in [(12, 8), (24, 4), (20, 16), (16, 12), (12, 24)]:
    ok, parts, rows, padrows = toy_embedding(vt, dt, 3)
    print(f"  V={vt} d={dt}: parts {parts}, rows {rows}, padded vocabulary rows {padrows}, tau~(rho) reproduced: {ok}")
    assert ok
print("\n== A1b. toy: padded vocabulary committed with row-0 copies, one plain claim")
for vt, dt in [(12, 8), (20, 16), (24, 4)]:
    ok = toy_embedding_padcopy(vt, dt)
    print(f"  V={vt} d={dt}: tau~(rho) reproduced by ONE claim: {ok}")
    assert ok
print("\n== A2. toy: the stage-OUT head claim with the multiplier folded into the words")
for vt, dt in [(12, 8), (20, 16), (24, 8)]:
    ok, parts, rows, distinct = toy_head(vt, dt, 4)
    print(f"  V={vt} d={dt}: folded claim (W'' = m W') reproduced: {ok}, parts {parts}, rows {rows}; "
          f"without folding, distinct column-weight vectors needed (distinct, rows): {distinct}")
    assert ok

# ------------------------------------------------------------------ B
n, rho, k, Q = 1 << 16, 4, 16, 172
qpad = k * Q
path = int(math.log2(rho * n))
GROUP = (n + qpad) * 16                    # bytes of one more column-weight group (the (G+1) term)


def wire(rows, G=1):
    return (G + 1) * (n + qpad) * 16 + Q * 8 * rows + Q * (8 + 32 + 32 * path)


def prof(name, V, d, d_pad, pad_row0):
    vo, vlo = odd_split(V)
    do, dlo = odd_split(d)
    v_pad = 1 << (V - 1).bit_length()
    words = V * d
    assert words % n == 0
    rows = words // n
    rows_pad_v = v_pad * d // n               # vocabulary padded to 2^17, width true
    rows_pad_both = v_pad * d_pad // n        # both padded
    parts = vo * do
    part_words = words // parts
    print(f"\n== B. {name}: V={V:,} = {vo} x 2^{vlo}, d={d:,} = {do} x 2^{dlo} (d_pad {d_pad}), V_pad {v_pad:,}")
    print(f"  words {words:,}; rows at n=2^16: dense {rows:,}; vocabulary padded {rows_pad_v:,}; both padded {rows_pad_both:,} "
          f"(x{rows_pad_both/rows:.3f})")
    print(f"  claim parts {parts}  (v side {vo}, d side {do}); one part = {part_words:,} words = {part_words//n:,} rows "
          f"(whole rows: {part_words % n == 0})")
    print(f"  pad vocabulary rows {v_pad - V:,}; the table repeats row 0 on them: {'one extra claim, one extra group' if pad_row0 and v_pad > V else 'none'}")
    w1 = wire(rows)
    print(f"  one opening, dense, one group: {w1/1e6:.2f} MB (columns {Q*8*rows/1e6:.2f} MB, vectors {2*(n+qpad)*16/1e6:.2f} MB)")
    if pad_row0 and v_pad > V:
        w2 = wire(rows, G=2)
        print(f"  + row-0 claim as a second group: {w2/1e6:.2f} MB (+{(w2-w1)/1e6:.3f} MB = one group {GROUP:,} B)")
    wp = wire(rows_pad_both)
    print(f"  both axes padded: {wp/1e6:.2f} MB (dense saves {(wp-w1)/1e6:.2f} MB)")
    return rows


rows_e8 = prof("W16R2 8B embedding (int16) and head (int8 W'' = m W'), each", 128_256, 4096, 4096, True)
rows_s = prof("W16R2 Shieldstral embedding (int16; its classifier has no head)", 131_072, 3072, 4096, True)

print("\n== C. the head's multiplier left outside the committed words (8B), distinct column-weight groups")
per_row = n // 4096
rows_head = 128_256 * 4096 // n
print(f"  vocabulary rows per commitment row {per_row}; commitment rows {rows_head:,}; each holds 16 different m_j, "
      f"so up to {rows_head:,} distinct column-weight vectors = {rows_head:,} groups")
print(f"  extra bytes at one group = {GROUP:,} B: {rows_head*GROUP/1e9:.2f} GB a request (against {wire(rows_head)/1e6:.2f} MB for the folded form)")
print(f"  words of W'' = m_j W'[j][i]: |w| <= 127 x 2^12 = {127 * 4096:,} < 2^19 (one 8-byte field word each, no extra receipt bytes)")
