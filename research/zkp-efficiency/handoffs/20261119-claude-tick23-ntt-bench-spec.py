#!/usr/bin/env python3
"""Tick 23 (queue item 39): counts for the NTT-only bench specification.
Standard library only. Every DERIVED number in the handoff comes from this script.

Inputs (cited, not re-measured):
  - kernel structure: metal_kernels.metal lines 211-463 (k_ntt_head_t, k_ntt_tail), metal.rs 290-332 (encode_fused)
  - K4 throughput (results/zk60_k0k1_roofline_20261118/README.md, K3/K4 table): gl_add 1.71 ps/op, gl_mul 4.55 ps/op
    (whole GPU, independent chains; gl_sub assumed equal to gl_add; gl_mul_pow2 NOT measured: bounded by [gl_add, gl_mul])
  - tick 21 table: measured diag medians per block (ms) and the 700 GB/s traffic floors (ms)
"""

PS_ADD = 1.71e-12
PS_MUL = 4.55e-12

TILE_LOG = 11


def ntt_counts(log_n, log_src, prune, scale):
    """Per row: general gl_mul, shifted (gl_mul_pow2) multiplies, add/sub pairs counted as 2 ops per butterfly,
    barriers (head + tail), threadgroups per row."""
    bf = 1 << (log_n - 1)  # butterflies per stage
    shift = 0
    general = 0
    addsub = 0
    # stages 1..6 use the power-of-two form (head only; stages above 11 are tail = general)
    for s in range(1, log_n + 1):
        if s <= 6:
            shift += bf
        else:
            general += bf
        addsub += 2 * bf
    if prune:
        # first radix-4 pass (stages 1, 2) pruned: reads half the words, 2 shift mults per 4 elements, 4 add/sub per 4
        shift -= 2 * bf - (1 << (log_n - 1))  # 2^(log_n-1) shift mults instead of 2 * bf = 2^log_n
        addsub -= 2 * (2 * bf) - 4 * ((1 << log_n) // 4)  # 4 per 4 elements vs 2 per butterfly * 2 stages
    if scale:
        general += 1 << log_n
    # barriers: head: 1 load + passes; r4 passes of 2 stages, leftover radix-2 stage
    L = min(log_n, TILE_LOG)
    s0 = 3 if prune else 1
    head_passes = 0
    while s0 + 1 <= L:
        head_passes += 1
        s0 += 2
    head_passes += (L - s0 + 1)  # leftover single stages
    head_bar = 1 + head_passes
    tail_bar = 0
    G = log_n - TILE_LOG
    if G > 0:
        t = G // 2 + (G % 2)
        tail_bar = 1 + t
    return dict(general=general, shift=shift, addsub=addsub, head_bar=head_bar, tail_bar=tail_bar, G=G,
                tg_head=1 << (log_n - L), tg_tail=(1 << G) if G > 0 else 0)


# (name, rows, log_n, log_src, prune, scale, measured_ms, traffic_floor_ms)  -- measured and floors: tick 21 section 1, 2
CASES = [
    ("8B A inverse",     2504, 14, 14, False, True, 4.110, 1.88),
    ("8B A forward",     2504, 15, 14, True,  False, 6.897, 3.28),
    ("Shield A inverse", 4577, 14, 14, False, True, 7.427, 3.43),
    ("Shield A forward", 4577, 16, 14, True,  False, 25.138, 11.14),
]

print("case                 rows  gen/row   shift/row  addsub/row  barriers(h+t)  TGs/row(h,t)")
tot = {}
for name, rows, ln, ls, pr, sc, meas, trf in CASES:
    c = ntt_counts(ln, ls, pr, sc)
    gen = rows * c["general"]
    sh = rows * c["shift"]
    ad = rows * c["addsub"]
    t_gen = gen * PS_MUL
    t_add = ad * PS_ADD
    t_sh_lo = sh * PS_ADD
    t_sh_hi = sh * PS_MUL
    ar_lo = (t_gen + t_add + t_sh_lo) * 1e3
    ar_hi = (t_gen + t_add + t_sh_hi) * 1e3
    print(f"{name:18s} {rows:5d} {c['general']:8d} {c['shift']:9d} {c['addsub']:10d}   {c['head_bar']}+{c['tail_bar']}           {c['tg_head']},{c['tg_tail']}")
    print(f"   total: gen {gen/1e6:8.1f} M, shift {sh/1e6:8.1f} M, add/sub {ad/1e6:8.1f} M; TGs total head {rows*c['tg_head']}, tail {rows*c['tg_tail']}")
    print(f"   arithmetic floor at K4 independent-chain throughput: {ar_lo:5.2f} to {ar_hi:5.2f} ms "
          f"(gen {t_gen*1e3:5.2f}, add/sub {t_add*1e3:5.2f}, shift {t_sh_lo*1e3:4.2f} to {t_sh_hi*1e3:4.2f})")
    print(f"   traffic floor {trf:5.2f} ms; measured {meas:6.3f} ms; measured / arith {meas/ar_hi:4.2f} to {meas/ar_lo:4.2f}; "
          f"measured / traffic {meas/trf:4.2f}")
    print(f"   traffic + arithmetic (no overlap): {trf+ar_lo:5.2f} to {trf+ar_hi:5.2f} ms; max(traffic, arith): {max(trf, ar_lo):5.2f} to {max(trf, ar_hi):5.2f} ms")
    tot[name] = (ar_lo, ar_hi, trf, meas)

# threadgroup memory and thread counts
print()
print("threadgroup array: TILE = 2^11 words x 8 B =", (1 << TILE_LOG) * 8, "B per threadgroup (head and tail)")
print("threads requested per group with r4: TILE/4 =", (1 << TILE_LOG) // 4)

# general multiplications of a factorisation 2^14 = 2^6 * 2^6 * 2^2 (shift-only 64-point blocks, 2 inter-pass twiddle sets)
n = 1 << 14
cur_gen = 8 * (n // 2)                       # stages 7..14 as general
alt_gen = 2 * n                              # two inter-pass twiddle sets, every element once (upper bound: trivial ones not skipped)
print()
print(f"general multiplications per 2^14 row now: {cur_gen}; with a 2^6 x 2^6 x 2^2 split (two twiddle sets, upper bound): {alt_gen}; ratio {alt_gen/cur_gen:.2f}")
n2 = 1 << 15
cur2 = 9 * (n2 // 2)
print(f"2^15 forward: now {cur2} general per row (plain, stages 7..15); a 2^6 x 2^6 x 2^3 split: {2*n2}; ratio {2*n2/cur2:.2f}")
n3 = 1 << 16
cur3 = 10 * (n3 // 2)
print(f"2^16 forward: now {cur3}; 2^6 x 2^6 x 2^4: {2*n3}; ratio {2*n3/cur3:.2f}")

# production forward at 8B: ZK mode is NOT pruned (extent = 2^14 + q > 2^14)
for q in (280, 256):
    ext = (1 << 14) + q
    print(f"ZK extent 2^14 + {q} = {ext}; prune needs <= 2^(log_n-1): at log_n 15 -> {1<<14} (pruned: {ext <= (1<<14)}); at log_n 16 -> {1<<15} (pruned: {ext <= (1<<15)})")

# cost of the unpruned first pass at 8B forward: extra shift mults and add/sub per row, as seconds on the arithmetic model
rows = 2504
ln = 15
extra_shift = (1 << ln) - (1 << (ln - 1))     # 2^15 - 2^14 per row
extra_addsub = 2 * (1 << (ln - 1)) * 2 - 4 * ((1 << ln) // 4)  # 4 * 2^14 - 2^15... (see model above)
t_lo = rows * (extra_shift * PS_ADD + extra_addsub * PS_ADD) * 1e3
t_hi = rows * (extra_shift * PS_MUL + extra_addsub * PS_ADD) * 1e3
print(f"8B A forward unpruned (ZK): extra per row shift {extra_shift}, add/sub {extra_addsub}; extra arithmetic {t_lo:.2f} to {t_hi:.2f} ms per commit (A) at independent-chain rates")

# diag sum against the commit (tick 21): commit 13.987 ms vs diag parts 4.110 + 6.897 + 1.660
print(f"8B A: commit {13.987} ms - diag parts (4.110 + 6.897 + 1.660 = {4.110+6.897+1.660:.3f}) = {13.987-(4.110+6.897+1.660):.3f} ms ({(13.987-(4.110+6.897+1.660))/13.987*100:.1f}% of commit)")

# ---- ceilings for a shift-only factorisation (general multiplications 0.40 to 0.50 of today's), whole block (A and H commits)
print()
def gen_ms(rows, ln, scale):
    c = ntt_counts(ln, 14, ln > 14 and True, scale)
    return rows * c["general"] * PS_MUL * 1e3, rows * (c["general"] - (1 << ln if scale else 0)) * PS_MUL * 1e3
prof = {
    "8B": ([(2504, 14, 15), (2606, 14, 15)], 91.462, 3745.5),
    "Shield": ([(4577, 14, 16), (4390, 14, 16)], 174.249, None),
}
for k, (lst, blk, cad) in prof.items():
    g_all = 0.0
    g_nonscale = 0.0
    for rows, li, lf in lst:
        a, a2 = gen_ms(rows, li, True)
        b, b2 = gen_ms(rows, lf, False)
        g_all += a + b
        g_nonscale += a2 + b
    save_lo = 0.5 * g_nonscale
    save_hi = 0.6 * g_nonscale
    print(f"{k}: general multiplications (A + H, inverse + forward) {g_all:5.2f} ms of NTT arithmetic at K4 rate; "
          f"split saves 50 to 60% of the non-scale part = {save_lo:4.2f} to {save_hi:4.2f} ms = {save_lo/blk*100:3.1f} to {save_hi/blk*100:3.1f}% of block GPU"
          + (f"; at most {save_hi*32/cad*100:3.1f}% of cadence at full pass-through" if cad else ""))
