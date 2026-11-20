#!/usr/bin/env python3
"""Tick 27 arithmetic (item 46): Shieldstral stream value of dropping committed padding.
Reads no file. Every input is typed from a cited record (see the handoff). Runs in under a second."""

# --- inputs -------------------------------------------------------------------------------
# A30/A31 benchmark review (results/zk60_astra_20261026/a30a31_benchmark_review_20261113/REVIEW.json)
armB_stream_wall = 105.14046490192413   # s, 24 requests, W16R2 Shieldstral app profile, proved and checked
armA_stream_wall = 190.74181365966797   # s, 24 requests, R13
reqs = 24
armB_proof_only_tps = 33.33878769195344 # deferred checks, W16R2
armA_proof_only_tps = 18.439724831815763
T = 128
cad_B = armB_stream_wall / reqs
cad_A = armA_stream_wall / reqs
print(f"cadence per T128 request: W16R2 {cad_B:.3f} s (proof only {T/armB_proof_only_tps:.3f} s), R13 {cad_A:.3f} s (proof only {T/armA_proof_only_tps:.3f} s)")

# slot breakdown README / tick 21 / tick 22 (production block GPU, diagnostic re-runs removed)
blk_8b = 91.46          # W16R2_8B
blk_r13s = 174.25       # R13_SHIELD (NOT W16R2_SHIELD)
commit_frac_8b = 0.305  # commit_A+H share of block GPU at W16R2_8B (tick 21)
commit_8b = commit_frac_8b * blk_8b
commit_r13s = 39.481 + 36.718   # R13_SHIELD commit_A + commit_H, README section 1 (ms)
print(f"commit_A+H: W16R2_8B {commit_8b:.2f} ms (13.987+13.900 = {13.987+13.900:.3f} diag), R13_SHIELD {commit_r13s:.2f} ms")

# --- padded rows --------------------------------------------------------------------------
# W16R2: tick 26 (plane lists counted at 8B, assumed equal at Shieldstral): 304 / 1376 of 5103
w_8b, w_sh, w_tot = 304, 1376, 2501 + 2602
f_w16r2_sh = w_sh / w_tot
print(f"W16R2 padded fraction: 8B {w_8b/w_tot:.4f}, Shieldstral {f_w16r2_sh:.4f}")

# R13: lists counted at R13_8B (census.log): A D 1248 rows, A F 2048, H D 544, H F 1024 (planes x rows; H doubled to base rows)
# Shieldstral padding: D 25.0% (3072 of 4096), F 43.75% (9216 of 16384)
r13_rows = 4577 + 4390
pad_r13 = 1248 * 0.25 + 2048 * 0.4375 + 544 * 2 * 0.25 + 1024 * 2 * 0.4375
print(f"R13 padded rows (R13_8B lists at Shieldstral padding, ASSUMED equal lists): {pad_r13:.0f} of {r13_rows} = {pad_r13/r13_rows:.4f}")

# --- tick 26's figure re-derived ----------------------------------------------------------
t26 = f_w16r2_sh * commit_r13s
print(f"tick 26 figure: W16R2 fraction x R13 commit = {t26:.2f} ms = {t26/blk_r13s*100:.2f}% of 174.25 (a cross-profile product)")
r13_own = pad_r13 / r13_rows * commit_r13s
print(f"R13 with its own fraction: {r13_own:.2f} ms = {r13_own/blk_r13s*100:.2f}% of 174.25; x26 = {r13_own*26/1000:.3f} s of R13 cadence {cad_A:.3f} s = {r13_own*26/1000/cad_A*100:.2f}%")

# --- W16R2_SHIELD ------------------------------------------------------------------------
# same row totals as W16R2_8B (ACCOUNTING.md:68), same row length 2^14, same code: commit time of the 8B block
# bracket: the retained older M4 phases (a23merge_trained.log:256,250), gpu=1 warm, wall seconds, single pass
m4_8b = 0.064 + 0.005 + 0.060 + 0.163
m4_sh = 0.054 + 0.005 + 0.062 + 0.160
ratio = m4_sh / m4_8b
print(f"M4 phases (older code, wall): W16R2_SHIELD {m4_sh:.3f} s vs W16R2_8B {m4_8b:.3f} s, ratio {ratio:.3f}")
blk_w16r2_sh = blk_8b * ratio
print(f"W16R2_SHIELD block GPU, DERIVED from the ratio: {blk_w16r2_sh:.1f} ms (x26 = {blk_w16r2_sh*26/1000:.2f} s, {blk_w16r2_sh*26/1000/cad_B*100:.0f}% of cadence)")
# 8B comparison: production solo GPU 2.927 s of cadence 3.7455 s
print(f"8B: {2.927/3.7455*100:.0f}% (tick 22)")

lo = f_w16r2_sh * commit_8b            # commit time as the 8B block
hi = f_w16r2_sh * (13.987 + 13.900 * 1.29) * (commit_8b / (13.987 + 13.900))  # helper commit +29% (M4 helper phase 0.062 vs 0.048)
for name, x in (("central", lo), ("upper", hi)):
    per_req = x * 26 / 1000
    print(f"{name}: saving {x:.2f} ms per block = {x/blk_w16r2_sh*100:.1f}% of block GPU; x26 = {per_req:.3f} s = {per_req/cad_B*100:.2f}% of cadence {cad_B:.3f} s;"
          f" at cadence 3.5 s {per_req/3.5*100:.2f}%; at 4.1 s {per_req/4.1*100:.2f}%")
# threshold: 5% of cadence
thr = 0.05 * cad_B * 1000 / 26
print(f"5% of cadence = {thr:.2f} ms saved per block; as a fraction of the commit: {thr/commit_8b:.3f}")
