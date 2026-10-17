# Handoff: exact NTT pad-load fusion, with a locality warning

Run `20260927T015233Z-c29b434c`, cycle 0010. **Do not promote this as a speed
patch on the byte counts alone.** The algebra and scalar layout tests pass;
the large-row source-address model counts more memory-sector requests.
No code was merged, production file edited, build queued or device job run.

The [experiment](../experiments/ntt-pad-load-fusion-20260927/README.md),
[results](../experiments/ntt-pad-load-fusion-20260927/result.json) and
[source pins](../experiments/ntt-pad-load-fusion-20260927/source-pins.json)
are self-contained except for read-only original-source validation.

Interface: add a separate `k_ntt_p1_zk(coef,pads,pows,dst,tw,log_nn,n,q)`
producer, where coef has normalized natural-order inverse coefficients at
stride n, pads has existing fresh values at stride q, pows is the unchanged
public coset table, dst has stride nn and tw is stage-major forward twiddles.
`hashline/src/gpu/cuda.rs::encode_rows_view_zk` (line 1741 at the pinned source)
and `_gather` (1769) are the host seams. Kernel seam is `kernels.cu:117`.
Keep p1 butterflies/stores, forward scale one and p2/gather semantics intact.

The [proposed load helper](../experiments/ntt-pad-load-fusion-20260927/fused_load.proposed.cuh)
is uncompiled and unapplied. **No complete native patch exists.** Removing
`coef2` requires explicit host dispatch/allocation work and pool-lifetime
review. Existing compact/full switches and fallback behavior must remain
observable. Do not substitute the non-hiding `k_dit_p1_pad_c` producer.

Validation: 138 cases, 828 full/compact comparisons, 12,912 direct polynomial
points, 15 native synthetic conformance vectors, three sparse-polynomial
boundary cases (20,480 outputs), 16 flat chunk/stride cases, 256 column-byte
checks, duplicate/unsorted gathers, 13 mutation controls and six refusals pass.
Final CPU experiment 4.0622 s, 20,300 KiB RSS, one thread, seed 2026092710.
Complete p1 intermediates and final rows agree; scalar p2 mathematics is
tested, not native p2 thread execution. No transcript, RNG, native hash or
proof gate ran. Proving/verification/readiness remain null.

For q<=n this agrees with current pad/scale semantics. For q>n it agrees with
the independent CPU polynomial and the **corrected** materialized baseline;
the current CUDA branch is still a retained negative. The earlier
[pad-overlap handoff](20260926-ntt-layout-and-pad-overlap.md) stands, without
an affected-receipt or actual-device claim.

At n=16,384/q=256/nn=65,536, per row, the modeled interface loses 266,240
logical bytes (25.145%) and a 133,120-byte logical allocation. Its counted
32-byte sector requests rise **45,568 -> 49,920 (9.551%)**. Counts include
coefficient/pad/power reads; both compact arms retain 16,640 coset products.
This is the pad/p1 interface only, not the whole NTT or commitment. L2 reuse,
SASS load merging, occupancy, pool retention and actual DRAM traffic remain
unknown. Reordering each block's loads helps small domains but fails to
reduce the 16-stride coefficient reads at nn=65,536. Bank conflicts remain
unpriced. Native measurement may overturn the model in either direction.

Owner gates if pursued: original conformance row digests and forced compact/
full resident/chunked/opening paths, q boundaries, pad mutation, grow/shrink
dirty pools, duplicate gathers and keyed/legacy hash behavior; then native
mask/RNG/refusal/receipt parity and actual p1 plus **complete encode/readiness**
A/B under shared build/heavy locks and the owner's device authorization.
Removing a launch or allocation alone is not acceptance. Tagged shaped
commitments still need an authorized keyed device path; D22 is CPU-toy only,
and D19b/D23 remain proposed. No privacy acceptance extends through this test.

Better-directed memory follow-up: synthesize pad/coset terms at the normalized
inverse NTT's final store, removing the `coef` pass while retaining compact
`coef2`. First test ownership for q<=n and q>n, both inverse stage paths,
coalescing, stride changes and overlapping in-place p2 reads/writes. A new
buffer needed to avoid overwrites could eliminate the benefit. No native
implementation is requested before that bounded test.

Latest owner logs remain proving 34.861/33.315 s; known witness+prove+serialize
40.322/39.095 s; verify from bytes .91/.82 s separately, on a shared two-thread
CPU synthetic 125M block. A+H encode/Merkle is 16.739/16.903 s; the pad/p1
subphase is unmeasured. No seconds saved or complete private 8B throughput can
be inferred. The >=50 proved tokens/s target and complete-stack obligations
remain unchanged; prefill does not establish decode.
