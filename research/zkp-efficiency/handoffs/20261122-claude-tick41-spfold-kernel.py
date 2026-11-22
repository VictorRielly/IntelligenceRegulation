"""Tick 41 (item 67): the spfold kernel against its floors. Arithmetic only; no input files.
Shapes are the trace detail strings of results/zk60_lane_threads_20261122/raw/traces/lt_trace_leg3 (COUNTED);
times are tick 40's one-lane execution per block (MEASURED, partial + reduce kernels together)."""

shapes = {
    # name: rows, active, nnz, n, q, k, blocks, measured_ms
    "A rows=2504": (2504, 2504, 5658, 16384, 280, 37, 13, 4.18),
    "H rows=2606": (2606, 2606, 7726, 16384, 280, 10, 16, 1.85),
}
COPY_BW = 700e9      # K0 copy roofline, B/s (tick 14 / K0 record)
GL_MUL = 220e9       # K4 gl_mul rate, products/s (K4 record)
CORES = 80
for name, (rows, act, nnz, n, q, k, blocks, ms) in shapes.items():
    cols = n + q
    tgx = -(-cols // 32)
    groups = tgx * blocks
    tg_bytes = k * 32 * 16                     # metal.rs:1827
    rows_blk = act / blocks
    read = act * cols * 8                      # data + pads, 8 B per word (upper bound: v == 0 rows still read)
    part_w = blocks * k * cols * 16            # partial write
    part_r = part_w                            # reduce read
    out_w = k * cols * 16
    muls = nnz * cols * 2
    print(f"== {name}: cols {cols}, groups {groups} (32 threads each), tg memory {tg_bytes} B, rows/block {rows_blk:.1f}, "
          f"terms/row {nnz/act:.2f}, terms/vector {nnz/k:.1f}")
    print(f"   read {read/1e6:.0f} MB, partials {part_w/1e6:.0f} MB written + {part_r/1e6:.0f} MB read, out {out_w/1e6:.1f} MB")
    fl_bytes = (read + part_w + part_r + out_w) / COPY_BW * 1e3
    fl_mul = muls / GL_MUL * 1e3
    print(f"   gl_mul {muls/1e6:.1f} M; floor bytes {fl_bytes:.2f} ms, floor mul {fl_mul:.2f} ms, sum {fl_bytes+fl_mul:.2f} ms; "
          f"measured {ms} ms = {ms/(fl_bytes+fl_mul):.2f}x sum, {ms/max(fl_bytes, fl_mul):.2f}x max")
    print(f"   rates: read {read/ms/1e6:.0f} GB/s ({read/ms/1e6/700:.0%} of copy roofline), "
          f"gl_mul {muls/ms/1e6:.0f} G/s ({muls/ms/1e6/220:.0%} of K4)")
    for gpc in (1, 2, 3, 6):
        resident = CORES * gpc
        waves = groups / resident
        print(f"   if {gpc} group(s)/core resident: {waves:.1f} waves, {ms/waves*1e3:.0f} us a wave, "
              f"{ms/waves*1e3/rows_blk*1e3:.0f} ns a row-iteration")

# Layout B: one thread per (column, vector), terms by vector (CSC), accumulators in registers, no partials, no reduce.
rows, act, nnz, n, q, k, blocks, ms = shapes["A rows=2504"]
cols = n + q
read_dram = act * cols * 8
read_l2 = nnz * cols * 8
out_w = k * cols * 16
muls = nnz * cols * 2
print("== layout B (CSC by vector, registers), A shape")
print(f"   logical row loads {read_l2/1e6:.0f} MB ({read_l2/read_dram:.2f}x), DRAM {read_dram/1e6:.0f} MB if a column tile's {act*256/1e3:.0f} KB is shared by its 37 groups; out {out_w/1e6:.1f} MB; no partials")
fb = (read_dram + out_w) / COPY_BW * 1e3
fm = muls / GL_MUL * 1e3
print(f"   floor bytes {fb:.2f} ms, mul {fm:.2f} ms, sum {fb+fm:.2f} ms; groups {-(-cols//32)*k}")
# Efficiency the H shape already reaches, applied to A's multiplications (DERIVED).
hr = shapes["H rows=2606"]
h_rate = hr[2] * (hr[3] + hr[4]) * 2 / (hr[7] * 1e-3) / 1e9     # G gl_mul/s (time in ms)
print(f"   H attains {h_rate:.0f} G gl_mul/s; A's {muls/1e6:.0f} M at that rate = {muls/ (h_rate*1e9)*1e3:.2f} ms (saves {4.18 - muls/(h_rate*1e9)*1e3:.2f} ms of 4.18)")
# What a saving is worth (tick 40: a one-lane device ms is 0.27 to 0.8 % of rate, from 0.8-2.4 % for 3 ms)
for s in (1.0, 2.0, 2.7, 3.0):
    print(f"   saving {s} ms -> {s*0.27:.1f} to {s*0.8:.1f} % of the six-lane rate (tick 40's exchange range)")
# K-split bench: the unchanged kernel called on chunks of the 37 vectors.
for ch in ((10, 9, 9, 9), (19, 18), (8, 8, 8, 8, 5)):
    tg = [c * 512 for c in ch]
    blk = [min(16, (128 << 20) // (c * cols * 16)) for c in ch]
    part_mb = sum(b * c * cols * 16 for b, c in zip(blk, ch)) / 1e6
    print(f"   K-split {ch}: tg bytes {tg}, blocks {blk}, partials {part_mb:.0f} MB, data re-read {len(ch)}x = {len(ch)*read_dram/1e6:.0f} MB")

# T-occ: H's shape with its threadgroup allocation padded to A's size (the kernel uses only k*512 B of it).
print("== T-occ: H shape, tg length 5,120 -> 18,944 B; A's allocation per group; output unchanged")
print("   hypothesis (resident groups limit the rate): H time rises from 1.85 toward A's per-row rate; "
      f"at 1 group/core 256 ns a row-iteration -> {8336/80*162.9*256e-9*1e3:.2f} ms; at 3 groups/core -> {8336/240*162.9*769e-9*1e3:.2f} ms (both include A's measured rate per wave)")
