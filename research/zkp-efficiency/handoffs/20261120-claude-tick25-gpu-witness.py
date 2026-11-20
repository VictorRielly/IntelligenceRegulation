"""Tick 25 arithmetic: GPU witness generation against the sealing pass (standard library, reads no file).

Inputs are copied from the cited records; every line says which.
"""

# --- inputs ---------------------------------------------------------------
# Batch 8 REPORT.md lines 13-16, 150-168 (solo serve1 sealing pass, 32 blocks, MEASURED + sampler split)
PASS = 2.183                       # s, unsampled median, n = 12
GROUPS = {"a_witness_only": 1.065, "b_before_first_product": 0.146, "c_middle": 0.531, "d_device_wait": 0.440}
CS3 = 0.728
CS3_REPEAT = 0.349                 # removed by A33 stage 1 (measured -0.26 to -0.275 s on the pass)
HIST_W16 = 0.250                   # w16_histograms_cols
HIST_OTHER = 0.128                 # looked_built 0.059, exp 0.035, act histogram 0.031, Layout 0.003
ASSIGN_LIMBS = 0.289               # fill_planes and closures inside assign_with (0.302)
SCORES_SOFTMAX_PV = 0.354          # report line 154
RQ_ROPE = 0.114
BUILD_WEIGHT_SCAN = 0.128          # (b): the build's own check_accuracy_for_shape weight scan
GPU_BUSY = 0.372                   # s per pass, A1/A2 (report line 111)
BESIDE = 1.51                      # sealing slowdown beside a proof, MVP_STATUS (x1.51 to x1.56)
BLOCKS = 32

# RTX 5090 [search-result figures from third-party spec pages, not NVIDIA's datasheet]
INT8_DENSE_TOPS = 838e12
BW = 1792e9
# W16R2_8B block (h124 README): 27.92 G MACs, about 218 M int8 weights
MACS = 27.92e9
W_BYTES = 218e6

print("== A. what the GPU already does in the sealing pass (Mac) ==")
print("GPU busy per pass %.3f s = %.1f%% of %.3f s; per block %.1f ms" % (GPU_BUSY, 100 * GPU_BUSY / PASS, PASS, 1e3 * GPU_BUSY / BLOCKS))
print("device-wait group d: %.3f s = %.1f%%" % (GROUPS['d_device_wait'], 100 * GROUPS['d_device_wait'] / PASS))
host = PASS - GROUPS['d_device_wait']
print("host-only groups a+b+c: %.3f s = %.1f%%" % (host, 100 * host / PASS))

print("\n== B. the weight products on a 5090 (floors, not predictions) ==")
t_comp = 2 * MACS / INT8_DENSE_TOPS
t_bw = W_BYTES / BW
print("per block: arithmetic floor %.3f ms, weight-read floor %.3f ms; x32 = %.1f ms per request" % (1e3 * t_comp, 1e3 * t_bw, 1e3 * BLOCKS * max(t_comp, t_bw)))
print("Mac GPU busy per block %.1f ms is %.0fx the 5090 weight-read floor" % (1e3 * GPU_BUSY / BLOCKS, GPU_BUSY / BLOCKS / t_bw))

print("\n== C. data-parallel host work a device builder could take (solo, after A33) ==")
dp = {
    "w16 histograms": HIST_W16,
    "looked_built / exp / act histograms": HIST_OTHER,
    "limb planes and scatter (assign_with)": ASSIGN_LIMBS,
}
tot = sum(dp.values())
for k, v in dp.items():
    print("  %-40s %.3f s  %.1f%% of pass  %.1f ms/block" % (k, v, 100 * v / PASS, 1e3 * v / BLOCKS))
print("  subtotal (histograms + limbs)            %.3f s  %.1f%% of pass" % (tot, 100 * tot / PASS))
more = SCORES_SOFTMAX_PV + RQ_ROPE
print("  plus scores/softmax/PV and requant/RoPE  %.3f s -> %.3f s (%.1f%%)" % (more, tot + more, 100 * (tot + more) / PASS))
print("  beside a proof (x%.2f, a MODEL: slowdown assumed uniform): subtotal %.2f s, with attention %.2f s" % (BESIDE, tot * BESIDE, (tot + more) * BESIDE))

print("\n== D. the request-independent weight scan ==")
print("build's own scan (b): %.3f s per pass = %.1f%% of pass; %.1f ms per block; scans about %.1f GB per request (218 MB x 32)" % (BUILD_WEIGHT_SCAN, 100 * BUILD_WEIGHT_SCAN / PASS, 1e3 * BUILD_WEIGHT_SCAN / BLOCKS, W_BYTES * BLOCKS / 1e9))
print("implied scan rate %.0f GB/s on the pool (assumes the scan is the whole of group b's item)" % (W_BYTES * BLOCKS / BUILD_WEIGHT_SCAN / 1e9))

print("\n== E. what the sealing side must give for 2.56 s per request (two lanes) ==")
# MVP_STATUS / Batch 7: prove beside sealing 3.70 s, sealing beside proof 3.35 s (before A33), write about 0.33 s
# two lanes: cadence = (sealing + write + prove) / 2  =>  budget at 2.56 s is 5.12 s
budget = 2 * 2.56
for prove in (2.5, 2.8, 3.0):
    print("  if the prove call is %.1f s, sealing + write may be %.2f s (Mac beside-proof: sealing 3.35 s before A33, write 0.33 s)" % (prove, budget - prove))
print("  data-parallel subtotal beside a proof is %.2f s; the gap to a 2.3 s sealing side from 3.35 is %.2f s" % (tot * BESIDE, 3.35 - 2.3))

print("\n== F. PCIe upload if planes are built on the host (discrete GPU; a MODEL) ==")
rows = 984 + 1272 + 8 + 15   # A rows per block, cycle 6a section 2
plane_bytes = rows * 2**14 * 8
print("A rows %d x 2^14 words x 8 B = %.0f MB per block, %.1f GB per request" % (rows, plane_bytes / 1e6, plane_bytes * BLOCKS / 1e9))
for rate in (40e9, 55e9):
    print("  at %.0f GB/s PCIe: %.2f s per request (overlappable with the prove call)" % (rate / 1e9, plane_bytes * BLOCKS / rate))
