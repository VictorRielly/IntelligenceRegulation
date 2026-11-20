"""Arithmetic behind the tick 19 handoff (TensorZKP, ePrint 2026/1250). Standard library only; reads nothing; runs nothing on a GPU.

Every input marked [paper] is a number printed in the USENIX Security 2026 PDF; ASSUMED inputs are spec-sheet figures
written from memory and not verified in this tick.
"""

# --- Table 1 of the paper, 2^25 gates, ms [paper] ---
merkle, encoder, opening = 8.59, 50.64, 6.30
perm, zero = 134.00, 16.96
pcs = merkle + encoder + opening
piop = perm + zero
total = pcs + piop
print("Table 1 sums: PCS %.2f PIOP %.2f total %.2f vs headline 215.28 (diff %.2f ms, %.2f%%)"
      % (pcs, piop, total, total - 215.28, 100 * (total - 215.28) / 215.28))
for name, v in [("merkle", merkle), ("encoder", encoder), ("opening", opening), ("perm-check", perm), ("zero-check", zero)]:
    print("  %-10s %7.2f ms  %5.1f%% of Table 1 total" % (name, v, 100 * v / total))
print("encoder in Table 1 / encoder module at 2^25 [11.58 ms]: %.2fx" % (encoder / 11.58))

# --- bandwidth reading of the micro-benchmarks (BabyBear^8: k = 8, L = 4 -> 32 B per element, paper section 7.1 and 4.1) ---
N = 2 ** 25
B = 32  # bytes per element, N*k*L [paper]
HBM = 3.35e12  # ASSUMED: H100 SXM5 HBM3 peak, B/s (the paper names an H100 SXM5 and 80 GB)
ip_bytes = 2 * N * B
print("inner product: %.3f GB in 0.85 ms = %.2f TB/s = %.0f%% of %.2f TB/s" % (ip_bytes / 1e9, ip_bytes / 0.85e-3 / 1e12, 100 * ip_bytes / 0.85e-3 / HBM, HBM / 1e12))
sv_bytes = 2 * N * B  # read one vector, write one vector (limb-layout output assumed folded back to N*k*L bytes)
print("scalar-vector: %.3f GB in 0.91 ms = %.2f TB/s = %.0f%%" % (sv_bytes / 1e9, sv_bytes / 0.91e-3 / 1e12, 100 * sv_bytes / 0.91e-3 / HBM))
# degree-2 sumcheck: two tables f,g; round i reads 2 vectors of N/2^(i-1) elements; fold writes half of that
read_eval = 2 * N * B * 2  # geometric sum 2x the first round
write_fold = 2 * (N // 2) * B * 2
read_fold_extra = read_eval  # unfused: the fold re-reads both vectors
unfused = read_eval + read_fold_extra + write_fold
fused = read_eval + write_fold
for label, tr in [("unfused (eval then fold, as Algorithm 1 is written)", unfused), ("fused (fold on load)", fused)]:
    print("sumcheck %s: %.2f GB in 4.04 ms = %.2f TB/s = %.0f%%" % (label, tr / 1e9, tr / 4.04e-3 / 1e12, 100 * tr / 4.04e-3 / HBM))

# --- limb accounting for the project's field ---
print("byte-MACs per base-field product: BabyBear 4x4=%d, Goldilocks 8x8=%d" % (4 * 4, 8 * 8))
print("inner product of Fp2 Goldilocks elements: (2*8)^2 = %d byte-MACs per element-pair vs 4 schoolbook / 3 Karatsuba field products" % ((2 * 8) ** 2))
print("BabyBear^8: (8*4)^2 = %d byte-MACs per element-pair vs 64 schoolbook base products" % ((8 * 4) ** 2))
print("bytes per element: BabyBear^8 %d B, Goldilocks Fp2 16 B (the same as the project's native Fp2 word)" % B)

# --- exactness bounds for the accumulators ---
print("int32 accumulator (paper eq. 23 prints N < 33,025): N <= %d" % ((2 ** 31 - 1) // 255 ** 2))
print("fp32 accumulator, exact integers up to 2^24, fp16 inputs 0..255: N <= %d" % (2 ** 24 // 255 ** 2))
print("  (centred limbs -128..127, product <= 2^14: N <= %d)" % (2 ** 24 // 2 ** 14))

# --- the local G1 roof claim, unit check ---
tops, gl = 1500.0, 0.85  # [MODEL] numbers quoted in 20261115-gpu-friendly-protocols.md, section 1
for infl in (9, 36, 64):
    print("roof ratio at %2d x inflation: if TOPS = MAC/s %.1fx ; if TOPS counts 2 ops per MAC %.1fx" % (infl, tops / gl / infl, tops / gl / infl / 2))
